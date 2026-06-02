import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart'
    show AuthException, UserAttributes;
import '../data/restaurants.dart';
import '../data/supabase_restaurant_repository.dart';
import '../models/account.dart';
import '../models/dashboard_metrics.dart';
import '../models/restaurant.dart';
import '../services/supabase_service.dart';

class AppProvider extends ChangeNotifier {
  // ── 앱 상태 ──
  String _stage = 'splash'; // splash | onboarding | login | app | owner | admin
  String get stage => _stage;

  // ── 인증 ──
  bool _isLoggedIn = false;
  String _nickname = '';
  String _accountId = '';
  String _userRole = 'user';
  List<String> _ownerRestaurantIds = [];

  bool get isLoggedIn => _isLoggedIn;
  String get nickname => _nickname;
  String get accountId => _accountId;
  String get userRole => _userRole;
  List<String> get ownerRestaurantIds => _ownerRestaurantIds;

  // ── 설정 ──
  bool _locationMode = false;
  bool _notificationEnabled = false;
  bool _useAlgorithmRanking = true;

  bool get locationMode => _locationMode;
  bool get notificationEnabled => _notificationEnabled;
  bool get useAlgorithmRanking => _useAlgorithmRanking;

  // ── 식당 ──
  List<Restaurant> _restaurants = [];
  List<Restaurant> get restaurants => _restaurants;

  // ── 북마크 ──
  Set<String> _bookmarks = {};
  Set<String> get bookmarks => _bookmarks;

  // ── 대시보드 지표 ──
  DashboardMetrics _metrics = DashboardMetrics.empty;
  DashboardMetrics get metrics => _metrics;

  // ── 키 ──
  static const _kLocation = 'cl_location_mode';
  static const _kLogin = 'cl_logged_in';
  static const _kNickname = 'cl_nickname';
  static const _kPush = 'cl_push_enabled';
  static const _kSessionExp = 'cl_session_exp';
  static const _kUserRole = 'cl_user_role';
  static const _kOwnerIds = 'cl_owner_restaurant_ids';
  static const _kAccountId = 'cl_account_id';
  static const _kAccounts = 'cl_accounts';
  static const _kBookmarks = 'cl_bookmarks';
  static const _kOverrides = 'cl_restaurant_overrides';
  static const _kUseAlgorithmRanking = 'cl_use_algorithm_ranking';

  static const _sessionDuration = Duration(days: 30);

  SupabaseRestaurantRepository? get _restaurantRepo =>
      SupabaseService.isReady ? SupabaseRestaurantRepository() : null;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();

    _useAlgorithmRanking = prefs.getBool(_kUseAlgorithmRanking) ?? true;

    _restaurants = List<Restaurant>.from(initialRestaurants);
    await _loadRestaurantsFromSupabase();

    // 저장된 혼잡도 오버라이드 적용
    final overridesJson = prefs.getString(_kOverrides);
    if (overridesJson != null) {
      final overrides = jsonDecode(overridesJson) as Map<String, dynamic>;
      _restaurants = _restaurants.map((r) {
        final ov = overrides[r.id.toString()] as Map<String, dynamic>?;
        if (ov == null) return r;
        final updatedAt = ov['updatedAt'] as int? ?? 0;
        final diffMin =
            ((DateTime.now().millisecondsSinceEpoch - updatedAt) / 60000)
                .floor();
        return r.copyWith(status: ov['status'] as String, updated: diffMin);
      }).toList();
    }

    // 북마크 복원
    final bookmarksJson = prefs.getString(_kBookmarks);
    if (bookmarksJson != null) {
      _bookmarks = Set<String>.from(
        (jsonDecode(bookmarksJson) as List).map((e) => e.toString()),
      );
    }

    // 인증 상태 복원
    final loggedIn = prefs.getBool(_kLogin) ?? false;
    final sessionExp = prefs.getInt(_kSessionExp) ?? 0;
    if (loggedIn && DateTime.now().millisecondsSinceEpoch > sessionExp) {
      // 세션 만료
      await _clearSession(prefs);
      _stage = 'login';
      notifyListeners();
      return;
    }

