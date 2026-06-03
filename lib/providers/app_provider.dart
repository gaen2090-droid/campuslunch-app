import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/env.dart';
import '../utils/nickname_generator.dart';
import '../data/auth_repository.dart';
import '../data/profile_repository.dart';
import '../data/restaurants.dart';
import '../data/supabase_restaurant_repository.dart';
import '../models/account.dart';
import '../models/dashboard_metrics.dart';
import '../models/restaurant.dart';
import '../services/kakao_auth_service.dart';
import '../services/supabase_service.dart';
import '../utils/business_hours.dart';

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

  /// 이메일 링크 인증 직후 메인 화면에서 1회 표시
  bool _showSignupCompleteMessage = false;
  bool get showSignupCompleteMessage => _showSignupCompleteMessage;

  void clearSignupCompleteMessage() {
    if (!_showSignupCompleteMessage) return;
    _showSignupCompleteMessage = false;
    notifyListeners();
  }

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
  static const _kAwaitingEmailConfirm = 'cl_awaiting_email_confirm';
  static const _kAuthProvider = 'cl_auth_provider';

  static const _sessionDuration = Duration(days: 30);

  SupabaseRestaurantRepository? get _restaurantRepo =>
      SupabaseService.isReady ? SupabaseRestaurantRepository() : null;

  /// 앱 내 admin/admin123 또는 Supabase JWT role=admin
  bool get _canAdminOps => _userRole == 'admin' || SupabaseService.isAdmin;

  StreamSubscription<AuthState>? _authSub;
  final ProfileRepository _profileRepo = ProfileRepository();
  final AuthRepository _authRepo = AuthRepository();

  @override
  void dispose() {
    _authSub?.cancel();
    super.dispose();
  }

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
    _restaurants = _restaurants.map(_applyOperatingHours).toList();

    // 북마크 복원
    final bookmarksJson = prefs.getString(_kBookmarks);
    if (bookmarksJson != null) {
      _bookmarks = Set<String>.from(
        (jsonDecode(bookmarksJson) as List).map((e) => e.toString()),
      );
    }

    if (SupabaseService.isReady) {
      _bindAuthListener();
      final session = SupabaseService.client.auth.currentSession;
      final user = SupabaseService.client.auth.currentUser;
      if (session != null &&
          user != null &&
          user.emailConfirmedAt != null) {
        await _onSupabaseSignedIn(user);
        await Future.delayed(const Duration(seconds: 2));
        notifyListeners();
        return;
      }
    }

    // 인증 상태 복원 (로컬 / 테스트 계정)
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
    // 편의용 관리자 (개발·운영 준비 단계 — 출시 전 Supabase 관리자 계정으로 교체 권장)
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

    if (kDebugMode) {
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
    if (email == 'user' && password == 'user123') {
      await _saveSession(
          await SharedPreferences.getInstance(),
          Account(
              id: 'user',
              password: 'user123',
              nickname: '테스트유저',
              role: 'user'));
      return true;
    }
    }

    // Supabase Auth
    if (SupabaseService.isReady) {
      try {
        final res = await SupabaseService.client.auth
            .signInWithPassword(email: email, password: password);
        if (res.user != null) {
          if (res.user!.emailConfirmedAt == null) {
            debugPrint('[Supabase] login: email not confirmed');
            return false;
          }
          await _onSupabaseSignedIn(res.user!);
          return true;
        }
      } on AuthException catch (e) {
        final msg = e.message.toLowerCase();
        if (msg.contains('email not confirmed') || msg.contains('not confirmed')) {
          // 이메일 미인증 → 로컬 폴백 없이 바로 false 반환 (메시지 별도 처리)
          debugPrint('[Supabase] email not confirmed: ${e.message}');
          return false;
        }
        debugPrint('[Supabase] login AuthException: ${e.message}');
        // 그 외 Supabase 에러 → 로컬 폴백으로 진행
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
    final nickname = nick.isEmpty ? generateNickname() : nick;
    final trimmedEmail = email.trim();

    if (SupabaseService.isReady) {
      final status = await _authRepo.checkEmailSignupStatus(trimmedEmail);
      switch (status) {
        case EmailSignupStatus.registered:
          return '이미 가입된 이메일이에요. 로그인해주세요.';
        case EmailSignupStatus.pending:
          return '이미 가입 요청된 이메일이에요. 메일함의 인증 링크를 확인하거나, 인증 화면에서 메일을 다시 보내주세요.';
        case EmailSignupStatus.invalid:
          return '이메일 형식을 확인해주세요.';
        case EmailSignupStatus.available:
        case EmailSignupStatus.unknown:
          break;
      }

      try {
        final res = await SupabaseService.client.auth.signUp(
          email: trimmedEmail,
          password: password,
          data: {'nickname': nickname},
          emailRedirectTo: Env.authRedirectUrl,
        );
        if (res.user == null) return '회원가입에 실패했어요.';

        if (res.user!.identities != null && res.user!.identities!.isEmpty) {
          return '이미 가입된 이메일이에요. 로그인해주세요.';
        }

        if (res.session != null) {
          await _onSupabaseSignedIn(res.user!);
          return null;
        }
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool(_kAwaitingEmailConfirm, true);
        return 'pending_email';
      } on AuthException catch (e) {
        final msg = e.message.toLowerCase();
        if (msg.contains('already') || msg.contains('registered')) {
          return '이미 가입된 이메일이에요. 로그인해주세요.';
        }
        if (msg.contains('rate') || msg.contains('limit')) {
          return '메일 발송 한도에 걸렸어요. 30분 후 다시 시도하거나 다른 이메일로 가입해주세요.';
        }
        if (msg.contains('redirect') || msg.contains('url')) {
          return '인증 주소 설정 오류예요. Supabase Redirect URLs에 campuslunch://login-callback 을 등록해주세요.';
        }
        return e.message;
      } catch (e) {
        debugPrint('[Supabase] register failed: $e');
        return '회원가입에 실패했어요. 잠시 후 다시 시도해주세요.';
      }
    }

    final prefs = await SharedPreferences.getInstance();
    final accounts = _loadAccounts(prefs);
    if (accounts.any((a) => a.id == email)) return '이미 사용 중인 이메일이에요.';
    final account = Account(id: email, password: password, nickname: nickname);
    _saveAccounts(prefs, [...accounts, account]);
    await _saveSession(prefs, account);
    return null;
  }

  /// 이메일 인증 메일 재발송
  Future<String?> resendSignupEmail(String email) async {
    if (!SupabaseService.isReady) return '서버 연결을 확인해주세요.';

    final status = await _authRepo.checkEmailSignupStatus(email.trim());
    if (status == EmailSignupStatus.registered) {
      return '이미 가입이 완료된 이메일이에요. 로그인해주세요.';
    }
    if (status == EmailSignupStatus.available) {
      return '가입 요청이 없는 이메일이에요. 회원가입을 먼저 진행해주세요.';
    }

    try {
      await SupabaseService.client.auth.resend(
        type: OtpType.signup,
        email: email.trim(),
        emailRedirectTo: Env.authRedirectUrl,
      );
      return null;
    } on AuthException catch (e) {
      return e.message;
    } catch (e) {
      debugPrint('[Supabase] resend failed: $e');
      return '메일 재발송에 실패했어요.';
    }
  }

  void _bindAuthListener() {
    _authSub?.cancel();
    _authSub = SupabaseService.client.auth.onAuthStateChange.listen((data) async {
      if (data.event == AuthChangeEvent.signedIn && data.session != null) {
        final user = data.session!.user;
        if (user.emailConfirmedAt != null) {
          await _onSupabaseSignedIn(user);
        }
      }
    });
  }

  Future<void> _onSupabaseSignedIn(User user) async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_kAwaitingEmailConfirm) ?? false) {
      _showSignupCompleteMessage = true;
      await prefs.remove(_kAwaitingEmailConfirm);
    }

    final profile = await _profileRepo.fetch(user.id);

    final meta = user.userMetadata;
    final appMeta = user.appMetadata;
    var nickname = profile?.nickname ?? meta?['nickname'] as String?;
    if (isPlaceholderNickname(nickname)) {
      nickname = generateNickname();
      await _syncMetadata({'nickname': nickname});
    }
    nickname ??= generateNickname();

    await _profileRepo.upsertFromAuthUser(
      SupabaseService.client.auth.currentUser ?? user,
    );
    final role = profile?.role ??
        appMeta['role'] as String? ??
        meta?['role'] as String? ??
        'user';
    final restaurantIds = (meta?['restaurant_ids'] as List?)
            ?.map((e) => e.toString())
            .toList() ??
        [];

    final remoteBookmarks = meta?['bookmarks'];
    if (remoteBookmarks is List && remoteBookmarks.isNotEmpty) {
      await prefs.setString(_kBookmarks, jsonEncode(remoteBookmarks));
    }

    final authProvider =
        meta?['auth_provider'] as String? ??
        user.appMetadata['provider'] as String? ??
        'email';

    await _saveSession(
      prefs,
      Account(
        id: user.email ?? user.id,
        password: '',
        nickname: nickname,
        role: role,
        restaurantIds: restaurantIds,
      ),
      authProvider: authProvider,
    );
  }

  Future<void> _saveSession(
    SharedPreferences prefs,
    Account account, {
    String authProvider = 'email',
  }) async {
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
    await prefs.setString(_kAuthProvider, authProvider);

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
    final authProvider = prefs.getString(_kAuthProvider) ?? '';

    if (authProvider == 'kakao') {
      await KakaoAuthService.logoutKakao();
    }

    if (SupabaseService.isReady) {
      try {
        await SupabaseService.client.auth.signOut();
      } catch (e) {
        debugPrint('[Supabase] signOut: $e');
      }
    }

    await _clearSession(prefs);
    _stage = 'login';
    notifyListeners();
  }

  /// 회원 탈퇴 (카카오 연결 해제 + Supabase 계정 삭제)
  Future<String?> withdrawAccount() async {
    if (!_hasSupabaseSession) {
      return '로그인된 계정이 없어요.';
    }

    final prefs = await SharedPreferences.getInstance();
    final authProvider = prefs.getString(_kAuthProvider) ?? '';

    try {
      if (authProvider == 'kakao') {
        await KakaoAuthService.unlinkKakao();
      }
      await _profileRepo.deleteOwnAccount();
      await SupabaseService.client.auth.signOut();
      await _clearSession(prefs);
      _stage = 'login';
      notifyListeners();
      return null;
    } on PostgrestException catch (e) {
      debugPrint('[withdraw] RPC: ${e.message}');
      return '탈퇴 처리에 실패했어요. (${e.message})';
    } catch (e) {
      debugPrint('[withdraw] $e');
      return '탈퇴 처리에 실패했어요.';
    }
  }

  /// 카카오 로그인 (Supabase Auth + public.users)
  Future<String?> loginWithKakao() async {
    if (!KakaoAuthService.isConfigured) {
      return 'KAKAO_NATIVE_APP_KEY가 .env에 없습니다.';
    }
    if (!SupabaseService.isReady) {
      return 'Supabase 연결을 확인해주세요.';
    }

    try {
      final result = await KakaoAuthService.signInWithSupabase();
      await _onSupabaseSignedIn(result.user);
      return null;
    } on AuthException catch (e) {
      if (e.message.contains('Unacceptable audience in id_token')) {
        return 'Supabase Kakao 설정을 확인해주세요.\n'
            'Authentication → Providers → Kakao → '
            'Native App Key(또는 REST API Key 칸)에 '
            '네이티브 앱 키(${Env.kakaoNativeAppKey})를 넣어야 합니다.';
      }
      return e.message;
    } catch (e) {
      debugPrint('[Kakao] loginWithKakao: $e');
      final msg = e.toString().toLowerCase();
      if (msg.contains('cancel') || msg.contains('canceled')) {
        return '로그인이 취소되었어요.';
      }
      return e.toString().replaceFirst('Exception: ', '');
    }
  }

  Future<void> _clearSession(SharedPreferences prefs) async {
    await prefs.remove(_kLogin);
    await prefs.remove(_kNickname);
    await prefs.remove(_kSessionExp);
    await prefs.remove(_kAccountId);
    await prefs.remove(_kAuthProvider);
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
            source: _userRole == 'owner' ? 'owner' : 'user',
            userId: userId,
            nickname: _nickname);
        _restaurants = _withOperatingHours(await repo.fetchAll());
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

  /// 닉네임 변경. 성공 시 null, 실패 시 메시지 반환.
  Future<String?> updateNickname(String nick) async {
    final trimmed = nick.trim();
    if (trimmed.isEmpty) return '닉네임을 입력해주세요.';
    if (trimmed == _nickname.trim()) return null;

    if (_hasSupabaseSession) {
      final available = await _profileRepo.isNicknameAvailable(trimmed);
      if (available == false) {
        return '이미 사용 중인 닉네임이에요.';
      }
      if (available == null) {
        return '닉네임 확인에 실패했어요. 잠시 후 다시 시도해주세요.';
      }
    }

    final prefs = await SharedPreferences.getInstance();

    if (_hasSupabaseSession) {
      await _syncMetadata({'nickname': trimmed});
      final user = SupabaseService.client.auth.currentUser;
      if (user != null) {
        try {
          final updated = await _profileRepo.updateNickname(user.id, trimmed);
          if (!updated) {
            await _profileRepo.upsertNickname(
              SupabaseService.client.auth.currentUser ?? user,
              trimmed,
            );
          }
        } on PostgrestException catch (e) {
          if (e.code == '23505') {
            return '이미 사용 중인 닉네임이에요.';
          }
          debugPrint('[Profile] updateNickname: ${e.message}');
          return '닉네임 저장에 실패했어요.';
        }
      }
    }

    _nickname = trimmed;
    await prefs.setString(_kNickname, trimmed);
    notifyListeners();
    return null;
  }


  /// Google Places로 매장 등록. 성공 시 6자리 ownerCode 반환.
  Future<String?> addRestaurantFromGooglePlace({
    required String placeId,
    required String name,
    required String address,
    required double latitude,
    required double longitude,
    required String category,
    required String area,
    String imageUrl = '',
    String hours = BusinessHoursData.defaultHours,
    String hoursDisplay = '',
    List<Map<String, dynamic>> hoursPeriods = const [],
  }) async {
    final repo = _restaurantRepo;
    if (repo == null) return null;
    if (!_canAdminOps) {
      debugPrint('[addRestaurantFromGooglePlace] 관리자 로그인 필요');
      return null;
    }

    try {
      final existing = await repo.findRestaurantIdByGooglePlaceId(placeId);
      if (existing != null) return null;

      final restaurant = await repo.insert({
        'name': name,
        'category': category,
        'area': area,
        'address': address,
        'latitude': latitude,
        'longitude': longitude,
        'image_url': imageUrl,
        'hours': hours,
        if (hoursDisplay.isNotEmpty) 'hours_display': hoursDisplay,
        if (hoursPeriods.isNotEmpty) 'hours_periods': hoursPeriods,
        'google_place_id': placeId,
      });

      _restaurants = _withOperatingHours(await repo.fetchAll());
      notifyListeners();
      return restaurant.ownerCode;
    } catch (e, st) {
      debugPrint('[Supabase] addRestaurantFromGooglePlace failed: $e\n$st');
      return null;
    }
  }

  // ── 어드민: 매장 관리 ──
  Future<void> addRestaurant(Map<String, dynamic> data) async {
    final repo = _restaurantRepo;
    if (repo != null) {
      if (!_canAdminOps) {
        debugPrint('[addRestaurant] 관리자 로그인 필요');
        return;
      }
      try {
        await repo.insert(data);
        _restaurants = _withOperatingHours(await repo.fetchAll());
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
      latitude: (data['latitude'] as num?)?.toDouble() ?? 0,
      longitude: (data['longitude'] as num?)?.toDouble() ?? 0,
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
      if (!_canAdminOps) {
        debugPrint('[editRestaurant] 관리자 로그인 필요');
        return;
      }
      try {
        await repo.update(id, data);
        _restaurants = _withOperatingHours(await repo.fetchAll());
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
        latitude: r.latitude,
        longitude: r.longitude,
        x: r.x,
        y: r.y,
        hours: data['hours'] as String? ?? r.hours,
        reports: r.reports,
        ownerCode: r.ownerCode,
        ownerRegistered: r.ownerRegistered,
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
      if (!_canAdminOps) {
        debugPrint('[deleteRestaurant] 관리자 로그인 필요');
        return;
      }
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
    if (!_canAdminOps) {
      debugPrint('[generateOwnerCode] 관리자 로그인 필요');
      return;
    }
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
          latitude: r.latitude,
          longitude: r.longitude,
          x: r.x,
          y: r.y,
          hours: r.hours,
          reports: r.reports,
          menu: r.menu,
          popularityScore: r.popularityScore,
          manualRank: r.manualRank,
          ownerCode: code,
          ownerRegistered: r.ownerRegistered,
        );
      }).toList();
      notifyListeners();
    } catch (e, st) {
      debugPrint('[Supabase] generateOwnerCode failed: $e\n$st');
    }
  }

  Future<String?> verifyOwnerCode(String code) async {
    final trimmed = code.trim();
    if (trimmed.length != 6) return 'INVALID_CODE';

    final repo = _restaurantRepo;
    String? restaurantId;

    if (repo != null) {
      try {
        restaurantId = await repo.claimOwnerByCode(trimmed);
      } on PostgrestException catch (e) {
        final msg = e.message;
        if (msg.contains('ALREADY_USED')) return 'ALREADY_USED';
        debugPrint('[verifyOwnerCode] RPC: $msg');
        return 'INVALID_CODE';
      } catch (e) {
        debugPrint('[verifyOwnerCode] RPC failed: $e');
        // 오프라인/미배포 RPC: 로컬 폴백
        final found =
            _restaurants.where((r) => r.ownerCode == trimmed);
        if (found.isEmpty) return 'INVALID_CODE';
        if (found.first.ownerRegistered) return 'ALREADY_USED';
        restaurantId = found.first.id;
      }
    } else {
      final found = _restaurants.where((r) => r.ownerCode == trimmed);
      if (found.isEmpty) return 'INVALID_CODE';
      if (found.first.ownerRegistered) return 'ALREADY_USED';
      restaurantId = found.first.id;
    }

    try {
      _userRole = 'owner';
      _ownerRestaurantIds = [restaurantId];

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kUserRole, 'owner');
      await prefs.setString(_kOwnerIds, jsonEncode([restaurantId]));

      await _syncMetadata({
        'role': 'owner',
        'restaurant_ids': [restaurantId],
      });

      if (repo != null) {
        _restaurants = _withOperatingHours(await repo.fetchAll());
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
      if (fetched.isNotEmpty) {
        _restaurants = fetched.map(_applyOperatingHours).toList();
      }
    } catch (e, st) {
      debugPrint('[Supabase] load restaurants failed: $e\n$st');
    }
  }

  /// 영업시간 외에는 혼잡도 오버라이드보다 영업안함 우선
  List<Restaurant> _withOperatingHours(List<Restaurant> list) =>
      list.map(_applyOperatingHours).toList();

  Restaurant _applyOperatingHours(Restaurant r) {
    final bh = BusinessHoursData.fromDescription({
      'hours': r.hours,
      'hours_display': r.hours,
      'hours_periods': r.hoursPeriods,
    });
    if (!bh.isOpenAt(DateTime.now())) {
      return r.copyWith(status: '영업안함', updated: 0);
    }
    return r;
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
