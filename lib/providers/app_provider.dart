import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/restaurant.dart';
import '../models/account.dart';
import '../data/restaurants.dart';

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

  bool get locationMode => _locationMode;
  bool get notificationEnabled => _notificationEnabled;

  // ── 식당 ──
  List<Restaurant> _restaurants = [];
  List<Restaurant> get restaurants => _restaurants;

  // ── 북마크 ──
  Set<int> _bookmarks = {};
  Set<int> get bookmarks => _bookmarks;

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

  static const _sessionDuration = Duration(days: 30);

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();

    _restaurants = List<Restaurant>.from(initialRestaurants);

    // 저장된 혼잡도 오버라이드 적용
    final overridesJson = prefs.getString(_kOverrides);
    if (overridesJson != null) {
      final overrides = jsonDecode(overridesJson) as Map<String, dynamic>;
      _restaurants = _restaurants.map((r) {
        final ov = overrides[r.id.toString()] as Map<String, dynamic>?;
        if (ov == null) return r;
        final updatedAt = ov['updatedAt'] as int? ?? 0;
        final diffMin = ((DateTime.now().millisecondsSinceEpoch - updatedAt) / 60000).floor();
        return r.copyWith(status: ov['status'] as String, updated: diffMin);
      }).toList();
    }

    // 북마크 복원
    final bookmarksJson = prefs.getString(_kBookmarks);
    if (bookmarksJson != null) {
      _bookmarks = Set<int>.from(jsonDecode(bookmarksJson) as List);
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
      _ownerRestaurantIds = List<String>.from(jsonDecode(prefs.getString(_kOwnerIds) ?? '[]') as List);
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
  Future<bool> login(String id, String password) async {
    // 개발용 테스트 계정
    if (id == 'admin' && password == 'admin123') {
      await _saveSession(await SharedPreferences.getInstance(),
          Account(id: 'admin', password: 'admin123', nickname: '관리자', role: 'admin'));
      return true;
    }
    if (id == 'owner' && password == 'owner123') {
      await _saveSession(await SharedPreferences.getInstance(),
          Account(id: 'owner', password: 'owner123', nickname: '사장님', role: 'owner',
              restaurantIds: [_restaurants.isNotEmpty ? _restaurants.first.id.toString() : '1']));
      return true;
    }

    final prefs = await SharedPreferences.getInstance();
    final accounts = _loadAccounts(prefs);
    final account = accounts.where((a) => a.id == id && a.password == password).firstOrNull;
    if (account == null) return false;
    await _saveSession(prefs, account);
    return true;
  }

  Future<String?> register(String id, String password, String nick) async {
    final prefs = await SharedPreferences.getInstance();
    final accounts = _loadAccounts(prefs);
    if (accounts.any((a) => a.id == id)) return '이미 사용 중인 아이디예요.';
    final account = Account(id: id, password: password, nickname: nick.isEmpty ? _generateNickname() : nick);
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
  Future<void> reportStatus(int restaurantId, String status) async {
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
  Future<void> toggleBookmark(int id) async {
    final prefs = await SharedPreferences.getInstance();
    if (_bookmarks.contains(id)) {
      _bookmarks.remove(id);
    } else {
      _bookmarks.add(id);
    }
    await prefs.setString(_kBookmarks, jsonEncode(_bookmarks.toList()));
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
    prefs.setString(_kAccounts, jsonEncode(accounts.map((a) => a.toMap()).toList()));
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
    notifyListeners();
  }

  Future<void> socialLogin() async {
    final prefs = await SharedPreferences.getInstance();
    final nick = prefs.getString(_kNickname) ?? _generateNickname();
    final fakeAccount = Account(id: 'social_${DateTime.now().millisecondsSinceEpoch}', password: '', nickname: nick);
    await _saveSession(prefs, fakeAccount);
  }

  // ── 어드민: 매장 관리 ──
  Future<void> addRestaurant(Map<String, dynamic> data) async {
    final maxId = _restaurants.isEmpty
        ? 0
        : _restaurants.map((r) => r.id).reduce((a, b) => a > b ? a : b);
    final newR = Restaurant(
      id: maxId + 1,
      name: data['name'] as String,
      cuisine: data['cuisine'] as String,
      region: data['region'] as String,
      area: data['area'] as String? ?? data['region'] as String,
      status: '여유로움',
      updated: 0,
      emoji: '🍽️',
      image: data['image'] as String? ?? '',
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

  Future<void> editRestaurant(int id, Map<String, dynamic> data) async {
    _restaurants = _restaurants.map((r) {
      if (r.id != id) return r;
      return Restaurant(
        id: r.id,
        name: data['name'] as String? ?? r.name,
        cuisine: data['cuisine'] as String? ?? r.cuisine,
        region: data['region'] as String? ?? r.region,
        area: data['area'] as String? ?? r.area,
        status: r.status,
        updated: r.updated,
        emoji: r.emoji,
        image: data['image'] as String? ?? r.image,
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

  Future<void> deleteRestaurant(int id) async {
    _restaurants = _restaurants.where((r) => r.id != id).toList();
    notifyListeners();
  }

  Future<void> devReset() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
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