    if (loggedIn) {
      _isLoggedIn = true;
      _nickname = prefs.getString(_kNickname) ?? '';
      _accountId = prefs.getString(_kAccountId) ?? '';
      _userRole = prefs.getString(_kUserRole) ?? 'user';
      _ownerRestaurantIds = List<String>.from(
          jsonDecode(prefs.getString(_kOwnerIds) ?? '[]') as List);
      _locationMode = prefs.getBool(_kLocation) ?? false;
      _notificationEnabled = prefs.getBool(_kPush) ?? false;

      await Future.delayed(const Duration(seconds: 2));
      _stage = _userRole == 'owner' && _ownerRestaurantIds.isNotEmpty
          ? 'owner'
          : _userRole == 'admin'
              ? 'admin'
              : 'app';
    } else {
      final locationStored = prefs.containsKey(_kLocation);
      await Future.delayed(const Duration(seconds: 2));
      _stage = locationStored ? 'login' : 'onboarding';
    }

    notifyListeners();
  }

  // ── 로그인 ──
  Future<bool> login(String email, String password) async {
    // 개발용 테스트 계정
    if (email == 'admin' && password == 'admin123') {
      await _saveSession(
          await SharedPreferences.getInstance(),
          Account(
              id: 'admin',
              password: 'admin123',
              nickname: '관리자',
              role: 'admin'));
      return true;
    }
    if (email == 'owner' && password == 'owner123') {
      await _saveSession(
          await SharedPreferences.getInstance(),
          Account(
              id: 'owner',
              password: 'owner123',
              nickname: '사장님',
              role: 'owner',
              restaurantIds: [
                _restaurants.isNotEmpty ? _restaurants.first.id.toString() : '1'
              ]));
      return true;
    }

    // Supabase Auth
    if (SupabaseService.isReady) {
      try {
        final res = await SupabaseService.client.auth
            .signInWithPassword(email: email, password: password);
        if (res.user != null) {
          final meta = res.user!.userMetadata;
          final nickname = meta?['nickname'] as String? ?? _generateNickname();
          final role = meta?['role'] as String? ?? 'user';
          final restaurantIds = (meta?['restaurant_ids'] as List?)
                  ?.map((e) => e.toString())
                  .toList() ??
              [];
          final prefs = await SharedPreferences.getInstance();
          // 북마크 복원
          final remoteBookmarks = meta?['bookmarks'];
          if (remoteBookmarks is List && remoteBookmarks.isNotEmpty) {
            await prefs.setString(_kBookmarks, jsonEncode(remoteBookmarks));
          }
          await _saveSession(
              prefs,
              Account(
                id: email,
                password: '',
                nickname: nickname,
                role: role,
                restaurantIds: restaurantIds,
              ));
          return true;
        }
      } on AuthException catch (e) {
        debugPrint('[Supabase] login AuthException: ${e.message}');
        // 로컬 폴백으로 진행
      } catch (e) {
        debugPrint('[Supabase] login failed: $e');
      }
    }

    // 로컬 폴백
    final prefs = await SharedPreferences.getInstance();
    final accounts = _loadAccounts(prefs);
    final account = accounts
        .where((a) => a.id == email && a.password == password)
        .firstOrNull;
    if (account == null) return false;
    await _saveSession(prefs, account);
    return true;
  }

  Future<String?> register(String email, String password, String nick) async {
    final nickname = nick.isEmpty ? _generateNickname() : nick;

    final prefs = await SharedPreferences.getInstance();
    final accounts = _loadAccounts(prefs);
    if (accounts.any((a) => a.id == email)) return '이미 사용 중인 이메일이에요.';

    // Supabase Auth 시도
    if (SupabaseService.isReady) {
      try {
        final res = await SupabaseService.client.auth.signUp(
          email: email,
          password: password,
          data: {'nickname': nickname},
        );
        if (res.user == null) return '회원가입에 실패했어요.';
      } on AuthException catch (e) {
        final msg = e.message.toLowerCase();
        if (msg.contains('already') || msg.contains('registered')) {
          return '이미 사용 중인 이메일이에요.';
        }
        debugPrint('[Supabase] register AuthException: ${e.message}');
        // rate limit 등 → 로컬에만 저장하고 계속 진행
      } catch (e) {
        debugPrint('[Supabase] register failed: $e');
      }
    }

    // 항상 로컬에도 저장 (초기화 후 로컬 로그인 보장)
    final account = Account(id: email, password: password, nickname: nickname);
    _saveAccounts(prefs, [...accounts, account]);
    await _saveSession(prefs, account);
    return null;
  }

  Future<void> _saveSession(SharedPreferences prefs, Account account) async {
    _isLoggedIn = true;
    _nickname = account.nickname;
    _accountId = account.id;
    _userRole = account.role;
    _ownerRestaurantIds = List<String>.from(account.restaurantIds);

    await prefs.setBool(_kLogin, true);
    await prefs.setString(_kNickname, account.nickname);
    await prefs.setString(_kAccountId, account.id);
    await prefs.setString(_kUserRole, account.role);
    await prefs.setString(_kOwnerIds, jsonEncode(account.restaurantIds));
    await prefs.setInt(_kSessionExp,
        DateTime.now().add(_sessionDuration).millisecondsSinceEpoch);

    final locationStored = prefs.containsKey(_kLocation);
    _locationMode = prefs.getBool(_kLocation) ?? false;
    _notificationEnabled = prefs.getBool(_kPush) ?? false;

    if (account.role == 'owner' && account.restaurantIds.isNotEmpty) {
      _stage = 'owner';
    } else if (account.role == 'admin') {
      _stage = 'admin';
    } else {
      _stage = locationStored ? 'app' : 'location_permission';
    }
    notifyListeners();
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await _clearSession(prefs);
    _stage = 'login';
    notifyListeners();
  }

  Future<void> _clearSession(SharedPreferences prefs) async {
    await prefs.remove(_kLogin);
    await prefs.remove(_kNickname);
    await prefs.remove(_kSessionExp);
    await prefs.remove(_kAccountId);
    _isLoggedIn = false;
    _nickname = '';
    _accountId = '';
    _userRole = 'user';
    _ownerRestaurantIds = [];
    _locationMode = false;
    _notificationEnabled = false;
  }

  // ── 위치 권한 ──
  Future<void> enableLocation() async {
    final prefs = await SharedPreferences.getInstance();
    _locationMode = true;
    await prefs.setBool(_kLocation, true);
    notifyListeners();
  }

  Future<void> setLocationMode(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    _locationMode = enabled;
    await prefs.setBool(_kLocation, enabled);
    if (_stage == 'location_permission') {
      _stage = prefs.containsKey(_kPush) ? 'app' : 'notification_permission';
    }
    notifyListeners();
  }

  Future<void> completeNotificationPermission(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    _notificationEnabled = enabled;
    await prefs.setBool(_kPush, enabled);
    _stage = 'app';
    notifyListeners();
  }

  // ── 알림 ──
  Future<void> setNotificationEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    _notificationEnabled = enabled;
    await prefs.setBool(_kPush, enabled);
    notifyListeners();
  }

  // ── 혼잡도 제보 ──
  Future<void> reportStatus(String restaurantId, String status) async {
    final repo = _restaurantRepo;
    if (repo != null) {
      try {
        final userId = SupabaseService.isReady
            ? (SupabaseService.client.auth.currentUser?.id ?? _accountId)
            : _accountId;
        await repo.reportStatus(restaurantId, status,
            source: _userRole == 'owner' ? 'owner' : 'user', userId: userId);
        _restaurants = await repo.fetchAll();
        notifyListeners();
        return;
      } catch (e, st) {
        debugPrint('[Supabase] reportStatus failed: $e\n$st');
      }
    }

    final prefs = await SharedPreferences.getInstance();
    final overridesJson = prefs.getString(_kOverrides);
    final overrides = overridesJson != null
        ? jsonDecode(overridesJson) as Map<String, dynamic>
        : <String, dynamic>{};

    overrides[restaurantId.toString()] = {
      'status': status,
      'updatedAt': DateTime.now().millisecondsSinceEpoch,
    };
    await prefs.setString(_kOverrides, jsonEncode(overrides));

    _restaurants = _restaurants.map((r) {
      if (r.id != restaurantId) return r;
      final next = Map<String, int>.from(r.reports);
      if (status != '영업안함') next[status] = (next[status] ?? 0) + 1;
      return r.copyWith(status: status, updated: 0, reports: next);
    }).toList();
    notifyListeners();
  }

  // ── 북마크 ──
  Future<void> toggleBookmark(String id) async {
    final prefs = await SharedPreferences.getInstance();
    if (_bookmarks.contains(id)) {
      _bookmarks.remove(id);
    } else {
      _bookmarks.add(id);
    }
    await prefs.setString(_kBookmarks, jsonEncode(_bookmarks.toList()));
    await _syncMetadata({'bookmarks': _bookmarks.toList()});
    notifyListeners();
  }

  // ── 온보딩 완료 ──
  void completeOnboarding() {
    _stage = 'login';
    notifyListeners();
  }

  // ── 헬퍼 ──
  List<Account> _loadAccounts(SharedPreferences prefs) {
    final json = prefs.getString(_kAccounts);
    if (json == null) return [];
    return (jsonDecode(json) as List)
        .map((e) => Account.fromMap(e as Map<String, dynamic>))
        .toList();
  }

  void _saveAccounts(SharedPreferences prefs, List<Account> accounts) {
    prefs.setString(
        _kAccounts, jsonEncode(accounts.map((a) => a.toMap()).toList()));
  }

  bool get _hasSupabaseSession =>
      SupabaseService.isReady &&
      SupabaseService.client.auth.currentUser != null;

  Future<void> _syncMetadata(Map<String, dynamic> data) async {
    if (!_hasSupabaseSession) return;
    try {
      await SupabaseService.client.auth.updateUser(
        UserAttributes(data: data),
      );
    } catch (e) {
      debugPrint('[Supabase] updateUser metadata failed: $e');
    }
  }

  String _generateNickname() {
    const fruits = ['딸기', '사과', '포도', '수박', '레몬', '망고', '복숭아', '바나나'];
    final idx = DateTime.now().millisecondsSinceEpoch % fruits.length;
    final num = DateTime.now().millisecondsSinceEpoch % 9000 + 1000;
    return '앙대${fruits[idx]}$num';
  }

  Future<void> updateNickname(String nick) async {
    final prefs = await SharedPreferences.getInstance();
    _nickname = nick;
    await prefs.setString(_kNickname, nick);
    await _syncMetadata({'nickname': nick});
    notifyListeners();
  }

  Future<void> socialLogin() async {
    final prefs = await SharedPreferences.getInstance();
    final nick = prefs.getString(_kNickname) ?? _generateNickname();
    final fakeAccount = Account(
        id: 'social_${DateTime.now().millisecondsSinceEpoch}',
        password: '',
        nickname: nick);
    await _saveSession(prefs, fakeAccount);
  }

  // ── 어드민: 매장 관리 ──
  Future<void> addRestaurant(Map<String, dynamic> data) async {
    final repo = _restaurantRepo;
    if (repo != null) {
      try {
        await repo.insert(data);
        _restaurants = await repo.fetchAll();
        notifyListeners();
        return;
      } catch (e, st) {
        debugPrint('[Supabase] addRestaurant failed: $e\n$st');
      }
    }

    final newR = Restaurant(
      id: 'local_${DateTime.now().millisecondsSinceEpoch}',
      name: data['name'] as String,
      category: data['category'] as String,
      area: data['area'] as String,
      address: data['address'] as String? ?? data['area'] as String,
      status: '여유로움',
      updated: 0,
      imageUrl: data['image_url'] as String? ?? '',
      distance: 200,
      x: (data['x'] as num?)?.toDouble() ?? 50,
      y: (data['y'] as num?)?.toDouble() ?? 50,
      hours: data['hours'] as String? ?? '11:00 - 21:00',
      reports: {},
      menu: ((data['menu'] as List<dynamic>?) ?? [])
          .map((m) => MenuItem(
              name: (m as Map)['name'] as String,
              price: (m['price'] as num).toInt()))
          .toList(),
    );
    _restaurants = [..._restaurants, newR];
    notifyListeners();
  }

  Future<void> editRestaurant(String id, Map<String, dynamic> data) async {
    final repo = _restaurantRepo;
    if (repo != null) {
      try {
        await repo.update(id, data);
        _restaurants = await repo.fetchAll();
        notifyListeners();
        return;
      } catch (e, st) {
        debugPrint('[Supabase] editRestaurant failed: $e\n$st');
      }
    }

    _restaurants = _restaurants.map((r) {
      if (r.id != id) return r;
      return Restaurant(
        id: r.id,
        name: data['name'] as String? ?? r.name,
        category: data['category'] as String? ?? r.category,
        area: data['area'] as String? ?? r.area,
        address: data['address'] as String? ?? r.address,
        status: r.status,
        updated: r.updated,
        imageUrl: data['image_url'] as String? ?? r.imageUrl,
        distance: r.distance,
        x: r.x,
        y: r.y,
        hours: data['hours'] as String? ?? r.hours,
        reports: r.reports,
        menu: data['menu'] != null
            ? ((data['menu'] as List<dynamic>))
                .map((m) => MenuItem(
                    name: (m as Map)['name'] as String,
                    price: (m['price'] as num).toInt()))
                .toList()
            : r.menu,
      );
    }).toList();
    notifyListeners();
  }

  Future<void> deleteRestaurant(String id) async {
    final repo = _restaurantRepo;
    if (repo != null) {
      try {
        await repo.delete(id);
        _restaurants = _restaurants.where((r) => r.id != id).toList();
        notifyListeners();
        return;
      } catch (e, st) {
        debugPrint('[Supabase] deleteRestaurant failed: $e\n$st');
      }
    }

    _restaurants = _restaurants.where((r) => r.id != id).toList();
    notifyListeners();
  }

  Future<String?> uploadRestaurantImage(Uint8List bytes, String ext) async {
    final repo = _restaurantRepo;
    if (repo == null) return null;
    try {
      return await repo.uploadImage(bytes, ext);
    } catch (e, st) {
      debugPrint('[Supabase] uploadImage failed: $e\n$st');
      return null;
    }
  }

  Future<void> generateOwnerCode(String restaurantId) async {
    final repo = _restaurantRepo;
    if (repo == null) return;
    try {
      final code = await repo.generateOwnerCode(restaurantId);
      _restaurants = _restaurants.map((r) {
        if (r.id != restaurantId) return r;
        return Restaurant(
          id: r.id,
          name: r.name,
          category: r.category,
          area: r.area,
          address: r.address,
          status: r.status,
          updated: r.updated,
          imageUrl: r.imageUrl,
          distance: r.distance,
          x: r.x,
          y: r.y,
          hours: r.hours,
          reports: r.reports,
          menu: r.menu,
          popularityScore: r.popularityScore,
          manualRank: r.manualRank,
          ownerCode: code,
        );
      }).toList();
      notifyListeners();
    } catch (e, st) {
      debugPrint('[Supabase] generateOwnerCode failed: $e\n$st');
    }
  }

  Future<String?> verifyOwnerCode(String code) async {
    // 로컬 restaurants에서 먼저 확인
    final found = _restaurants.where((r) => r.ownerCode == code);
    String? restaurantId = found.isEmpty ? null : found.first.id;

    // 로컬에 없으면 DB에서 조회
    if (restaurantId == null) {
      final repo = _restaurantRepo;
      if (repo != null) {
        try {
          restaurantId = await repo.findRestaurantIdByOwnerCode(code);
        } catch (e) {
          debugPrint('[verifyOwnerCode] DB lookup failed: $e');
        }
      }
    }

    if (restaurantId == null) return 'INVALID_CODE';

    try {
      _userRole = 'owner';
      _ownerRestaurantIds = [restaurantId];

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kUserRole, 'owner');
      await prefs.setString(_kOwnerIds, jsonEncode([restaurantId]));

      // Supabase Auth metadata에 role 저장 (로그인 후에도 유지)
      await _syncMetadata({
        'role': 'owner',
        'restaurant_ids': [restaurantId]
      });

      // 해당 매장을 오너 등록 완료로 표시
      final repo = _restaurantRepo;
      if (repo != null) {
        await repo.markOwnerRegistered(restaurantId);
        _restaurants = await repo.fetchAll();
      }

      _stage = 'owner';
      notifyListeners();
      return null;
    } catch (e) {
      debugPrint('[verifyOwnerCode] $e');
      return 'INVALID_CODE';
    }
  }

  Future<void> fetchMetrics() async {
    final repo = _restaurantRepo;
    if (repo == null) return;
    try {
      _metrics = await repo.fetchMetrics();
      notifyListeners();
    } catch (e, st) {
      debugPrint('[Supabase] fetchMetrics failed: $e\n$st');
    }
  }

  Future<void> toggleAlgorithmRanking() async {
    final wasOn = _useAlgorithmRanking;
    _useAlgorithmRanking = !_useAlgorithmRanking;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kUseAlgorithmRanking, _useAlgorithmRanking);

    // 처음 off 전환 시 현재 인기순으로 자동 순위 배정
    if (wasOn && !_useAlgorithmRanking) {
      final allUnranked = _restaurants.every((r) => r.manualRank == 0);
      if (allUnranked) {
        final sorted = [..._restaurants]..sort((a, b) {
            final aScore =
                a.popularityScore > 0 ? a.popularityScore : a.totalReports;
            final bScore =
                b.popularityScore > 0 ? b.popularityScore : b.totalReports;
            return bScore.compareTo(aScore);
          });
        await setManualRanks(sorted.map((r) => r.id).toList());
        return;
      }
    }
    notifyListeners();
  }

  Future<void> setManualRanks(List<String> orderedIds) async {
    final rankById = {
      for (int i = 0; i < orderedIds.length; i++) orderedIds[i]: i + 1
    };
    _restaurants = _restaurants.map((r) {
      final rank = rankById[r.id];
      if (rank == null) return r;
      return Restaurant(
        id: r.id,
        name: r.name,
        category: r.category,
        area: r.area,
        address: r.address,
        status: r.status,
        updated: r.updated,
        imageUrl: r.imageUrl,
        distance: r.distance,
        x: r.x,
        y: r.y,
        hours: r.hours,
        reports: r.reports,
        menu: r.menu,
        popularityScore: r.popularityScore,
        manualRank: rank,
      );
    }).toList();
    notifyListeners();

    final repo = _restaurantRepo;
    if (repo != null) {
      try {
        await repo.updateManualRanks(rankById);
      } catch (e, st) {
        debugPrint('[Supabase] setManualRanks failed: $e\n$st');
      }
    }
  }

  Future<void> _loadRestaurantsFromSupabase() async {
    final repo = _restaurantRepo;
    if (repo == null) return;

    try {
      final fetched = await repo.fetchAll();
      if (fetched.isNotEmpty) _restaurants = fetched;
    } catch (e, st) {
      debugPrint('[Supabase] load restaurants failed: $e\n$st');
    }
  }

  Future<void> devReset() async {
    final prefs = await SharedPreferences.getInstance();
    final savedAccounts = prefs.getString(_kAccounts);
    await prefs.clear();
    if (savedAccounts != null) await prefs.setString(_kAccounts, savedAccounts);
    _restaurants = List<Restaurant>.from(initialRestaurants);
    _bookmarks = {};
    _isLoggedIn = false;
    _nickname = '';
    _accountId = '';
    _userRole = 'user';
    _ownerRestaurantIds = [];
    _locationMode = false;
    _notificationEnabled = false;
    _stage = 'onboarding';
    notifyListeners();
  }
}
