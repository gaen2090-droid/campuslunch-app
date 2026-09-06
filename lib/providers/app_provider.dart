import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../constants/app_links.dart';
import '../constants/email_auth.dart';
import '../constants/legal_terms.dart';
import '../constants/stats_excluded_account.dart';
import '../utils/nickname_generator.dart';
import '../utils/app_session_id.dart';
import '../utils/device_install_id.dart';
import '../data/analytics_repository.dart';
import '../data/auth_repository.dart';
import '../data/community_repository.dart';
import '../data/feedback_repository.dart';
import '../data/legal_consent_repository.dart';
import '../data/profile_repository.dart';
import '../data/push_config_repository.dart';
import '../data/supabase_restaurant_repository.dart';
import '../models/account.dart';
import '../models/crowd_report.dart';
import '../models/dashboard_metrics.dart';
import '../models/owner_seat_update.dart';
import '../models/restaurant.dart';
import '../models/reward.dart';
import '../data/reward_repository.dart';
import '../services/apple_auth_service.dart';
import '../services/google_auth_service.dart';
import '../services/kakao_auth_service.dart';
import '../services/supabase_service.dart';
import '../services/device_permission_service.dart';
import '../services/fcm_push_service.dart';
import '../services/push_notification_service.dart';
import '../utils/app_startup.dart';
import '../utils/available_restaurant_ranking.dart';
import '../utils/business_hours.dart';
import '../utils/profanity_filter.dart';

class AppProvider extends ChangeNotifier {
  // ── 앱 상태 ──
  String _stage = 'splash'; // splash | permissions_consent | legal_terms_consent | login | app | admin
  String get stage => _stage;

  // ── 인증 ──
  bool _isLoggedIn = false;
  String _nickname = '';
  String _accountId = '';
  String _userRole = 'user';
  List<String> _ownerRestaurantIds = [];
  String? _selectedOwnerRestaurantId;

  bool get isLoggedIn => _isLoggedIn;
  String get nickname => _nickname;
  String get accountId => _accountId;
  String get userRole => _userRole;
  List<String> get ownerRestaurantIds => _ownerRestaurantIds;

  /// Screen/Widget는 [CommunityRepository]를 직접 생성하지 말고 이 accessor를 쓴다.
  CommunityRepository get community => CommunityRepository();

  /// Supabase auth user id (세션 없으면 null)
  String? get currentUserId =>
      SupabaseService.isReady
          ? SupabaseService.client.auth.currentUser?.id
          : null;

  /// 로그인 이메일 (없으면 빈 문자열)
  String get authEmail =>
      SupabaseService.isReady
          ? (SupabaseService.client.auth.currentUser?.email ?? '')
          : '';

  /// OAuth provider: kakao | google | apple | email 등
  String? get authLoginProvider {
    if (!SupabaseService.isReady) return null;
    final user = SupabaseService.client.auth.currentUser;
    if (user == null) return null;
    return user.appMetadata['provider'] as String?;
  }

  /// 사장님 탭들(제보/마이페이지)이 공유하는 현재 선택 매장 ID.
  /// 선택값이 더 이상 소유 목록에 없으면(삭제 등) 첫 번째 매장으로 폴백.
  String? get selectedOwnerRestaurantId {
    if (_ownerRestaurantIds.isEmpty) return null;
    if (_selectedOwnerRestaurantId != null &&
        _ownerRestaurantIds.contains(_selectedOwnerRestaurantId)) {
      return _selectedOwnerRestaurantId;
    }
    return _ownerRestaurantIds.first;
  }

  void selectOwnerRestaurant(String restaurantId) {
    if (_selectedOwnerRestaurantId == restaurantId) return;
    _selectedOwnerRestaurantId = restaurantId;
    notifyListeners();
  }

  /// 사장님이 커뮤니티에서 "OO 가게 사장님"으로 표시될 매장 (제보/마이 선택과 별개).
  /// 매장이 1개뿐이면 선택 UI 없이 그 매장으로 항상 고정.
  String? _activeOwnerRestaurantId;

  String? get communityActiveOwnerRestaurantId {
    if (_ownerRestaurantIds.length == 1) return _ownerRestaurantIds.first;
    if (_activeOwnerRestaurantId != null &&
        _ownerRestaurantIds.contains(_activeOwnerRestaurantId)) {
      return _activeOwnerRestaurantId;
    }
    return null;
  }

  Future<void> setCommunityActiveOwnerRestaurant(String restaurantId) async {
    if (_activeOwnerRestaurantId == restaurantId) return;
    _activeOwnerRestaurantId = restaurantId;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kActiveOwnerRestaurantId, restaurantId);
      await community.setActiveOwnerRestaurant(restaurantId);
    } catch (e, st) {
      debugPrint('[setCommunityActiveOwnerRestaurant] failed: $e\n$st');
    }
  }

  /// 약관 동의 + 추천인 코드 입력까지 끝나고 메인 화면에서 1회 표시
  bool _showSignupCompleteMessage = false;
  bool get showSignupCompleteMessage => _showSignupCompleteMessage;

  /// OTP 인증은 끝났지만 아직 약관 동의/추천인 코드 단계가 남아있어
  /// 축하 메시지 표시를 미뤄둔 상태
  bool _pendingSignupCompleteMessage = false;

  /// 일반('app') 진입 직전 거치는 단계. 최초 로그인 때만 사용법 가이드를 보여준다.
  Future<String> _postAppStage(SharedPreferences prefs) async {
    final seen = prefs.getBool(_kUsageGuideSeen) ?? false;
    if (!seen) return 'usage_guide';

    final userId = _sessionUserId(prefs);
    if (isReferralPromptPending(prefs, userId)) return 'referral_code';

    return 'app';
  }

  Future<void> completeUsageGuide() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kUsageGuideSeen, true);
    _stage = await _postAppStage(prefs);
    if (hasOwnerTab) _mainTabIndex = 0;
    notifyListeners();
  }

  /// 홈 화면 코치마크(필터/혼잡도/스탬프/지도 안내)를 아직 안 봤으면 true.
  /// SharedPreferences 조회가 비동기라 캐시해두고, 앱 시작 시 1회 로드한다.
  bool? _coachMarkSeenCache;

  Future<bool> shouldShowCoachMark() async {
    if (_coachMarkSeenCache != null) return !_coachMarkSeenCache!;
    final prefs = await SharedPreferences.getInstance();
    _coachMarkSeenCache = prefs.getBool(_kCoachMarkSeen) ?? false;
    return !_coachMarkSeenCache!;
  }

  void completeCoachMark() {
    _coachMarkSeenCache = true;
    SharedPreferences.getInstance()
        .then((prefs) => prefs.setBool(_kCoachMarkSeen, true));
  }

  /// 사장님 인증 승인 후 사장님 모드 첫 진입 시 1회만 보여줄 사용법 가이드.
  bool? _ownerUsageGuideSeenCache;

  Future<bool> shouldShowOwnerUsageGuide() async {
    if (_ownerUsageGuideSeenCache != null) return !_ownerUsageGuideSeenCache!;
    final prefs = await SharedPreferences.getInstance();
    _ownerUsageGuideSeenCache = prefs.getBool(_kOwnerUsageGuideSeen) ?? false;
    return !_ownerUsageGuideSeenCache!;
  }

  void completeOwnerUsageGuide() {
    _ownerUsageGuideSeenCache = true;
    SharedPreferences.getInstance()
        .then((prefs) => prefs.setBool(_kOwnerUsageGuideSeen, true));
  }

  bool? _communityGuidelineSeenCache;

  Future<bool> shouldShowCommunityGuideline() async {
    if (_communityGuidelineSeenCache != null) return !_communityGuidelineSeenCache!;
    final prefs = await SharedPreferences.getInstance();
    _communityGuidelineSeenCache = prefs.getBool(_kCommunityGuidelineSeen) ?? false;
    return !_communityGuidelineSeenCache!;
  }

  void completeCommunityGuideline() {
    _communityGuidelineSeenCache = true;
    SharedPreferences.getInstance()
        .then((prefs) => prefs.setBool(_kCommunityGuidelineSeen, true));
  }

  void clearSignupCompleteMessage() {
    if (!_showSignupCompleteMessage) return;
    _showSignupCompleteMessage = false;
    notifyListeners();
  }

  // ── 필터 (세션 내 유지, 앱 재시작 시 초기화) ──
  String homeFilterSortBy = '최신순';
  Set<String> homeFilterRegions = {'전체'};
  Set<String> homeFilterCuisines = {'전체'};
  bool homeFilterBookmarkOnly = false;

  void setHomeFilter({
    required String sortBy,
    required Set<String> regions,
    required Set<String> cuisines,
    required bool bookmarkOnly,
  }) {
    homeFilterSortBy = sortBy;
    homeFilterRegions = regions;
    homeFilterCuisines = cuisines;
    homeFilterBookmarkOnly = bookmarkOnly;
    notifyListeners();
  }

  // ── 지도 탭 필터 (세션 내 유지) ──
  // MapScreen은 main_screen.dart에서 IndexedStack 밖에 조건부로 마운트되므로
  // (PlatformView가 비활성 IndexedStack 자식에 있으면 iOS 터치가 막히는 문제 회피),
  // 탭을 벗어났다 돌아오기만 해도 위젯 State가 완전히 새로 생성된다. 홈 필터와
  // 마찬가지로 provider에 백업해야 탭 이동 후에도 유지된다.
  Set<String> mapFilterRegions = {'전체'};
  Set<String> mapFilterCuisines = {'전체'};
  bool mapFilterBookmarkOnly = false;
  String mapFilterReport = '전체';

  void setMapFilter({
    required Set<String> regions,
    required Set<String> cuisines,
    required bool bookmarkOnly,
    required String report,
  }) {
    mapFilterRegions = regions;
    mapFilterCuisines = cuisines;
    mapFilterBookmarkOnly = bookmarkOnly;
    mapFilterReport = report;
    notifyListeners();
  }

  // 각 더보기 페이지 필터: key = RestaurantListMode.name
  final Map<String, String> _listFilterSortBy = {};
  final Map<String, Set<String>> _listFilterRegions = {};
  final Map<String, Set<String>> _listFilterCuisines = {};
  final Map<String, bool> _listFilterBookmarkOnly = {};

  String listFilterSortBy(String mode) => _listFilterSortBy[mode] ?? '최신순';
  Set<String> listFilterRegions(String mode) => _listFilterRegions[mode] ?? {'전체'};
  Set<String> listFilterCuisines(String mode) => _listFilterCuisines[mode] ?? {'전체'};
  bool listFilterBookmarkOnly(String mode) => _listFilterBookmarkOnly[mode] ?? false;

  void setListFilter(String mode, {
    required String sortBy,
    required Set<String> regions,
    required Set<String> cuisines,
    required bool bookmarkOnly,
  }) {
    _listFilterSortBy[mode] = sortBy;
    _listFilterRegions[mode] = regions;
    _listFilterCuisines[mode] = cuisines;
    _listFilterBookmarkOnly[mode] = bookmarkOnly;
    notifyListeners();
  }

  // ── 설정 ──
  bool _locationMode = false;
  bool _notificationEnabled = false;
  bool _lunchPushEnabled = true;
  bool _dinnerPushEnabled = true;
  bool _communityCommentsPushEnabled = true;
  bool _rewardPushEnabled = true;
  bool _newsPushEnabled = true;
  bool _useAlgorithmRanking = true;
  int _ownerInfluence = 80;
  int _mainTabIndex = 0;

  /// 소유 매장(restaurants.owner_id)이 있으면 사장님 전용 3탭(제보/커뮤니티/마이) 앱으로 전환
  bool get hasOwnerTab {
    if (_ownerRestaurantIds.isEmpty) return false;
    if (_restaurants.isEmpty) return true;
    return _ownerRestaurantIds.any(
      (id) => _restaurants.any((r) => r.id.toString() == id),
    );
  }

  /// 사장님 모드: 0=제보, 1=매장관리, 2=커뮤니티, 3=마이. 일반 모드: 0=홈, 1=지도, 2=커뮤니티, 3=MY.
  int get homeTabIndex => hasOwnerTab ? 0 : 0;

  int get communityTabIndex => hasOwnerTab ? 2 : 2;

  int get myTabIndex => hasOwnerTab ? 3 : 3;

  String? _pendingCommunityPostId;
  String? get pendingCommunityPostId => _pendingCommunityPostId;

  String? consumePendingCommunityPostId() {
    final id = _pendingCommunityPostId;
    _pendingCommunityPostId = null;
    return id;
  }

  String? _pendingCollectionId;
  String? get pendingCollectionId => _pendingCollectionId;

  String? consumePendingCollectionId() {
    final id = _pendingCollectionId;
    _pendingCollectionId = null;
    return id;
  }

  bool _pendingOwnerRejectionPush = false;
  bool get pendingOwnerRejectionPush => _pendingOwnerRejectionPush;

  bool consumePendingOwnerRejectionPush() {
    final v = _pendingOwnerRejectionPush;
    _pendingOwnerRejectionPush = false;
    return v;
  }

  bool get hasPendingAppLink => _pendingAppLink != null;

  bool get locationMode => _locationMode;
  bool get notificationEnabled => _notificationEnabled;
  bool get lunchPushEnabled => _lunchPushEnabled;
  bool get dinnerPushEnabled => _dinnerPushEnabled;
  bool get communityCommentsPushEnabled => _communityCommentsPushEnabled;
  bool get rewardPushEnabled => _rewardPushEnabled;
  bool get newsPushEnabled => _newsPushEnabled;
  bool get useAlgorithmRanking => _useAlgorithmRanking;
  int get ownerInfluence => _ownerInfluence;
  int get mainTabIndex => _mainTabIndex;

  // ── 매장 ──
  List<Restaurant> _restaurants = [];
  List<Restaurant> get restaurants => _restaurants;
  int _restaurantRefreshGen = 0;
  bool _restaurantsLoading = true;
  /// true: 최초 로딩 중(네트워크 응답 전). 실패해도 한 번 끝나면 false.
  bool get restaurantsLoading => _restaurantsLoading;
  bool _restaurantsLoadFailed = false;
  /// true: 마지막 로드 시도가 네트워크/서버 오류로 실패함(매장이 진짜 0개인 것과 구분).
  bool get restaurantsLoadFailed => _restaurantsLoadFailed;

  bool _rewardLoadFailed = false;
  /// true: 스탬프/기프티콘 조회가 모두 실패함(빈 목록과 구분).
  bool get rewardLoadFailed => _rewardLoadFailed;

  // ── 북마크 ──
  Set<String> _bookmarks = {};
  Set<String> get bookmarks => _bookmarks;

  // ── 대시보드 지표 ──
  DashboardMetrics _metrics = DashboardMetrics.empty;
  DashboardMetrics get metrics => _metrics;

  // ── 리워드 ──
  UserReward _reward = UserReward.empty;
  UserReward get reward => _reward;
  List<Gifticon> _myGifticons = [];
  List<Gifticon> get myGifticons => _myGifticons;
  Set<String> _hiddenGifticonIds = {};
  List<Gifticon> get visibleMyGifticons =>
      _myGifticons.where((g) => !_hiddenGifticonIds.contains(g.id)).toList();

  Set<String> _seenGifticonIds = {};
  bool get hasUnseenCoupon =>
      visibleMyGifticons.any((g) => !_seenGifticonIds.contains(g.id));

  Future<void> markCouponBoxSeen() async {
    final ids = visibleMyGifticons.map((g) => g.id).toSet();
    if (ids.difference(_seenGifticonIds).isEmpty) return;
    _seenGifticonIds = {..._seenGifticonIds, ...ids};
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_kSeenGifticons, _seenGifticonIds.toList());
  }

  RewardRepository? get _rewardRepo =>
      SupabaseService.isReady ? RewardRepository(SupabaseService.client) : null;

  // ── 키 ──
  static const _kLocation = 'cl_location_mode';
  static const _kPermissionsConsentSeen = 'cl_permissions_consent_seen';
  static const _kLegalTermsAcceptedUsers = 'cl_legal_terms_accepted_users';
  static const _kPendingLegalTermsUsers = 'cl_pending_legal_terms_users';
  static const _kUsageGuideSeen = 'cl_usage_guide_seen';
  static const _kOwnerUsageGuideSeen = 'cl_owner_usage_guide_seen';
  static const _kCoachMarkSeen = 'cl_coach_mark_seen';
  static const _kCommunityGuidelineSeen = 'cl_community_guideline_seen';
  static const _kLogin = 'cl_logged_in';
  static const _kNickname = 'cl_nickname';
  static const _kPush = 'cl_push_enabled';
  static const _kLunchPush = 'cl_push_lunch';
  static const _kDinnerPush = 'cl_push_dinner';
  static const _kCommunityCommentsPush = 'cl_push_community_comments';
  static const _kRewardPush = 'cl_push_reward';
  static const _kNewsPush = 'cl_push_news';
  static const _kSessionExp = 'cl_session_exp';
  static const _kUserRole = 'cl_user_role';
  static const _kOwnerIds = 'cl_owner_restaurant_ids';
  static const _kAccountId = 'cl_account_id';
  static const _kAccounts = 'cl_accounts';
  static const _kBookmarks = 'cl_bookmarks';
  static const _kOverrides = 'cl_restaurant_overrides';
  static const _kUseAlgorithmRanking = 'cl_use_algorithm_ranking';
  static const _kAwaitingEmailConfirm = 'cl_awaiting_email_confirm';
  static const _kSeenGifticons = 'cl_seen_gifticon_ids';
  static const _kPendingSignupPassword = 'cl_pending_signup_password';
  static const _kPendingSignupNickname = 'cl_pending_signup_nickname';
  static const _kAuthProvider = 'cl_auth_provider';
  static const _kHiddenGifticons = 'cl_hidden_gifticon_ids';
  static const _kReferralPromptPendingUsers = 'cl_referral_prompt_pending_users';
  static const _kReferralPromptDoneUsers = 'cl_referral_prompt_done_users';
  static const _kReferralCodeFromInviteLink = 'cl_referral_code_from_invite';
  static const _kActiveOwnerRestaurantId = 'cl_community_active_owner_restaurant';
  /// 계정별 첫 제보 시 StoreKit/Play 리뷰 요청을 이미 했는지
  static const _kStoreReviewFirstReportAccounts =
      'cl_store_review_first_report_accounts';

  String? _pendingSignupPasswordMem;
  String? _pendingSignupNicknameMem;

  final Set<String> _storeReviewFirstReportAccounts = {};

  static const _sessionDuration = Duration(days: 30);

  SupabaseRestaurantRepository? get _restaurantRepo =>
      SupabaseService.isReady ? SupabaseRestaurantRepository() : null;

  /// Supabase admin 세션 + role=admin (로컬 admin/admin123 제외)
  bool get _canAdminOps =>
      _hasSupabaseSession && _userRole == 'admin';

  StreamSubscription<AuthState>? _authSub;
  /// 스플래시·init() 중 notifyListeners 억제 (AnimatedSwitcher 크래시 방지)
  bool _bootstrapping = true;
  DateTime? _splashStartedAt;
  Uri? _queuedIncomingUri;
  AppLinkTarget? _pendingAppLink;
  int? _pendingRestaurantLinkNo;
  // restaurantId → 마지막 제보 시각 (5분 재제보 금지)
  final Map<String, DateTime> _lastReportTime = {};
  DateTime _tabEnteredAt = DateTime.now();
  final ProfileRepository _profileRepo = ProfileRepository();
  final AuthRepository _authRepo = AuthRepository();
  final AnalyticsRepository _analyticsRepo = AnalyticsRepository();
  final PushConfigRepository _pushConfigRepo = PushConfigRepository();
  final LegalConsentRepository _legalConsentRepo = LegalConsentRepository();
  final FeedbackRepository _feedbackRepo = FeedbackRepository();
  Map<String, dynamic>? _pendingRemotePushData;

  @override
  void dispose() {
    _authSub?.cancel();
    super.dispose();
  }

  @override
  void notifyListeners() {
    if (_bootstrapping) return;
    super.notifyListeners();
  }

  void _finishBootstrap() {
    if (!_bootstrapping) return;
    _bootstrapping = false;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      super.notifyListeners();
      final queued = _queuedIncomingUri;
      _queuedIncomingUri = null;
      if (queued != null) handleIncomingUri(queued);
      _flushPendingRemotePush();
    });
    // 파이프라인이 유휴 상태면 post-frame 콜백이 예약만 되고 실행되지 않을 수 있어
    // (스플래시가 끝나지 않는 버그의 원인) 프레임을 명시적으로 요청해 즉시 flush한다.
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  /// App Link 수신. invite ref는 미로그인·가입 중에도 저장. 나머지는 stage=app 일 때만 라우팅.
  void handleIncomingUri(Uri uri) {
    if (_bootstrapping) {
      _queuedIncomingUri = uri;
      return;
    }
    final parsed = AppLinks.parse(uri);
    if (parsed == null) return;

    final ref = parsed.referralCode;
    if (ref != null && ref.isNotEmpty) {
      unawaited(_saveReferralCodeFromInviteLink(ref));
    }

    if (!_isLoggedIn || _stage != 'app') {
      debugPrint(
        '[AppLink] nav deferred (loggedIn=$_isLoggedIn stage=$_stage ref=$ref): $uri',
      );
      return;
    }
    _pendingAppLink = parsed.target;
    _pendingRestaurantLinkNo = parsed.linkNo;
    notifyListeners();
  }

  Future<void> _saveReferralCodeFromInviteLink(String code) async {
    final trimmed = code.trim();
    if (trimmed.isEmpty) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kReferralCodeFromInviteLink, trimmed);
      debugPrint('[AppLink] saved invite referral code');
    } catch (e, st) {
      debugPrint('[AppLink] save invite referral failed: $e\n$st');
    }
  }

  /// 추천인 코드 입력 화면에 미리 채움 (아직 소비하지 않음)
  Future<String?> peekReferralCodeFromInviteLink() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final code = prefs.getString(_kReferralCodeFromInviteLink)?.trim();
      if (code == null || code.isEmpty) return null;
      return code;
    } catch (e, st) {
      debugPrint('[AppLink] peek invite referral failed: $e\n$st');
      return null;
    }
  }

  /// 추천인 코드 적용 성공 후 1회 소비
  Future<void> consumeReferralCodeFromInviteLink() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_kReferralCodeFromInviteLink);
    } catch (e, st) {
      debugPrint('[AppLink] consume invite referral failed: $e\n$st');
    }
  }

  /// MainScreen에서 소비 후 null 반환
  ({AppLinkTarget target, int? linkNo})? consumePendingAppLink() {
    final target = _pendingAppLink;
    final linkNo = _pendingRestaurantLinkNo;
    _pendingAppLink = null;
    _pendingRestaurantLinkNo = null;
    if (target == null) return null;
    return (target: target, linkNo: linkNo);
  }

  Restaurant? restaurantByLinkNo(int linkNo) {
    if (linkNo <= 0) return null;
    for (final r in _restaurants) {
      if (r.linkNo == linkNo) return r;
    }
    return null;
  }

  Future<Restaurant?> fetchRestaurantByLinkNo(int linkNo) async {
    final cached = restaurantByLinkNo(linkNo);
    if (cached != null) return cached;
    final repo = _restaurantRepo;
    if (repo == null) return null;
    final fetched = await repo.fetchByLinkNo(linkNo);
    if (fetched == null) return null;
    final idx = _restaurants.indexWhere((r) => r.id == fetched.id);
    if (idx >= 0) {
      _restaurants[idx] = fetched;
    }
    return fetched;
  }

  /// 스플래시 → 다음 화면 전환 기준
  ///
  /// 1. [main] Supabase·환경키만 동기 초기화 후 runApp (카카오맵·푸시·Google은 첫 프레임 이후)
  /// 2. [init] SharedPreferences 복원 → 최소 [kMinSplashDuration] 스플래시 표시
  /// 3. 매장·리워드는 백그라운드 로드 (홈/지도는 restaurantsLoading 으로 스켈레톤)
  /// 4. stage 결정:
  ///    - Supabase 세션 있음 → prefs 복원 후 메인(또는 권한·가이드), 프로필은 백그라운드 동기화
  ///    - 로컬 세션 만료 → login
  ///    - 로컬 로그인 유지 → usage_guide / app
    ///    - 비로그인 → permissions(최초) / login
    ///    - 회원가입 직후 → legal_terms_consent → app
  Future<void> init() async {
    _bootstrapping = true;
    _splashStartedAt = DateTime.now();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kPendingSignupPassword);

    _useAlgorithmRanking = prefs.getBool(_kUseAlgorithmRanking) ?? true;
    _hiddenGifticonIds =
        Set<String>.from(prefs.getStringList(_kHiddenGifticons) ?? const []);
    _seenGifticonIds =
        Set<String>.from(prefs.getStringList(_kSeenGifticons) ?? const []);
    _storeReviewFirstReportAccounts
      ..clear()
      ..addAll(prefs.getStringList(_kStoreReviewFirstReportAccounts) ?? const []);

    _restaurants = [];
    unawaited(_loadRestaurantsFromSupabase());
    unawaited(_loadBannedWords());

    final bookmarksJson = prefs.getString(_kBookmarks);
    if (bookmarksJson != null) {
      _bookmarks = Set<String>.from(
        (jsonDecode(bookmarksJson) as List).map((e) => e.toString()),
      );
    }

    try {
      if (SupabaseService.isReady) {
        final session = SupabaseService.client.auth.currentSession;
        final user = SupabaseService.client.auth.currentUser;
        if (session != null &&
            user != null &&
            _isSupabaseSessionRestorable(user)) {
          final prefsLoggedIn = prefs.getBool(_kLogin) ?? false;
          if (prefsLoggedIn) {
            await _restoreSessionFromPrefs(prefs);
            if (hasOwnerTab) _mainTabIndex = 0;
            await _leaveSplash(await _resolveStageAfterSplash(prefs));
          } else {
            await _onSupabaseSignedIn(user, updateStage: false, notify: false);
            await _leaveSplash(await _resolveStageAfterSplash(prefs));
          }
          if (_hasPermissionsConsent(prefs)) {
            unawaited(triggerDeferredStartup());
          }
          _bindAuthListener();
          if (prefsLoggedIn) {
            unawaited(_onSupabaseSignedIn(user, updateStage: false, notify: false));
          }
          return;
        }
      }

      final loggedIn = prefs.getBool(_kLogin) ?? false;
      final sessionExp = prefs.getInt(_kSessionExp) ?? 0;
      if (loggedIn && DateTime.now().millisecondsSinceEpoch > sessionExp) {
        await _clearSession(prefs);
        await _leaveSplash('login');
        if (SupabaseService.isReady) _bindAuthListener();
        return;
      }

      if (loggedIn) {
        await _restoreSessionFromPrefs(prefs);
        if (SupabaseService.isReady &&
            SupabaseService.client.auth.currentUser != null) {
          unawaited(_syncOwnerRestaurantIdsFromDb(prefs));
        }
        unawaited(fetchMyReward());
        if (hasOwnerTab) _mainTabIndex = 0;
        await _leaveSplash(await _resolveStageAfterSplash(prefs));
      } else {
        await _leaveSplash(await _resolveStageAfterSplash(prefs));
      }

      if (_hasPermissionsConsent(prefs)) {
        unawaited(triggerDeferredStartup());
      }

      _bindAuthListener();
    } catch (e, st) {
      debugPrint('[AppProvider] init failed: $e\n$st');
      await _leaveSplash('login');
      if (SupabaseService.isReady) _bindAuthListener();
    }
  }

  /// 스플래시 UI(stage=splash)를 최소 시간 유지한 뒤 다음 화면으로 전환
  Future<void> _leaveSplash(String nextStage) async {
    final started = _splashStartedAt ?? DateTime.now();
    await waitMinSplashDuration(started);
    _stage = nextStage;
    _finishBootstrap();
  }

  Future<void> _restoreSessionFromPrefs(SharedPreferences prefs) async {
    _isLoggedIn = true;
    _nickname = prefs.getString(_kNickname) ?? '';
    _accountId = prefs.getString(_kAccountId) ?? '';
    _userRole = prefs.getString(_kUserRole) ?? 'user';
    _ownerRestaurantIds = List<String>.from(
      jsonDecode(prefs.getString(_kOwnerIds) ?? '[]') as List,
    );
    if (_userRole == 'owner') {
      _userRole = 'user';
      await prefs.setString(_kUserRole, 'user');
    }
    _locationMode = prefs.getBool(_kLocation) ?? false;
    _notificationEnabled = prefs.getBool(_kPush) ?? false;
    _lunchPushEnabled = prefs.getBool(_kLunchPush) ?? _notificationEnabled;
    _dinnerPushEnabled = prefs.getBool(_kDinnerPush) ?? _notificationEnabled;
    _communityCommentsPushEnabled =
        prefs.getBool(_kCommunityCommentsPush) ?? _notificationEnabled;
    _rewardPushEnabled = prefs.getBool(_kRewardPush) ?? _notificationEnabled;
    _newsPushEnabled = prefs.getBool(_kNewsPush) ?? _notificationEnabled;
  }

  // ── 로그인 ──
  Future<bool> login(String email, String password) async {
    if (kDebugMode) {
    if (email == 'owner' && password == 'owner123') {
      await _saveSession(
          await SharedPreferences.getInstance(),
          Account(
              id: 'owner',
              password: 'owner123',
              nickname: '사장님',
              role: 'user',
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
          debugPrint('[Supabase] email not confirmed: ${e.message}');
          return false;
        }
        debugPrint('[Supabase] login AuthException: ${e.message}');
        if (!kDebugMode) return false;
      } catch (e) {
        debugPrint('[Supabase] login failed: $e');
        if (!kDebugMode) return false;
      }
    } else if (!kDebugMode) {
      // 릴리즈는 Supabase 필수
      return false;
    }

    // 로컬 폴백 — 디버그 빌드에서만
    if (!kDebugMode) return false;
    final prefs = await SharedPreferences.getInstance();
    final accounts = _loadAccounts(prefs);
    final account = accounts
        .where((a) => a.id == email && a.password == password)
        .firstOrNull;
    if (account == null) return false;
    await _saveSession(prefs, account);
    return true;
  }

  /// 이메일 회원가입
  Future<String?> register(String email, String password, String nick) async {
    final trimmedNick = nick.trim();
    if (trimmedNick.isNotEmpty) {
      final taken = await _profileRepo.isNicknameTaken(trimmedNick);
      if (taken == true) return '이미 사용 중인 닉네임이에요.';
    }
    final nickname = trimmedNick.isEmpty
        ? await generateAvailableNickname(_profileRepo.isNicknameTaken)
        : trimmedNick;
    final trimmedEmail = email.trim();

    if (SupabaseService.isReady) {
      final status = await _authRepo.checkEmailSignupStatus(trimmedEmail);
      switch (status) {
        case EmailSignupStatus.registered:
          return _emailAlreadyRegisteredMessage(trimmedEmail);
        case EmailSignupStatus.withdrawn:
          return _withdrawnCooldownMessage;
        case EmailSignupStatus.pending:
          await _storePendingSignupCredentials(
            password: password,
            nickname: nickname,
          );
          return await _resumePendingSignup(trimmedEmail);
        case EmailSignupStatus.invalid:
          return '이메일 형식을 확인해주세요.';
        case EmailSignupStatus.available:
        case EmailSignupStatus.unknown:
          break;
      }

      try {
        await _storePendingSignupCredentials(
          password: password,
          nickname: nickname,
        );
        return await _sendSignupOtpEmail(
          trimmedEmail,
          data: {'nickname': nickname},
        );
      } on AuthException catch (e) {
        final msg = e.message.toLowerCase();
        if (msg.contains('already') || msg.contains('registered')) {
          return _emailAlreadyRegisteredMessage(trimmedEmail);
        }
        final emailErr = _formatAuthEmailSendFailure(e);
        if (emailErr != null) return emailErr;
        return e.message;
      } catch (e) {
        debugPrint('[Supabase] register failed: $e');
        return '회원가입에 실패했어요. 잠시 후 다시 시도해주세요.';
      }
    }

    if (!kDebugMode) {
      return '서버에 연결할 수 없어요. 잠시 후 다시 시도해주세요.';
    }

    final prefs = await SharedPreferences.getInstance();
    final accounts = _loadAccounts(prefs);
    if (accounts.any((a) => a.id == email)) return '이미 사용 중인 이메일이에요.';
    if (accounts.any(
      (a) => a.nickname.trim().toLowerCase() == nickname.trim().toLowerCase(),
    )) {
      return '이미 사용 중인 닉네임이에요.';
    }
    final account = Account(id: email, password: password, nickname: nickname);
    _saveAccounts(prefs, [...accounts, account]);
    await _saveSession(prefs, account);
    return null;
  }

  static String _emailAlreadyRegisteredMessage(String email) =>
      '이미 가입된 이메일이에요.\n'
      '다른 이메일로 가입하거나 로그인해주세요.';

  static const String _withdrawnCooldownMessage =
      '탈퇴한 계정이에요.\n'
      '탈퇴 후 30일간은 같은 계정으로 재가입할 수 없어요.';

  /// Supabase Auth 메일 발송 실패 시 사용자 안내. 해당 없으면 null.
  static String? _formatAuthEmailSendFailure(AuthException e) {
    final msg = e.message.toLowerCase();
    if (msg.contains('rate') || msg.contains('limit')) {
      return '메일 발송 한도에 걸렸어요.\n'
          '잠시 후 다시 시도해주세요.';
    }
    if (msg.contains('confirmation email') ||
        msg.contains('sending confirmation') ||
        msg.contains('unexpected_failure')) {
      debugPrint('[Supabase] email send failed: ${e.message}');
      return '인증 메일 발송에 실패했어요.\n'
          '잠시 후 다시 시도하거나 스팸함을 확인해주세요.';
    }
    return null;
  }

  static String _oauthLoginBlockedMessage(OAuthLoginEmailStatus status) {
    switch (status) {
      case OAuthLoginEmailStatus.blockedEmail:
        return '이 이메일은 이미 이메일 가입으로 등록되어 있어요.\n'
            '이메일·비밀번호로 로그인해주세요.';
      case OAuthLoginEmailStatus.pending:
        return '이 이메일은 가입 인증이 진행 중이에요.\n'
            '메일의 인증번호 입력을 먼저 완료해주세요.';
      case OAuthLoginEmailStatus.withdrawn:
        return _withdrawnCooldownMessage;
      case OAuthLoginEmailStatus.blockedOther:
        return '이 이메일은 이미 다른 방식으로 가입된 계정이에요.\n'
            '가입할 때 사용한 로그인 방법을 이용해주세요.';
      case OAuthLoginEmailStatus.invalid:
        return '이메일을 확인할 수 없어요. 다른 계정으로 시도해주세요.';
      default:
        return '이 이메일로는 소셜 로그인을 할 수 없어요.';
    }
  }

  Future<void> _storePendingSignupCredentials({
    required String password,
    required String nickname,
  }) async {
    _pendingSignupPasswordMem = password;
    _pendingSignupNicknameMem = nickname;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kPendingSignupPassword);
    await prefs.setString(_kPendingSignupNickname, nickname);
  }

  Future<void> _clearPendingSignupCredentials() async {
    _pendingSignupPasswordMem = null;
    _pendingSignupNicknameMem = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kPendingSignupPassword);
    await prefs.remove(_kPendingSignupNickname);
  }

  /// signInWithOtp → Magic Link 템플릿에 {{ .Token }} 이 있으면 6자리 메일 발송
  Future<String?> _sendSignupOtpEmail(
    String email, {
    Map<String, dynamic>? data,
  }) async {
    await SupabaseService.client.auth.signInWithOtp(
      email: email.trim(),
      shouldCreateUser: true,
      data: data,
    );
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kAwaitingEmailConfirm, true);
    return 'pending_email';
  }

  /// auth.users 에는 있으나 인증 미완료 — OTP 재발송 후 인증 화면으로
  Future<String?> _resumePendingSignup(String email) async {
    try {
      await SupabaseService.client.auth.signInWithOtp(
        email: email.trim(),
        shouldCreateUser: false,
      );
    } on AuthException catch (e) {
      debugPrint('[Supabase] resend pending signup OTP: ${e.message}');
      final emailErr = _formatAuthEmailSendFailure(e);
      if (emailErr != null) return emailErr;
      return '인증번호 재발송에 실패했어요. (${e.message})';
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kAwaitingEmailConfirm, true);
    return 'pending_email';
  }

  /// 이메일 가입 인증번호 확인 (6자리, Supabase 최소값)
  Future<String?> verifySignupOtp(String email, String code) async {
    if (!SupabaseService.isReady) return '서버 연결을 확인해주세요.';

    final token = code.trim();
    if (!RegExp('^\\d{$emailSignupOtpLength}\$').hasMatch(token)) {
      return '${emailSignupOtpLength}자리 인증번호를 입력해주세요.';
    }

    try {
      AuthResponse res;
      try {
        res = await SupabaseService.client.auth.verifyOTP(
          type: OtpType.email,
          email: email.trim(),
          token: token,
        );
      } on AuthException catch (e) {
        final msg = e.message.toLowerCase();
        if (msg.contains('invalid') ||
            msg.contains('otp') ||
            msg.contains('token')) {
          res = await SupabaseService.client.auth.verifyOTP(
            type: OtpType.signup,
            email: email.trim(),
            token: token,
          );
        } else {
          rethrow;
        }
      }
      final user = res.user;
      if (user == null) return '인증에 실패했어요.';

      final prefs = await SharedPreferences.getInstance();
      final pendingPassword = _pendingSignupPasswordMem;
      final pendingNickname = _pendingSignupNicknameMem ??
          prefs.getString(_kPendingSignupNickname);
      if (pendingPassword != null && pendingPassword.length >= 6) {
        final data = <String, dynamic>{};
        if (pendingNickname != null && pendingNickname.isNotEmpty) {
          data['nickname'] = pendingNickname;
        }
        await SupabaseService.client.auth.updateUser(
          UserAttributes(
            password: pendingPassword,
            data: data.isEmpty ? null : data,
          ),
        );
      }

      _pendingSignupCompleteMessage = true;
      await prefs.remove(_kAwaitingEmailConfirm);
      await _clearPendingSignupCredentials();
      await _onSupabaseSignedIn(user, isNewSignup: true);
      return null;
    } on AuthException catch (e) {
      final msg = e.message.toLowerCase();
      if (msg.contains('expired') || msg.contains('otp_expired')) {
        return '인증번호가 만료됐어요. 다시 받아주세요.';
      }
      if (msg.contains('invalid') || msg.contains('otp')) {
        return '인증번호가 올바르지 않아요.';
      }
      return e.message;
    } catch (e) {
      debugPrint('[Supabase] verifyOTP failed: $e');
      return '인증에 실패했어요. 잠시 후 다시 시도해주세요.';
    }
  }

  /// 이메일 인증번호 재발송
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
      await SupabaseService.client.auth.signInWithOtp(
        email: email.trim(),
        shouldCreateUser: false,
      );
      return null;
    } on AuthException catch (e) {
      final emailErr = _formatAuthEmailSendFailure(e);
      return emailErr ?? e.message;
    } catch (e) {
      debugPrint('[Supabase] resend OTP failed: $e');
      return '메일 재발송에 실패했어요.';
    }
  }

  bool _isSupabaseSessionRestorable(User user) {
    if (user.emailConfirmedAt != null) return true;
    final provider = user.appMetadata['provider'] as String?;
    if (provider == 'google' || provider == 'kakao' || provider == 'apple') {
      return true;
    }
    for (final identity in user.identities ?? const []) {
      if (identity.provider == 'google' ||
          identity.provider == 'kakao' ||
          identity.provider == 'apple') {
        return true;
      }
    }
    return false;
  }

  void _bindAuthListener() {
    if (_authSub != null) return;
    _authSub = SupabaseService.client.auth.onAuthStateChange.listen((data) async {
      if (data.event == AuthChangeEvent.initialSession) return;
      if (data.event == AuthChangeEvent.signedIn && data.session != null) {
        final user = data.session!.user;
        if (!_isSupabaseSessionRestorable(user)) return;
        if (_isLoggedIn &&
            SupabaseService.client.auth.currentUser?.id == user.id) {
          return;
        }
        final prefs = await SharedPreferences.getInstance();
        if (prefs.getBool(_kAwaitingEmailConfirm) ?? false) {
          return;
        }
        await _onSupabaseSignedIn(user);
      }
    });
  }

  Future<void> _onSupabaseSignedIn(
    User user, {
    bool isNewSignup = false,
    bool updateStage = true,
    bool notify = true,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    if (!isNewSignup && (prefs.getBool(_kAwaitingEmailConfirm) ?? false)) {
      return;
    }

    final profile = await _profileRepo.fetch(user.id);

    final meta = user.userMetadata;
    final appMeta = user.appMetadata;
    // DB 프로필 닉네임 우선 — 본인 row이므로 taken 체크 불필요
    var nickname = profile?.nickname;
    final fromMeta = nickname == null;
    nickname ??= meta?['nickname'] as String?;
    if (isPlaceholderNickname(nickname)) {
      nickname = await generateAvailableNickname(_profileRepo.isNicknameTaken);
      await _syncMetadata({'nickname': nickname});
    } else if (fromMeta && nickname != null) {
      // meta에서 온 경우에만 중복 체크
      final taken = await _profileRepo.isNicknameTaken(nickname);
      if (taken == true) {
        nickname = await generateAvailableNickname(_profileRepo.isNicknameTaken);
        await _syncMetadata({'nickname': nickname});
      }
    }
    nickname ??= await generateAvailableNickname(_profileRepo.isNicknameTaken);

    await _profileRepo.upsertFromAuthUser(
      SupabaseService.client.auth.currentUser ?? user,
      nicknameOverride: nickname,
    );
    final metaRole = meta?['role'] as String?;
    final profileRole = profile?.role;
    final rawRole = profileRole ??
        appMeta['role'] as String? ??
        metaRole ??
        'user';
    final role = rawRole == 'admin' ? 'admin' : 'user';
    final restaurantIds = await _resolveOwnerRestaurantIds();

    final remoteBookmarks = meta?['bookmarks'];
    if (remoteBookmarks is List && remoteBookmarks.isNotEmpty) {
      await prefs.setString(_kBookmarks, jsonEncode(remoteBookmarks));
    }

    final authProvider =
        meta?['auth_provider'] as String? ??
        user.appMetadata['provider'] as String? ??
        'email';

    if (isNewSignup) {
      await _markReferralPromptPending(prefs, user.id);
    }

    var needsLegal = _needsLegalTermsConsent(
      prefs,
      user.id,
      isNewSignup: isNewSignup,
    );
    final serverConsent = await _legalConsentRepo.fetchHasRequiredConsents();
    if (serverConsent == true) {
      await _markLegalTermsAccepted(prefs, user.id);
      await _clearPendingLegalTerms(prefs, user.id);
      needsLegal = false;
    } else if (serverConsent == false) {
      await _markPendingLegalTerms(prefs, user.id);
      needsLegal = true;
    }

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
      supabaseUserId: user.id,
      needsLegalTerms: needsLegal,
      updateStage: updateStage,
      notify: notify,
    );
    await recordAppSession();
    await _syncPushNotifications();
    await fetchMyReward();
  }

  Future<void> _saveSession(
    SharedPreferences prefs,
    Account account, {
    String authProvider = 'email',
    String supabaseUserId = '',
    bool needsLegalTerms = false,
    bool updateStage = true,
    bool notify = true,
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

    _locationMode = prefs.getBool(_kLocation) ?? false;
    _notificationEnabled = prefs.getBool(_kPush) ?? false;
    _lunchPushEnabled = prefs.getBool(_kLunchPush) ?? _notificationEnabled;
    _dinnerPushEnabled = prefs.getBool(_kDinnerPush) ?? _notificationEnabled;
    _communityCommentsPushEnabled =
        prefs.getBool(_kCommunityCommentsPush) ?? _notificationEnabled;
    _rewardPushEnabled = prefs.getBool(_kRewardPush) ?? _notificationEnabled;
    _newsPushEnabled = prefs.getBool(_kNewsPush) ?? _notificationEnabled;

    final userId = supabaseUserId.isNotEmpty
        ? supabaseUserId
        : (_hasSupabaseSession
            ? SupabaseService.client.auth.currentUser!.id
            : account.id);
    if (needsLegalTerms) {
      await _markPendingLegalTerms(prefs, userId);
    }
    if (updateStage) {
      _stage = await _resolveStageForSession(
        prefs,
        userId: userId,
        needsLegalTerms: needsLegalTerms,
      );
    }
    if (account.restaurantIds.isNotEmpty) {
      _mainTabIndex = 0;
    }
    if (notify) notifyListeners();
    _flushPendingRemotePush();
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    final authProvider = prefs.getString(_kAuthProvider) ?? '';

    try {
      await FcmPushService.instance.unregisterToken();
    } catch (e, st) {
      debugPrint('[FCM] logout unregister failed: $e\n$st');
    }

    if (authProvider == 'kakao') {
      await KakaoAuthService.logoutKakao();
    } else if (authProvider == 'google') {
      await GoogleAuthService.signOut();
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
      // DB 탈퇴가 실패해도 계정을 그대로 쓸 수 있도록, 되돌릴 수 없는
      // 카카오/구글 연결 해제보다 DB 삭제(RPC)를 먼저 성공시킨다.
      await _profileRepo.deleteOwnAccount();
    } on PostgrestException catch (e) {
      debugPrint('[withdraw] RPC: ${e.message}');
      return '탈퇴 처리에 실패했어요. (${e.message})';
    } catch (e) {
      debugPrint('[withdraw] $e');
      return '탈퇴 처리에 실패했어요.';
    }

    try {
      if (authProvider == 'kakao') {
        await KakaoAuthService.unlinkKakao();
      } else if (authProvider == 'google') {
        await GoogleAuthService.disconnect();
      }
    } catch (e) {
      // DB 탈퇴는 이미 끝났으니 소셜 연결 해제 실패는 무시하고 계속 진행한다.
      debugPrint('[withdraw] social unlink failed (ignored): $e');
    }

    try {
      // RPC 마지막 단계에서 auth.users.banned_until을 세팅해 재로그인을
      // 막기 때문에, 서버 로그아웃(GoTrue) 요청은 이미 무효화된 세션으로
      // 거부되기 쉽다. 로컬 세션 정리만 하고(scope: local) 서버 왕복은
      // 건너뛰어, 이 호출이 실패해도 아래 로그인 화면 전환은 반드시 실행된다.
      await SupabaseService.client.auth
          .signOut(scope: SignOutScope.local);
    } catch (e) {
      debugPrint('[withdraw] signOut failed (ignored): $e');
    }
    await _clearSession(prefs);
    _stage = 'login';
    notifyListeners();
    return null;
  }

  /// OAuth SDK가 설정 오류를 cancel로 반환할 때 안내
  String _oauthCancelledMessage() {
    return '로그인이 취소되었어요.';
  }

  /// 카카오 로그인 (Supabase Auth + public.users)
  Future<String?> loginWithKakao() async {
    if (!KakaoAuthService.isConfigured) {
      return '카카오 로그인을 사용할 수 없어요. 잠시 후 다시 시도해주세요.';
    }
    if (!SupabaseService.isReady) {
      return '서버 연결에 실패했어요. 잠시 후 다시 시도해주세요.';
    }

    try {
      final result = await KakaoAuthService.signInWithSupabase();
      final user = result.user;
      await _onSupabaseSignedIn(
        user,
        isNewSignup: _isLikelyNewAccount(user),
      );
      return null;
    } on GoogleEmailBlocked catch (e) {
      return _oauthLoginBlockedMessage(e.status);
    } on AuthException catch (e) {
      debugPrint(
        '[Kakao] loginWithKakao AuthException: ${e.message} '
        'status=${e.statusCode} code=${e.code}',
      );
      if (e.message.contains('Unacceptable audience in id_token')) {
        return '카카오 로그인에 실패했어요. 잠시 후 다시 시도해주세요.';
      }
      if (_isKakaoIdTokenIssuerBlocked(e.message)) {
        return '카카오 로그인에 실패했어요. Supabase에서 Kakao issuer 허용이 필요해요.';
      }
      if (e.message.toLowerCase().contains('banned') ||
          e.message.toLowerCase().contains('suspended')) {
        return _withdrawnCooldownMessage;
      }
      return e.message;
    } catch (e) {
      debugPrint('[Kakao] loginWithKakao: $e');
      final msg = e.toString().toLowerCase();
      if (msg.contains('cancel') || msg.contains('canceled')) {
        return _oauthCancelledMessage();
      }
      if (msg.contains('koe101') ||
          msg.contains('invalid_client') ||
          msg.contains('invalidclient') ||
          msg.contains('misconfigured')) {
        return '카카오 로그인에 실패했어요. 잠시 후 다시 시도해주세요.';
      }
      if (_isKakaoIdTokenIssuerBlocked(msg)) {
        return '카카오 로그인에 실패했어요. Supabase에서 Kakao issuer 허용이 필요해요.';
      }
      return '로그인에 실패했어요. 잠시 후 다시 시도해주세요.';
    }
  }

  bool _isKakaoIdTokenIssuerBlocked(String message) {
    final msg = message.toLowerCase();
    return msg.contains('api request is blocked') ||
        msg.contains('issuer allow') ||
        (msg.contains('custom oidc provider') && msg.contains('not allowed'));
  }

  /// Google 로그인 (Supabase Auth + public.users)
  Future<String?> loginWithGoogle() async {
    if (!GoogleAuthService.isConfigured) {
      return '구글 로그인을 사용할 수 없어요. 잠시 후 다시 시도해주세요.';
    }
    if (!SupabaseService.isReady) {
      return '서버 연결에 실패했어요. 잠시 후 다시 시도해주세요.';
    }

    try {
      final result = await GoogleAuthService.signInWithSupabase();
      final user = result.user!;
      await _onSupabaseSignedIn(
        user,
        isNewSignup: _isLikelyNewAccount(user),
      );
      return null;
    } on GoogleSignInCancelled {
      return _oauthCancelledMessage();
    } on GoogleEmailBlocked catch (e) {
      return _oauthLoginBlockedMessage(e.status);
    } on AuthException catch (e) {
      final msg = e.message.toLowerCase();
      if (msg.contains('already') ||
          msg.contains('registered') ||
          msg.contains('exists')) {
        return '이 이메일은 이미 이메일 가입으로 등록되어 있어요.\n'
            '이메일·비밀번호로 로그인해주세요.';
      }
      if (msg.contains('nonce')) {
        return '구글 로그인 인증에 실패했어요.\n'
            '앱을 완전히 종료한 뒤 다시 시도해주세요.';
      }
      if (e.message.contains('Unacceptable audience in id_token') ||
          e.message.contains('audience')) {
        return '구글 로그인에 실패했어요. 잠시 후 다시 시도해주세요.';
      }
      if (msg.contains('banned') || msg.contains('suspended')) {
        return _withdrawnCooldownMessage;
      }
      return e.message;
    } catch (e) {
      debugPrint('[Google] loginWithGoogle: $e');
      if (e is GoogleSignInException) {
        if (e.code == GoogleSignInExceptionCode.canceled ||
            e.code == GoogleSignInExceptionCode.interrupted) {
          return _oauthCancelledMessage();
        }
      }
      final msg = e.toString().toLowerCase();
      if (msg.contains('cancel') || msg.contains('canceled')) {
        return _oauthCancelledMessage();
      }
      if (msg.contains('developer_error') || msg.contains('apiexception: 10')) {
        return '구글 로그인에 실패했어요. 잠시 후 다시 시도해주세요.';
      }
      return '로그인에 실패했어요. 잠시 후 다시 시도해주세요.';
    }
  }

  /// Apple 로그인 (iOS 네이티브 → Supabase Auth + public.users)
  Future<String?> loginWithApple() async {
    if (!SupabaseService.isReady) {
      return '서버 연결에 실패했어요. 잠시 후 다시 시도해주세요.';
    }
    if (!await AppleAuthService.isAvailable) {
      return '이 기기에서는 Apple 로그인을 사용할 수 없어요.';
    }

    try {
      final result = await AppleAuthService.signInWithSupabase();
      final user = result.user;
      await _onSupabaseSignedIn(
        user,
        isNewSignup: _isLikelyNewAccount(user),
      );
      return null;
    } on AppleSignInCancelled {
      return _oauthCancelledMessage();
    } on GoogleEmailBlocked catch (e) {
      return _oauthLoginBlockedMessage(e.status);
    } on AuthException catch (e) {
      final msg = e.message.toLowerCase();
      if (msg.contains('already') ||
          msg.contains('registered') ||
          msg.contains('exists')) {
        return '이 이메일은 이미 다른 방법으로 가입되어 있어요.\n'
            '기존 로그인 수단으로 로그인해주세요.';
      }
      if (msg.contains('nonce') || msg.contains('audience')) {
        return 'Apple 로그인 인증에 실패했어요.\n'
            '앱을 완전히 종료한 뒤 다시 시도해주세요.';
      }
      if (msg.contains('banned') || msg.contains('suspended')) {
        return _withdrawnCooldownMessage;
      }
      return e.message;
    } catch (e) {
      debugPrint('[Apple] loginWithApple: $e');
      final msg = e.toString().toLowerCase();
      if (msg.contains('cancel') || msg.contains('canceled')) {
        return _oauthCancelledMessage();
      }
      return '로그인에 실패했어요. 잠시 후 다시 시도해주세요.';
    }
  }

  Future<void> _clearSession(SharedPreferences prefs) async {
    await prefs.remove(_kLogin);
    await prefs.remove(_kNickname);
    await prefs.remove(_kSessionExp);
    await prefs.remove(_kAccountId);
    await prefs.remove(_kAuthProvider);
    await prefs.remove(_kUserRole);
    await prefs.remove(_kOwnerIds);
    _isLoggedIn = false;
    _nickname = '';
    _accountId = '';
    _userRole = 'user';
    _ownerRestaurantIds = [];
    _locationMode = false;
    _notificationEnabled = false;
    _mainTabIndex = 0;
    _rewardLoadFailed = false;
  }

  bool _ownsRestaurant(String restaurantId) =>
      _ownerRestaurantIds.contains(restaurantId);

  Future<List<String>> _resolveOwnerRestaurantIds({
    List<String> fallbackIds = const [],
  }) async {
    final repo = _restaurantRepo;
    if (repo != null) {
      return await repo.fetchOwnedRestaurantIds();
    }
    return fallbackIds;
  }

  Future<void> _syncOwnerRestaurantIdsFromDb([
    SharedPreferences? prefs,
  ]) async {
    final hadOwnerTab = hasOwnerTab;
    final p = prefs ?? await SharedPreferences.getInstance();
    _ownerRestaurantIds = await _resolveOwnerRestaurantIds();
    await p.setString(_kOwnerIds, jsonEncode(_ownerRestaurantIds));
    // 사장님↔일반 유저 전환 시 탭셋 자체가 바뀌므로 인덱스는 항상 0으로 리셋.
    if (hadOwnerTab != hasOwnerTab) {
      _mainTabIndex = 0;
    }
    // 매장이 1개뿐이면 선택 UI 없이 그 매장을 커뮤니티 활동 매장으로 서버에도 자동 반영.
    if (_ownerRestaurantIds.length == 1) {
      unawaited(setCommunityActiveOwnerRestaurant(_ownerRestaurantIds.first));
    } else {
      final saved = p.getString(_kActiveOwnerRestaurantId);
      if (saved != null &&
          saved.isNotEmpty &&
          _ownerRestaurantIds.contains(saved)) {
        _activeOwnerRestaurantId = saved;
      }
    }
  }

  Future<void> refreshOwnerState() async {
    await _syncOwnerRestaurantIdsFromDb();
    notifyListeners();
  }

  Future<void> refreshRestaurants() async {
    final repo = _restaurantRepo;
    if (repo == null) return;
    final gen = ++_restaurantRefreshGen;
    try {
      final fetched = await repo.fetchAll();
      if (gen != _restaurantRefreshGen) return;
      _restaurants = fetched;
      _restaurantsLoadFailed = false;
      notifyListeners();
      unawaited(_updateDistances());
    } catch (e, st) {
      debugPrint('[Supabase] refreshRestaurants failed: $e\n$st');
      _restaurantsLoadFailed = true;
      notifyListeners();
      return;
    }
    try {
      await _syncOwnerRestaurantIdsFromDb();
      await _syncPushNotifications();
      notifyListeners();
    } catch (e, st) {
      debugPrint('[Supabase] refreshRestaurants post-sync failed: $e\n$st');
    }
  }

  Future<void> _updateDistances() async {
    if (!_locationMode) return;
    try {
      Position? pos;
      try {
        pos = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, timeLimit: Duration(seconds: 5)),
        );
      } catch (_) {
        pos = await Geolocator.getLastKnownPosition();
      }
      if (pos == null) return;
      _restaurants = _restaurants.map((r) {
        if (!r.hasMapLocation) return r;
        final dist = Geolocator.distanceBetween(pos!.latitude, pos.longitude, r.latitude, r.longitude);
        return r.copyWith(distance: dist);
      }).toList();
      notifyListeners();
    } catch (e) {
      debugPrint('[Location] _updateDistances failed: $e');
    }
  }

  // ── 위치 권한 ──
  Future<bool> requestLocationOsPermission() async {
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      return permission == LocationPermission.always ||
          permission == LocationPermission.whileInUse;
    } catch (e) {
      debugPrint('[Permissions] location: $e');
      return false;
    }
  }

  Future<void> enableLocation() async {
    final granted = await requestLocationOsPermission();
    if (!granted) return;
    final prefs = await SharedPreferences.getInstance();
    _locationMode = true;
    await prefs.setBool(_kLocation, true);
    notifyListeners();
    unawaited(_updateDistances());
  }

  Future<void> setLocationMode(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    _locationMode = enabled;
    await prefs.setBool(_kLocation, enabled);
    if (_stage == 'location_permission') {
      _stage = prefs.containsKey(_kPush) ? await _postAppStage(prefs) : 'notification_permission';
    }
    notifyListeners();
    if (enabled) unawaited(_updateDistances());
  }

  Future<void> completeNotificationPermission(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    _notificationEnabled = enabled;
    _lunchPushEnabled = enabled;
    _dinnerPushEnabled = enabled;
    _communityCommentsPushEnabled = enabled;
    _rewardPushEnabled = enabled;
    _newsPushEnabled = enabled;
    await prefs.setBool(_kPush, enabled);
    await prefs.setBool(_kLunchPush, enabled);
    await prefs.setBool(_kDinnerPush, enabled);
    await prefs.setBool(_kCommunityCommentsPush, enabled);
    await prefs.setBool(_kRewardPush, enabled);
    await prefs.setBool(_kNewsPush, enabled);
    try {
      if (enabled) {
        await PushNotificationService.instance.requestPermission();
        await FcmPushService.instance.requestPermissionAndRegister();
      }
      await _syncPushNotifications();
    } catch (e, st) {
      debugPrint('[Push] completeNotificationPermission side-effect failed: $e\n$st');
    }
    _stage = await _postAppStage(prefs);
    notifyListeners();
  }

  // ── 알림 ──
  Future<void> setNotificationEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    _notificationEnabled = enabled;
    _lunchPushEnabled = enabled;
    _dinnerPushEnabled = enabled;
    _communityCommentsPushEnabled = enabled;
    _rewardPushEnabled = enabled;
    _newsPushEnabled = enabled;
    await prefs.setBool(_kPush, enabled);
    await prefs.setBool(_kLunchPush, enabled);
    await prefs.setBool(_kDinnerPush, enabled);
    await prefs.setBool(_kCommunityCommentsPush, enabled);
    await prefs.setBool(_kRewardPush, enabled);
    await prefs.setBool(_kNewsPush, enabled);
    if (enabled) {
      await PushNotificationService.instance.requestPermission();
      await FcmPushService.instance.requestPermissionAndRegister();
    }
    await _syncPushNotifications();
    notifyListeners();
  }

  Future<void> setLunchPush(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    _lunchPushEnabled = enabled;
    _notificationEnabled = _lunchPushEnabled ||
        _dinnerPushEnabled ||
        _communityCommentsPushEnabled ||
        _rewardPushEnabled ||
        _newsPushEnabled;
    await prefs.setBool(_kLunchPush, enabled);
    await prefs.setBool(_kPush, _notificationEnabled);
    if (enabled) {
      await PushNotificationService.instance.requestPermission();
      await FcmPushService.instance.requestPermissionAndRegister();
    }
    await _syncPushNotifications();
    notifyListeners();
  }

  Future<void> setDinnerPush(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    _dinnerPushEnabled = enabled;
    _notificationEnabled = _lunchPushEnabled ||
        _dinnerPushEnabled ||
        _communityCommentsPushEnabled ||
        _rewardPushEnabled ||
        _newsPushEnabled;
    await prefs.setBool(_kDinnerPush, enabled);
    await prefs.setBool(_kPush, _notificationEnabled);
    if (enabled) {
      await PushNotificationService.instance.requestPermission();
      await FcmPushService.instance.requestPermissionAndRegister();
    }
    await _syncPushNotifications();
    notifyListeners();
  }

  Future<void> setCommunityCommentsPush(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    _communityCommentsPushEnabled = enabled;
    _notificationEnabled = _lunchPushEnabled ||
        _dinnerPushEnabled ||
        _communityCommentsPushEnabled ||
        _rewardPushEnabled ||
        _newsPushEnabled;
    await prefs.setBool(_kCommunityCommentsPush, enabled);
    await prefs.setBool(_kPush, _notificationEnabled);
    if (enabled) {
      await PushNotificationService.instance.requestPermission();
      await FcmPushService.instance.requestPermissionAndRegister();
    }
    await _syncPushNotifications();
    notifyListeners();
  }

  Future<void> setRewardPush(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    _rewardPushEnabled = enabled;
    _notificationEnabled = _lunchPushEnabled ||
        _dinnerPushEnabled ||
        _communityCommentsPushEnabled ||
        _rewardPushEnabled ||
        _newsPushEnabled;
    await prefs.setBool(_kRewardPush, enabled);
    await prefs.setBool(_kPush, _notificationEnabled);
    if (enabled) {
      await PushNotificationService.instance.requestPermission();
      await FcmPushService.instance.requestPermissionAndRegister();
    }
    await _syncPushNotifications();
    notifyListeners();
  }

  Future<void> setNewsPush(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    _newsPushEnabled = enabled;
    _notificationEnabled = _lunchPushEnabled ||
        _dinnerPushEnabled ||
        _communityCommentsPushEnabled ||
        _rewardPushEnabled ||
        _newsPushEnabled;
    await prefs.setBool(_kNewsPush, enabled);
    await prefs.setBool(_kPush, _notificationEnabled);
    if (enabled) {
      await PushNotificationService.instance.requestPermission();
      await FcmPushService.instance.requestPermissionAndRegister();
    }
    await _syncPushNotifications();
    notifyListeners();
  }

  void setMainTabIndex(int index) {
    final max = 3;
    final next = index.clamp(0, max);
    if (_mainTabIndex == next) return;
    _flushTabDwell(_mainTabIndex);
    _mainTabIndex = next;
    _tabEnteredAt = DateTime.now();
    notifyListeners();
    unawaited(_refreshForMainTab(next));
  }

  String _screenNameForTab(int index) {
    if (hasOwnerTab) {
      return switch (index) {
        0 => 'owner_report',
        1 => 'owner_store',
        2 => 'community',
        3 => 'my',
        _ => 'unknown',
      };
    }
    return switch (index) {
      0 => 'home',
      1 => 'map',
      2 => 'community',
      3 => 'my',
      _ => 'unknown',
    };
  }

  void _flushTabDwell(int tabIndex) {
    final ms = DateTime.now().difference(_tabEnteredAt).inMilliseconds;
    if (ms < 2000) return;
    unawaited(
      _analyticsRepo.recordScreenDwell(
        screen: _screenNameForTab(tabIndex),
        dwellMs: ms,
        appSessionId: getAppSessionId(),
      ),
    );
  }

  void openHomeFromPush([String? restaurantId]) {
    debugPrint('[AppProvider] openHomeFromPush restaurantId=$restaurantId');
    _mainTabIndex = homeTabIndex;
    notifyListeners();
    unawaited(_refreshForMainTab(homeTabIndex));
    if (restaurantId != null && restaurantId.isNotEmpty) {
      _pendingAppLink = AppLinkTarget.bookmarks;
      notifyListeners();
    }
  }

  void openCouponsFromPush() {
    debugPrint('[AppProvider] openCouponsFromPush');
    _mainTabIndex = homeTabIndex;
    _pendingAppLink = AppLinkTarget.coupons;
    notifyListeners();
  }

  void openCommunityFromPush([String? postId]) {
    debugPrint('[AppProvider] openCommunityFromPush postId=$postId');
    _mainTabIndex = communityTabIndex;
    if (postId != null && postId.isNotEmpty) {
      _pendingCommunityPostId = postId;
    }
    notifyListeners();
  }

  void openCollectionFromPush(String? collectionId) {
    debugPrint('[AppProvider] openCollectionFromPush collectionId=$collectionId');
    _mainTabIndex = communityTabIndex;
    if (collectionId != null && collectionId.isNotEmpty) {
      _pendingCollectionId = collectionId;
    }
    notifyListeners();
  }

  /// 사장님 인증 반려 푸시 탭 → 마이 탭으로 이동, 반려 사유가 뜨는
  /// 사장님 인증 화면으로 랜딩 (OwnerVerifyScreen이 자체적으로 상태 재조회).
  void openOwnerRejectionFromPush() {
    debugPrint('[AppProvider] openOwnerRejectionFromPush');
    _mainTabIndex = myTabIndex;
    _pendingOwnerRejectionPush = true;
    notifyListeners();
  }

  /// 사장님 인증 승인 푸시 탭 → 소유 매장 목록을 먼저 갱신해 사장님 탭셋으로
  /// 전환한 뒤 제보 홈(0번 탭)으로 랜딩한다. 갱신 전에 openHomeFromPush를 쓰면
  /// hasOwnerTab이 아직 false라 일반 유저 홈으로 잘못 랜딩된다.
  Future<void> openOwnerApprovalFromPush() async {
    debugPrint('[AppProvider] openOwnerApprovalFromPush');
    await _syncOwnerRestaurantIdsFromDb();
    await refreshRestaurants();
    _mainTabIndex = homeTabIndex;
    notifyListeners();
  }

  void handleRemotePushData(Map<String, dynamic> data) {
    if (_bootstrapping || _stage != 'app' || !_isLoggedIn) {
      _pendingRemotePushData = data;
      return;
    }
    _routeRemotePushData(data);
  }

  void _flushPendingRemotePush() {
    final data = _pendingRemotePushData;
    if (data == null) return;
    if (_bootstrapping || _stage != 'app' || !_isLoggedIn) return;
    _pendingRemotePushData = null;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _routeRemotePushData(data);
    });
  }

  void _routeRemotePushData(Map<String, dynamic> data) {
    final type = data['type'] as String?;
    if (type == 'config_refresh') {
      unawaited(refreshPushSchedulesFromRemote());
      return;
    }
    if (type == 'community_comment' ||
        type == 'community_like' ||
        type == 'community_moderation') {
      openCommunityFromPush(data['post_id'] as String?);
      return;
    }
    if (type == 'collection_reply') {
      openCollectionFromPush(data['collection_id'] as String?);
      return;
    }
    if (type == 'owner_approved') {
      unawaited(openOwnerApprovalFromPush());
      return;
    }
    if (type == 'owner_rejected') {
      openOwnerRejectionFromPush();
      return;
    }
    if (type == 'reward_gifticon') {
      openCouponsFromPush();
      return;
    }
    openHomeFromPush(data['restaurant_id'] as String?);
  }

  /// 어드민이 설정을 바꿨을 때 data-only FCM → 로컬 스케줄 재동기화
  Future<void> refreshPushSchedulesFromRemote() async {
    await _syncPushNotifications();
  }

  /// 하단 탭 전환 시 웹처럼 해당 화면 데이터를 서버에서 다시 불러온다.
  Future<void> _refreshForMainTab(int index) async {
    try {
      if (hasOwnerTab) {
        await refreshRestaurants();
        await refreshOwnerState();
        return;
      }
      if (index == myTabIndex) {
        await fetchMyReward();
        return;
      }
      await refreshRestaurants();
    } catch (e, st) {
      debugPrint('[AppProvider] _refreshForMainTab failed: $e\n$st');
    }
  }

  /// FCM 토큰·선호 동기화 + (옵션) 로컬 피크 예약
  Future<void> _syncPushNotifications() async {
    if (kIsWeb) return;
    try {
      final lunchOn = _notificationEnabled && _lunchPushEnabled;
      final dinnerOn = _notificationEnabled && _dinnerPushEnabled;
      final communityOn =
          _notificationEnabled && _communityCommentsPushEnabled;
      final rewardOn = _notificationEnabled && _rewardPushEnabled;
      final newsOn = _notificationEnabled && _newsPushEnabled;

      final pushConfig = await _pushConfigRepo.fetchConfig();

      if (!_hasSupabaseSession) {
        await PushNotificationService.instance.cancelAllSchedules();
        return;
      }

      await FcmPushService.instance.syncPrefs(
        peakLunch: lunchOn,
        peakDinner: dinnerOn,
        communityComments: communityOn,
        rewardGifticon: rewardOn,
        news: newsOn,
      );

      if (lunchOn || dinnerOn || communityOn || rewardOn || newsOn) {
        await FcmPushService.instance.registerToken();
      }

      if (pushConfig.peakLocalScheduleEnabled) {
        // 맛집컬렉션 전용 매장(crowdEnabled=false)은 혼잡도 개념이 없으므로
        // "지금 여유로워요" 류의 로컬 피크 푸시 추천 대상에서 제외한다.
        final crowdEnabledRestaurants =
            _restaurants.where((r) => r.crowdEnabled).toList();
        await PushNotificationService.instance.syncDeliveredAnalytics(
          lunchEnabled: lunchOn,
          dinnerEnabled: dinnerOn,
          restaurantId: pickRecommendedRestaurant(
                  crowdEnabledRestaurants, _useAlgorithmRanking)
              ?.id,
          config: pushConfig,
        );
        await PushNotificationService.instance.refreshSchedules(
          lunchEnabled: lunchOn,
          dinnerEnabled: dinnerOn,
          restaurants: crowdEnabledRestaurants,
          useAlgorithmRanking: _useAlgorithmRanking,
          config: pushConfig,
        );
      } else {
        await PushNotificationService.instance.cancelAllSchedules();
      }
    } catch (e, st) {
      debugPrint('[Push] _syncPushNotifications failed: $e\n$st');
    }
  }

  // ── 혼잡도 제보 ──
  /// 마지막 제보로 지급된 스탬프 결과 (report_feedback.dart에서 읽음)
  StampResult _lastStampResult = StampResult.none;
  StampResult get lastStampResult => _lastStampResult;

  /// 성공 시 null, 실패 시 사용자에게 보여줄 메시지
  Future<String?> reportStatus(String restaurantId, String status) async {
    final repo = _restaurantRepo;
    final authUser = SupabaseService.client.auth.currentUser;

    if (repo != null && authUser != null) {
      final deviceId = await getOrCreateDeviceInstallId();
      final sessionId = getAppSessionId();
      String source = 'user';
      double? attemptLat;
      double? attemptLng;
      try {
        final isOwnerReport = _ownsRestaurant(restaurantId);
        source = isOwnerReport ? 'owner' : 'user';
        final isStatsExcluded =
            StatsExcludedAccount.isEmail(authUser.email);

        // 사장님은 5분 제한 없음. 디버그 빌드(flutter run)는 테스트 위해 제한 우회.
        // 통계 제외 계정(is_stats_excluded)도 서버와 동일하게 전부 면제.
        if (source == 'user' && !kDebugMode && !isStatsExcluded) {
          final last = _lastReportTime[restaurantId];
          if (last != null &&
              DateTime.now().difference(last).inMinutes < 5) {
            final msg = '방금 제보한 매장이에요.\n잠시 후 다시 제보해주세요.';
            unawaited(_analyticsRepo.recordReportAttempt(
              restaurantId: restaurantId,
              success: false,
              failReason: 'client_cooldown',
              deviceInstallId: deviceId,
              appSessionId: sessionId,
              source: source,
              status: status,
            ));
            return msg;
          }
        }

        double? gpsLat;
        double? gpsLng;
        if (isStatsExcluded) {
          // GPS(위치) 확인·거리 제한 없이 매장 좌표를 그대로 사용해 제보를 넘긴다.
          final pos = await _currentPosition();
          gpsLat = pos?.latitude;
          gpsLng = pos?.longitude;
        } else {
          // 위치 제한은 사장님 제보에도 동일. 5분 쿨다운만 사장님 예외.
          // 디버그(flutter run)는 50m 우회 — _resolveVenueGps 참고.
          final (coords, gpsErr) = await _resolveVenueGps(
            restaurantId,
            tooFarMessage: '매장 근처에서만 혼잡도를 제보할 수 있어요.',
          );
          if (gpsErr != null) {
            unawaited(_analyticsRepo.recordReportAttempt(
              restaurantId: restaurantId,
              success: false,
              failReason: gpsErr,
              deviceInstallId: deviceId,
              appSessionId: sessionId,
              source: source,
              status: status,
            ));
            return gpsErr;
          }
          gpsLat = coords!.lat;
          gpsLng = coords.lng;
        }
        attemptLat = gpsLat;
        attemptLng = gpsLng;

        final stampResult = await repo.reportStatusWithStamp(
          restaurantId,
          status,
          source: source,
          userId: authUser.id,
          nickname: _nickname,
          latitude: gpsLat,
          longitude: gpsLng,
          deviceInstallId: deviceId,
          appSessionId: sessionId,
        );
        if (source == 'user') {
          _lastReportTime[restaurantId] = DateTime.now();
          _lastStampResult = stampResult;
        } else {
          _lastStampResult = StampResult.none;
        }

        unawaited(_analyticsRepo.recordReportAttempt(
          restaurantId: restaurantId,
          success: true,
          deviceInstallId: deviceId,
          appSessionId: sessionId,
          latitude: attemptLat,
          longitude: attemptLng,
          source: source,
          status: status,
        ));

        // 제보(RPC)는 이미 커밋됨 — 이후 부수 작업이 실패해도 "제보 실패"로 보이면 안 됨
        try {
          if (source == 'user') await fetchMyReward();
          final gen = ++_restaurantRefreshGen;
          final fetched = await repo.fetchAll();
          if (gen == _restaurantRefreshGen) {
            _restaurants = fetched;
          }
          final prefs = await SharedPreferences.getInstance();
          await prefs.remove(_kOverrides);
          await _syncPushNotifications();
        } catch (e, st) {
          debugPrint('[Supabase] reportStatus post-processing failed: $e\n$st');
        }
        notifyListeners();
        return null;
      } on PostgrestException catch (e) {
        debugPrint('[Supabase] reportStatus failed: ${e.message}');
        final msg = e.message.trim().isNotEmpty
            ? e.message.trim()
            : '제보에 실패했어요. 잠시 후 다시 시도해주세요.';
        unawaited(_analyticsRepo.recordReportAttempt(
          restaurantId: restaurantId,
          success: false,
          failReason: msg,
          deviceInstallId: deviceId,
          appSessionId: sessionId,
          latitude: attemptLat,
          longitude: attemptLng,
          source: source,
          status: status,
        ));
        return msg;
      } catch (e, st) {
        debugPrint('[Supabase] reportStatus failed: $e\n$st');
        unawaited(_analyticsRepo.recordReportAttempt(
          restaurantId: restaurantId,
          success: false,
          failReason: e.toString(),
          deviceInstallId: deviceId,
          appSessionId: sessionId,
          latitude: attemptLat,
          longitude: attemptLng,
          source: source,
          status: status,
        ));
        return '제보에 실패했어요. 잠시 후 다시 시도해주세요.';
      }
    }

    // repo는 있는데 authUser만 없는 경우 — 세션이 만료/무효화된 상태.
    // 서버에 반영되지 않으므로 로컬 오버라이드로 조용히 "성공" 처리하면 안 된다
    // (제보는 성공한 것처럼 보이지만 최근 제보·홈 화면엔 끝내 반영되지 않는 유령 상태가 됨).
    if (repo != null) {
      return '로그인이 만료됐어요.\n다시 로그인해주세요.';
    }

    if (!kDebugMode) {
      return '서버에 연결할 수 없어요. 잠시 후 다시 시도해주세요.';
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
    return null;
  }

  Future<Position?> _currentPosition() async {
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return null;
      }
      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 5),
        ),
      );
    } catch (_) {
      return null;
    }
  }

  /// 제보·입장가능인원용 GPS.
  ///
  /// - **디버그(`flutter run`)**: 50m 제한 없음. 서버도 50m를 검사하므로
  ///   실제 GPS 대신 매장 좌표를 보내 거리=0m로 통과시킨다.
  /// - **릴리즈/프로파일/IPA**: 실제 GPS + 클라이언트·서버 50m 검증.
  ///
  /// 실패 시 `(null, 사용자 메시지)`, 성공 시 `((lat,lng), null)`.
  Future<(({double lat, double lng})? coords, String? error)> _resolveVenueGps(
    String restaurantId, {
    required String tooFarMessage,
  }) async {
    Restaurant? restaurant;
    for (final r in _restaurants) {
      if (r.id == restaurantId) {
        restaurant = r;
        break;
      }
    }
    if (restaurant == null) {
      return (null, '매장 정보를 찾을 수 없어요.');
    }
    if (!restaurant.hasMapLocation) {
      return (null, '식당 위치 정보가 없어요.');
    }

    // assert/kDebugMode: flutter run(debug)에서만 true. release·profile·IPA는 false.
    if (kDebugMode) {
      debugPrint(
        '[GPS] debug bypass 50m — using restaurant coords '
        'id=$restaurantId lat=${restaurant.latitude} lng=${restaurant.longitude}',
      );
      return (
        (lat: restaurant.latitude, lng: restaurant.longitude),
        null,
      );
    }

    final pos = await _currentPosition();
    if (pos == null) {
      return (null, '현재 위치를 확인할 수 없어요.\n위치 권한을 확인해주세요.');
    }
    final dist = Geolocator.distanceBetween(
      pos.latitude,
      pos.longitude,
      restaurant.latitude,
      restaurant.longitude,
    );
    if (dist > 50) {
      return (null, tooFarMessage);
    }
    return ((lat: pos.latitude, lng: pos.longitude), null);
  }

  Future<void> loadOwnerInfluence() async {
    final repo = _restaurantRepo;
    if (repo == null) return;
    try {
      _ownerInfluence = await repo.fetchOwnerInfluence();
      notifyListeners();
    } catch (e) {
      debugPrint('[Supabase] loadOwnerInfluence failed: $e');
    }
  }

  Future<String?> setOwnerInfluence(int value) async {
    if (!_canAdminOps) return '관리자만 변경할 수 있어요.';
    final repo = _restaurantRepo;
    if (repo == null) return 'Supabase 연결이 필요해요.';
    try {
      final clamped = value.clamp(0, 100);
      await repo.setOwnerInfluence(clamped);
      _ownerInfluence = clamped;
      _restaurants = _withOperatingHours(await repo.fetchAll());
      notifyListeners();
      return null;
    } on PostgrestException catch (e) {
      return e.message.trim().isNotEmpty
          ? e.message.trim()
          : '설정 저장에 실패했어요.';
    } catch (e, st) {
      debugPrint('[Supabase] setOwnerInfluence failed: $e\n$st');
      return '설정 저장에 실패했어요.';
    }
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

  // ── 권한 동의 (첫 앱 실행) · 약관 동의 (회원가입 직후) ──
  bool _hasPermissionsConsent(SharedPreferences prefs) =>
      prefs.getBool(_kPermissionsConsentSeen) ?? false;

  bool _hasLegalTermsConsent(SharedPreferences prefs, String userId) {
    if (userId.isEmpty) return false;
    final accepted = prefs.getStringList(_kLegalTermsAcceptedUsers) ?? [];
    return accepted.contains(userId);
  }

  Future<void> _markLegalTermsAccepted(
    SharedPreferences prefs,
    String userId,
  ) async {
    if (userId.isEmpty) return;
    final accepted = List<String>.from(
      prefs.getStringList(_kLegalTermsAcceptedUsers) ?? const [],
    );
    if (!accepted.contains(userId)) {
      accepted.add(userId);
      await prefs.setStringList(_kLegalTermsAcceptedUsers, accepted);
    }
  }

  bool _isPendingLegalTerms(SharedPreferences prefs, String userId) {
    if (userId.isEmpty) return false;
    final pending = prefs.getStringList(_kPendingLegalTermsUsers) ?? [];
    return pending.contains(userId);
  }

  Future<void> _markPendingLegalTerms(
    SharedPreferences prefs,
    String userId,
  ) async {
    if (userId.isEmpty) return;
    final pending = List<String>.from(
      prefs.getStringList(_kPendingLegalTermsUsers) ?? const [],
    );
    if (!pending.contains(userId)) {
      pending.add(userId);
      await prefs.setStringList(_kPendingLegalTermsUsers, pending);
    }
  }

  Future<void> _clearPendingLegalTerms(
    SharedPreferences prefs,
    String userId,
  ) async {
    if (userId.isEmpty) return;
    final pending = List<String>.from(
      prefs.getStringList(_kPendingLegalTermsUsers) ?? const [],
    );
    if (pending.remove(userId)) {
      await prefs.setStringList(_kPendingLegalTermsUsers, pending);
    }
  }

  bool isReferralPromptPending(SharedPreferences prefs, String userId) {
    if (userId.isEmpty) return false;
    final pending = prefs.getStringList(_kReferralPromptPendingUsers) ?? [];
    return pending.contains(userId);
  }

  bool _isReferralPromptDone(SharedPreferences prefs, String userId) {
    if (userId.isEmpty) return false;
    final done = prefs.getStringList(_kReferralPromptDoneUsers) ?? [];
    return done.contains(userId);
  }

  Future<void> _markReferralPromptDone(
    SharedPreferences prefs,
    String userId,
  ) async {
    if (userId.isEmpty) return;
    final done = List<String>.from(
      prefs.getStringList(_kReferralPromptDoneUsers) ?? const [],
    );
    if (!done.contains(userId)) {
      done.add(userId);
      await prefs.setStringList(_kReferralPromptDoneUsers, done);
    }
  }

  Future<void> _markReferralPromptPending(
    SharedPreferences prefs,
    String userId,
  ) async {
    if (userId.isEmpty) return;
    // 건너뛰기/등록완료로 이미 한 번 처리한 유저는 다시 대기중으로 되돌리지 않는다.
    // (재로그인 시점에도 isNewSignup이 여전히 true일 수 있어서, 이 플래그가
    // 없으면 로그아웃 후 재로그인할 때마다 프롬프트가 다시 뜬다.)
    if (_isReferralPromptDone(prefs, userId)) return;
    final pending = List<String>.from(
      prefs.getStringList(_kReferralPromptPendingUsers) ?? const [],
    );
    if (!pending.contains(userId)) {
      pending.add(userId);
      await prefs.setStringList(_kReferralPromptPendingUsers, pending);
    }
  }

  Future<void> _clearReferralPromptPending(
    SharedPreferences prefs,
    String userId,
  ) async {
    if (userId.isEmpty) return;
    final pending = List<String>.from(
      prefs.getStringList(_kReferralPromptPendingUsers) ?? const [],
    );
    if (pending.remove(userId)) {
      await prefs.setStringList(_kReferralPromptPendingUsers, pending);
    }
  }

  /// 이 계정 첫 성공 제보에서 네이티브 리뷰 시트를 아직 요청하지 않았는지.
  /// StoreKit「안 함」은 감지 불가 → 영구 종료 없음. 같은 계정 재제보에는 안 뜨고,
  /// 기프티콘 수령·다른 계정 첫 제보 때 다시 요청한다.
  bool shouldPromptStoreReviewForFirstReport() {
    if (_accountId.isEmpty) return false;
    return !_storeReviewFirstReportAccounts.contains(_accountId);
  }

  Future<void> markStoreReviewFirstReportPrompted() async {
    if (_accountId.isEmpty) return;
    if (!_storeReviewFirstReportAccounts.add(_accountId)) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _kStoreReviewFirstReportAccounts,
      _storeReviewFirstReportAccounts.toList(),
    );
  }

  bool _isLikelyNewAccount(User user) {
    final created = DateTime.tryParse(user.createdAt);
    if (created == null) return false;
    return DateTime.now().difference(created).inMinutes < 15;
  }

  bool _needsLegalTermsConsent(
    SharedPreferences prefs,
    String userId, {
    required bool isNewSignup,
  }) {
    if (userId.isEmpty || _hasLegalTermsConsent(prefs, userId)) return false;
    if (isNewSignup) return true;
    return _isPendingLegalTerms(prefs, userId);
  }

  String _sessionUserId(SharedPreferences prefs) {
    if (_hasSupabaseSession) {
      return SupabaseService.client.auth.currentUser!.id;
    }
    return prefs.getString(_kAccountId) ?? '';
  }

  Future<String> _resolveStageAfterSplash(SharedPreferences prefs) async {
    // permissions 동의 전이면 시작하기 화면으로 (onboarding 화면 생략)
    if (!_hasPermissionsConsent(prefs)) return 'permissions_consent';
    if (_isLoggedIn) {
      final userId = _sessionUserId(prefs);
      final serverConsent = await _legalConsentRepo.fetchHasRequiredConsents();
      if (serverConsent == true) {
        await _markLegalTermsAccepted(prefs, userId);
        await _clearPendingLegalTerms(prefs, userId);
        return 'app';
      }
      if (serverConsent == false ||
          _needsLegalTermsConsent(
            prefs,
            userId,
            isNewSignup: false,
          )) {
        return 'legal_terms_consent';
      }
      return 'app';
    }
    return 'login';
  }

  Future<String> _resolveStageForSession(
    SharedPreferences prefs, {
    required String userId,
    required bool needsLegalTerms,
  }) async {
    debugPrint('[Stage] _resolveStageForSession userId=$userId needsLegalTerms=$needsLegalTerms '
        'hasPermissionsConsent=${_hasPermissionsConsent(prefs)} '
        'hasLegalTermsConsent=${_hasLegalTermsConsent(prefs, userId)} '
        'isPendingLegalTerms=${_isPendingLegalTerms(prefs, userId)}');
    if (!_hasPermissionsConsent(prefs)) return 'permissions_consent';
    if (needsLegalTerms &&
        userId.isNotEmpty &&
        _needsLegalTermsConsent(
          prefs,
          userId,
          isNewSignup: true,
        )) {
      return 'legal_terms_consent';
    }
    if (userId.isNotEmpty &&
        _needsLegalTermsConsent(prefs, userId, isNewSignup: false)) {
      return 'legal_terms_consent';
    }
    return await _postAppStage(prefs);
  }

  /// OS 권한 요청(확인 버튼 시점만). 위치는 선택 동의이며, 체크했을 때만 요청한다
  /// (동의하지 않은 사람에게 OS 위치 팝업을 띄우지 않기 위함 — 위치정보법).
  /// 거부/미동의 상태로도 앱 진입은 허용하고, 지도·길찾기·제보 등 위치가
  /// 필요한 기능에서 그때그때 다시 요청한다.
  /// 순서: 위치(동의 시만) → 주변 기기(Android만, 위치 동의 시만) → 알림
  ///
  /// iOS 「로컬 네트워크」팝업은 Flutter `flutter run` 디버그 연결이
  /// 앱 시작 시 띄우며, 이 메서드와 무관하다.
  Future<void> completePermissionsConsent({
    required bool requestLocation,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    debugPrint('[Permissions] confirm tapped — requesting OS permissions');

    var locationGranted = false;
    var pushGranted = false;
    try {
      if (requestLocation) {
        try {
          locationGranted = await requestLocationOsPermission()
              .timeout(const Duration(seconds: 30), onTimeout: () => false);
          debugPrint('[Permissions] location granted=$locationGranted');
          await DevicePermissionService.requestAndroidNearbyScanForLocation()
              .timeout(const Duration(seconds: 30), onTimeout: () {});
        } catch (e, st) {
          debugPrint('[Permissions] location: $e\n$st');
        }
      }

      try {
        pushGranted = await PushNotificationService.instance
            .requestPermission()
            .timeout(const Duration(seconds: 30), onTimeout: () => false);
        if (pushGranted) {
          await FcmPushService.instance.requestPermissionAndRegister();
        }
        debugPrint('[Permissions] notification granted=$pushGranted');
      } catch (e, st) {
        debugPrint('[Permissions] push: $e\n$st');
      }
    } finally {
      _locationMode = locationGranted;
      _notificationEnabled = pushGranted;
      _lunchPushEnabled = pushGranted;
      _dinnerPushEnabled = pushGranted;
      _communityCommentsPushEnabled = pushGranted;
      _rewardPushEnabled = pushGranted;
      _newsPushEnabled = pushGranted;

      await prefs.setBool(_kPermissionsConsentSeen, true);
      await prefs.setBool(_kLocation, locationGranted);
      await prefs.setBool(_kPush, pushGranted);
      await prefs.setBool(_kLunchPush, pushGranted);
      await prefs.setBool(_kDinnerPush, pushGranted);
      await prefs.setBool(_kCommunityCommentsPush, pushGranted);
      await prefs.setBool(_kRewardPush, pushGranted);
      await prefs.setBool(_kNewsPush, pushGranted);

      if (_hasSupabaseSession && pushGranted) {
        unawaited(_syncPushNotifications());
      }

      // 네이티브 SDK(카카오맵 등) 초기화는 화면 전환을 막지 않도록 백그라운드로 실행
      unawaited(triggerDeferredStartup());

      _stage = await _resolveStageAfterSplash(prefs);
      notifyListeners();
    }
  }

  Future<void> completeLegalTermsConsent([Map<String, bool>? agreed]) async {
    final prefs = await SharedPreferences.getInstance();
    final userId = _sessionUserId(prefs);
    if (userId.isEmpty) {
      _stage = 'login';
      notifyListeners();
      return;
    }

    await _markLegalTermsAccepted(prefs, userId);
    await _clearPendingLegalTerms(prefs, userId);

    if (agreed != null) {
      for (final item in LegalTerms.checkItems) {
        await _legalConsentRepo.recordConsent(
          termId: item.id,
          termLabel: item.label,
          agreed: agreed[item.id] ?? false,
        );
      }
    }

    _stage = await _postAppStage(prefs);
    if (hasOwnerTab) _mainTabIndex = 0;
    notifyListeners();
  }

  /// 마이페이지 설정에서 "개인정보 활용 및 마케팅 정보 수신" 토글 초기값 조회.
  Future<bool> fetchMarketingConsent() {
    return _legalConsentRepo.fetchMarketingConsent();
  }

  /// 마이페이지 설정에서 마케팅 동의 토글 변경 시 호출. 동의 이력에 새 레코드로 남는다.
  Future<void> setMarketingConsent(bool agreed) {
    return _legalConsentRepo.recordConsent(
      termId: 'marketing_consent',
      termLabel: '개인정보 활용 및 마케팅 정보 수신',
      agreed: agreed,
    );
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

  /// 실제 Supabase 세션이 있는지 (로컬 편의 계정 제외)
  bool get hasSupabaseSession => _hasSupabaseSession;

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
    if (containsForbiddenNicknameWord(trimmed)) {
      return '사용할 수 없는 닉네임이에요.';
    }
    if (trimmed == _nickname.trim()) return null;

    if (_hasSupabaseSession) {
      final available = await _profileRepo.isNicknameAvailable(trimmed);
      if (available == false) {
        return '이미 사용 중인 닉네임이에요.';
      }
      if (available == null) {
        final taken = await _profileRepo.isNicknameTaken(trimmed);
        if (taken == true) return '이미 사용 중인 닉네임이에요.';
        if (taken == null) {
          return '닉네임 확인에 실패했어요. 잠시 후 다시 시도해주세요.';
        }
      }
    }

    final prefs = await SharedPreferences.getInstance();

    if (_hasSupabaseSession) {
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
          if (e.message.contains('30일')) {
            return e.message;
          }
          debugPrint('[Profile] updateNickname: ${e.message}');
          return '닉네임 저장에 실패했어요.';
        }
      }
      // DB 반영(위의 30일 제한 검사)이 성공한 뒤에만 auth 메타데이터를 맞춘다 —
      // 순서가 바뀌면 제한에 걸려도 메타데이터만 새 닉네임으로 남아 다음 로그인 시
      // upsert가 DB와 메타데이터 간 불일치로 트리거를 다시 건드릴 수 있다.
      await _syncMetadata({'nickname': trimmed});
    }

    _nickname = trimmed;
    await prefs.setString(_kNickname, trimmed);
    notifyListeners();
    return null;
  }

  Future<List<RecentCrowdReport>> fetchRecentCrowdReports(String restaurantId) async {
    final repo = _restaurantRepo;
    if (repo == null) return [];
    try {
      return await repo.fetchRecentReports(restaurantId);
    } catch (e, st) {
      debugPrint('[Supabase] fetchRecentCrowdReports failed: $e\n$st');
      return [];
    }
  }

  /// 사장님 통계용: 본인 매장의 누적 즐겨찾기 수
  Future<int> fetchOwnerRestaurantBookmarkCount(String restaurantId) async {
    final repo = _restaurantRepo;
    if (repo == null) return 0;
    return repo.fetchOwnerRestaurantBookmarkCount(restaurantId);
  }

  /// 사장님 통계용: 본인 매장의 오늘/누적 지도 클릭 수 + 오늘 제보수
  Future<Map<String, int>> fetchOwnerRestaurantEngagementStats(
      String restaurantId) async {
    final repo = _restaurantRepo;
    if (repo == null) {
      return {
        'todayMapClicks': 0,
        'totalMapClicks': 0,
        'todayReports': 0,
        'totalSearchClicks': 0,
        'todayDetailViews': 0,
        'totalDetailViews': 0,
      };
    }
    return repo.fetchOwnerRestaurantEngagementStats(restaurantId);
  }

  /// 지도에서 매장 마커를 탭했을 때 기록 (사장님 통계의 "지도 클릭 수" 집계용)
  Future<void> recordMapMarkerClick(String restaurantId) async {
    await _analyticsRepo.recordMapMarkerClick(restaurantId);
  }

  /// 홈/지도 검색 결과에서 매장을 선택했을 때 기록 (사장님 통계의 "누적 검색수" 집계용)
  Future<void> recordSearchResultClick(String restaurantId) async {
    await _analyticsRepo.recordSearchResultClick(restaurantId);
  }

  /// 매장 상세페이지 진입 시 기록 (사장님 통계의 "페이지 방문수" 집계용)
  Future<void> recordDetailView(String restaurantId) async {
    await _analyticsRepo.recordDetailView(restaurantId);
  }

  /// 사장님 통계용: 이 매장에 대해 사장님으로 승인받은 시점
  Future<DateTime?> fetchOwnerVerifiedSince(String restaurantId) async {
    final repo = _restaurantRepo;
    if (repo == null) return null;
    return repo.fetchOwnerVerifiedSince(restaurantId);
  }

  Future<OwnerSeatUpdate?> fetchOwnerSeatUpdate(String restaurantId) async {
    final repo = _restaurantRepo;
    if (repo == null) return null;
    try {
      return await repo.fetchOwnerSeatUpdate(restaurantId);
    } catch (e, st) {
      debugPrint('[Supabase] fetchOwnerSeatUpdate failed: $e\n$st');
      return null;
    }
  }

  Future<OwnerSeatUpdate?> fetchLatestOwnerSeatUpdate(String restaurantId) async {
    final repo = _restaurantRepo;
    if (repo == null) return null;
    try {
      return await repo.fetchLatestOwnerSeatUpdate(restaurantId);
    } catch (e, st) {
      debugPrint('[Supabase] fetchLatestOwnerSeatUpdate failed: $e\n$st');
      return null;
    }
  }

  Future<String?> submitOwnerSeatUpdate(
    String restaurantId,
    int availableSeats,
  ) async {
    if (!_ownsRestaurant(restaurantId)) {
      return '본인 매장만 입력할 수 있어요.';
    }
    if (availableSeats < 0) {
      return '0 이상의 숫자만 입력할 수 있어요.';
    }

    final repo = _restaurantRepo;
    if (repo == null) {
      return '서버에 연결할 수 없어요.';
    }

    final (coords, gpsErr) = await _resolveVenueGps(
      restaurantId,
      tooFarMessage: '매장 근처에서만 입장 가능 인원을 입력할 수 있어요.',
    );
    if (gpsErr != null) return gpsErr;

    try {
      await repo.submitOwnerSeatUpdate(
        restaurantId,
        availableSeats,
        latitude: coords!.lat,
        longitude: coords.lng,
      );
      return null;
    } on PostgrestException catch (e) {
      debugPrint('[Supabase] submitOwnerSeatUpdate: ${e.message}');
      final msg = e.message.trim();
      if (msg.contains('본인 매장')) {
        return '본인 매장만 입력할 수 있어요.';
      }
      if (msg.contains('0 이상')) {
        return '0 이상의 숫자만 입력할 수 있어요.';
      }
      if (msg.contains('위치') || msg.contains('근처')) {
        return msg;
      }
      if (msg.isNotEmpty) return msg;
      return '반영에 실패했어요. 잠시 후 다시 시도해주세요.';
    } catch (e, st) {
      debugPrint('[Supabase] submitOwnerSeatUpdate failed: $e\n$st');
      return '반영에 실패했어요. 잠시 후 다시 시도해주세요.';
    }
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

  /// 사업자등록증 이미지 업로드 (사장님 인증 신청용). 실패 시 예외를 그대로 던짐.
  Future<String> uploadOwnerLicenseImage(Uint8List bytes, String ext) async {
    final repo = _restaurantRepo;
    if (repo == null) throw Exception('Supabase 연결이 필요해요.');
    return repo.uploadOwnerLicenseImage(bytes, ext);
  }

  /// 사장님 인증 신청 제출 (가게 선택 후 사업자등록증 + 연락처)
  Future<String?> submitOwnerApplication({
    required String restaurantId,
    required String phone,
    required String email,
    required List<String> licensePaths,
    bool notifyPush = false,
    bool notifySms = false,
  }) async {
    if (!_hasSupabaseSession) return '로그인이 필요해요.';
    final repo = _restaurantRepo;
    if (repo == null) return 'Supabase 연결이 필요해요.';
    try {
      await repo.submitOwnerApplication(
        restaurantId: restaurantId,
        phone: phone,
        email: email,
        licensePaths: licensePaths,
        notifyPush: notifyPush,
        notifySms: notifySms,
      );
      return null;
    } on PostgrestException catch (e) {
      debugPrint('[submitOwnerApplication] $e');
      return e.message;
    } catch (e, st) {
      debugPrint('[submitOwnerApplication] failed: $e\n$st');
      return '신청 제출에 실패했어요.';
    }
  }

  /// 내 최신 사장님 인증 신청 상태 (없으면 null)
  Future<Map<String, dynamic>?> fetchMyOwnerApplication() async {
    final repo = _restaurantRepo;
    if (repo == null) return null;
    try {
      return await repo.fetchMyOwnerApplication();
    } catch (e, st) {
      debugPrint('[fetchMyOwnerApplication] failed: $e\n$st');
      return null;
    }
  }

  /// 사장님 본인 매장 등록 해제. 마지막 매장이면 일반 유저 탭 구성으로 전환.
  Future<String?> releaseOwnerRestaurant(String restaurantId) async {
    if (!_ownsRestaurant(restaurantId)) {
      return '본인 매장만 삭제할 수 있어요.';
    }
    if (!_hasSupabaseSession) {
      return '로그인이 필요해요.';
    }

    final repo = _restaurantRepo;
    if (repo == null) {
      return '서버에 연결할 수 없어요.';
    }

    try {
      await repo.releaseOwnerRestaurant(restaurantId);
    } on PostgrestException catch (e) {
      final msg = e.message;
      if (msg.contains('NOT_OWNER')) return '본인 매장만 삭제할 수 있어요.';
      if (msg.contains('LOGIN_REQUIRED')) return '로그인이 필요해요.';
      debugPrint('[releaseOwnerRestaurant] RPC: $msg');
      return '매장 삭제에 실패했어요.';
    } catch (e, st) {
      debugPrint('[releaseOwnerRestaurant] failed: $e\n$st');
      return '매장 삭제에 실패했어요.';
    }

    try {
      await _syncOwnerRestaurantIdsFromDb();
      await _syncMetadata({'restaurant_ids': _ownerRestaurantIds});
      await refreshRestaurants();
      notifyListeners();
      return null;
    } catch (e, st) {
      debugPrint('[releaseOwnerRestaurant] sync failed: $e\n$st');
      return '매장 삭제에 실패했어요.';
    }
  }

  /// 사장님 매장 관리 공용 에러 매핑
  String _ownerUpdateErrorMessage(Object e) {
    if (e is PostgrestException) {
      final msg = e.message.trim();
      if (msg.isNotEmpty) return msg;
    }
    return '저장에 실패했어요. 잠시 후 다시 시도해주세요.';
  }

  /// 사장님 대표사진 변경 (Storage 업로드 실패 시 base64 폴백 없이 에러 반환)
  Future<String?> ownerUpdateRestaurantPhoto(
    String restaurantId, {
    required Uint8List bytes,
    required String ext,
  }) async {
    if (!_ownsRestaurant(restaurantId)) return '본인 매장만 수정할 수 있어요.';
    final repo = _restaurantRepo;
    if (repo == null) return '서버에 연결할 수 없어요.';
    try {
      final url = await repo.uploadOwnerPhoto(bytes, ext);
      await repo.ownerUpdateRestaurant(
        restaurantId,
        imageUrl: url,
        imageSource: 'owner',
      );
      await refreshRestaurants();
      notifyListeners();
      return null;
    } catch (e, st) {
      debugPrint('[ownerUpdateRestaurantPhoto] failed: $e\n$st');
      return _ownerUpdateErrorMessage(e);
    }
  }

  /// 사장님이 직접 등록한 대표사진을 원래 구글맵 사진으로 되돌림
  Future<String?> ownerRevertRestaurantPhotoToGoogle(String restaurantId) async {
    if (!_ownsRestaurant(restaurantId)) return '본인 매장만 수정할 수 있어요.';
    final repo = _restaurantRepo;
    if (repo == null) return '서버에 연결할 수 없어요.';
    try {
      await repo.ownerUpdateRestaurant(restaurantId, imageSource: 'google');
      await refreshRestaurants();
      notifyListeners();
      return null;
    } catch (e, st) {
      debugPrint('[ownerRevertRestaurantPhotoToGoogle] failed: $e\n$st');
      return _ownerUpdateErrorMessage(e);
    }
  }

  /// 사장님 메뉴 사진(최대 3장) 저장. 기존 유지분(existingUrls) + 신규 업로드분(newImages) 병합.
  Future<String?> ownerUpdateMenuPhotos(
    String restaurantId, {
    required List<String> existingUrls,
    required List<({Uint8List bytes, String ext})> newImages,
  }) async {
    if (!_ownsRestaurant(restaurantId)) return '본인 매장만 수정할 수 있어요.';
    final repo = _restaurantRepo;
    if (repo == null) return '서버에 연결할 수 없어요.';
    try {
      final urls = List<String>.from(existingUrls);
      for (final img in newImages) {
        urls.add(await repo.uploadOwnerPhoto(img.bytes, img.ext));
      }
      await repo.ownerUpdateRestaurant(restaurantId, menuPhotoUrls: urls);
      await refreshRestaurants();
      notifyListeners();
      return null;
    } catch (e, st) {
      debugPrint('[ownerUpdateMenuPhotos] failed: $e\n$st');
      return _ownerUpdateErrorMessage(e);
    }
  }

  /// 사장님 대표 메뉴(이름+가격) 저장
  Future<String?> ownerUpdateRestaurantMenu(
    String restaurantId,
    List<MenuItem> menu,
  ) async {
    if (!_ownsRestaurant(restaurantId)) return '본인 매장만 수정할 수 있어요.';
    final repo = _restaurantRepo;
    if (repo == null) return '서버에 연결할 수 없어요.';
    try {
      await repo.ownerUpdateRestaurant(restaurantId, menu: menu);
      await refreshRestaurants();
      notifyListeners();
      return null;
    } catch (e, st) {
      debugPrint('[ownerUpdateRestaurantMenu] failed: $e\n$st');
      return _ownerUpdateErrorMessage(e);
    }
  }

  /// 사장님 영업시간 저장 (구글 캐시된 요일별 시간은 서버에서 함께 무효화됨)
  Future<String?> ownerUpdateRestaurantHours(
    String restaurantId,
    String hours,
  ) async {
    if (!_ownsRestaurant(restaurantId)) return '본인 매장만 수정할 수 있어요.';
    final repo = _restaurantRepo;
    if (repo == null) return '서버에 연결할 수 없어요.';
    try {
      await repo.ownerUpdateRestaurant(
        restaurantId,
        hours: hours,
        hoursDisplay: hours,
      );
      await refreshRestaurants();
      notifyListeners();
      return null;
    } catch (e, st) {
      debugPrint('[ownerUpdateRestaurantHours] failed: $e\n$st');
      return _ownerUpdateErrorMessage(e);
    }
  }

  /// 사장님 매장 공지(최대 500자) 저장
  Future<String?> ownerUpdateRestaurantNotice(
    String restaurantId,
    String notice,
  ) async {
    if (!_ownsRestaurant(restaurantId)) return '본인 매장만 수정할 수 있어요.';
    if (notice.length > 500) return '공지는 500자를 넘을 수 없어요.';
    final repo = _restaurantRepo;
    if (repo == null) return '서버에 연결할 수 없어요.';
    try {
      await repo.ownerUpdateRestaurant(restaurantId, ownerNotice: notice);
      await refreshRestaurants();
      notifyListeners();
      return null;
    } catch (e, st) {
      debugPrint('[ownerUpdateRestaurantNotice] failed: $e\n$st');
      return _ownerUpdateErrorMessage(e);
    }
  }

  Future<void> recordAppSession() async {
    if (!SupabaseService.isReady) return;
    if (SupabaseService.client.auth.currentUser == null) return;
    await _analyticsRepo.recordAppSession();
  }

  Future<void> recordBannerImpression(String restaurantId) async {
    await _analyticsRepo.recordBannerImpression(restaurantId);
  }

  Future<void> recordBannerClick(String restaurantId) async {
    await _analyticsRepo.recordBannerClick(restaurantId);
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
    await _syncPushNotifications();
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
    if (repo == null) {
      _restaurantsLoading = false;
      return;
    }

    try {
      final gen = ++_restaurantRefreshGen;
      final fetched = await repo.fetchAll();
      if (gen != _restaurantRefreshGen) return;
      _restaurants = fetched;
      _restaurantsLoadFailed = false;
      await _syncOwnerRestaurantIdsFromDb();
      await _syncPushNotifications();
    } catch (e, st) {
      debugPrint('[Supabase] load restaurants failed: $e\n$st');
      _restaurantsLoadFailed = true;
    } finally {
      _restaurantsLoading = false;
      notifyListeners();
    }
  }

  /// 영업시간 외에는 혼잡도 오버라이드보다 영업안함 우선 (오프라인/시드 전용)
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

  Future<void> _loadBannedWords() async {
    if (!SupabaseService.isReady) return;
    try {
      final words = await community.fetchBannedWords();
      setBannedWords(words);
    } catch (e) {
      debugPrint('[Community] fetchBannedWords failed: $e');
    }
    try {
      final nicknameWords =
          await community.fetchNicknameBannedWords();
      setNicknameBannedWords(nicknameWords);
    } catch (e) {
      debugPrint('[Community] fetchNicknameBannedWords failed: $e');
    }
  }

  // ── 리워드 ──

  String _myReferralCode = '';
  int _cycleReferrerEventCount = 0;
  int _cycleReferredEventCount = 0;
  int _totalReferrerEventCount = 0;
  int _totalReferredEventCount = 0;
  String get myReferralCode => _myReferralCode;
  /// 이번 스탬프북 사이클(마지막 쿠폰 발급 이후) 동안의 건수 — 스탬프북 화면용
  int get cycleReferrerEventCount => _cycleReferrerEventCount;
  int get cycleReferredEventCount => _cycleReferredEventCount;
  /// 누적 건수 — 친구 초대 페이지용
  int get totalReferrerEventCount => _totalReferrerEventCount;
  int get totalReferredEventCount => _totalReferredEventCount;

  Future<void> fetchMyReferralHistory() async {
    final repo = _rewardRepo;
    if (repo == null) return;
    try {
      final (code, cycleReferrer, cycleReferred, totalReferrer, totalReferred) =
          await repo.fetchMyReferralHistory();
      _myReferralCode = code;
      _cycleReferrerEventCount = cycleReferrer;
      _cycleReferredEventCount = cycleReferred;
      _totalReferrerEventCount = totalReferrer;
      _totalReferredEventCount = totalReferred;
      notifyListeners();
    } catch (e) {
      debugPrint('[Reward] fetchMyReferralHistory failed: $e');
    }
  }

  Future<String> resolveGifticonImageUrl(String? raw) async {
    final repo = _rewardRepo;
    if (repo == null) return raw ?? '';
    return repo.resolveGifticonImageUrl(raw);
  }

  Future<String?> submitAppFeedback({
    required String category,
    required String content,
  }) async {
    if (!SupabaseService.isReady) {
      return '서버에 연결할 수 없어요. 잠시 후 다시 시도해주세요.';
    }
    if (SupabaseService.client.auth.currentUser == null) {
      return '로그인 후 피드백을 보낼 수 있어요.';
    }
    try {
      await _feedbackRepo.submit(category: category, content: content);
      return null;
    } catch (e) {
      debugPrint('[Feedback] submitAppFeedback: $e');
      return '전송에 실패했어요. 잠시 후 다시 시도해주세요.';
    }
  }

  Future<void> fetchMyReward() async {
    final repo = _rewardRepo;
    if (repo == null) return;
    var rewardOk = false;
    var giftOk = false;
    try {
      _reward = await repo.fetchMyReward();
      rewardOk = true;
      debugPrint('[Reward] fetched todayStamps=${_reward.todayStamps} totalStamps=${_reward.totalStamps}');
    } catch (e) {
      debugPrint('[Reward] fetchMyReward failed: $e');
    }
    try {
      _myGifticons = await repo.fetchMyGifticons();
      giftOk = true;
    } catch (e) {
      debugPrint('[Reward] fetchMyGifticons failed: $e');
    }
    _rewardLoadFailed = !rewardOk && !giftOk;
    notifyListeners();
  }


  /// 반환: null이면 성공(또는 건너뛰기), non-null이면 사용자에게 보여줄 에러 메시지
  Future<String?> submitReferralCode(String code) async {
    final trimmed = code.trim();
    if (trimmed.isEmpty) {
      await _finishReferralPrompt();
      return null;
    }

    final repo = _rewardRepo;
    if (repo == null) return '서버에 연결할 수 없어요.';

    final (status, message) = await repo.applyReferralCode(trimmed);
    switch (status) {
      case 'ok':
        await consumeReferralCodeFromInviteLink();
        await fetchMyReward();
        await _finishReferralPrompt();
        return null;
      case 'invalid_code':
        return '존재하지 않는 추천인 코드예요.';
      case 'self_referral':
        return '본인 코드는 입력할 수 없어요.';
      case 'already_used':
        return '이미 추천인 코드를 등록했어요.';
      case 'referrer_daily_limit':
        return '이 추천인 코드는 오늘 이미 사용됐어요.\n내일 다시 시도해주세요.';
      default:
        return message ?? '잠시 후 다시 시도해주세요.';
    }
  }

  Future<void> skipReferralPrompt() => _finishReferralPrompt();

  Future<void> _finishReferralPrompt() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = _sessionUserId(prefs);
    await _clearReferralPromptPending(prefs, userId);
    await _markReferralPromptDone(prefs, userId);
    if (_pendingSignupCompleteMessage) {
      _pendingSignupCompleteMessage = false;
      _showSignupCompleteMessage = true;
    }
    _stage = 'app';
    if (hasOwnerTab) _mainTabIndex = 0;
    notifyListeners();
    _flushPendingRemotePush();
  }

  Future<String?> markGifticonUsed(String gifticonId) async {
    final repo = _rewardRepo;
    if (repo == null) return '서버에 연결할 수 없어요.';
    final err = await repo.markGifticonUsed(gifticonId);
    if (err == null) await fetchMyReward();
    return err;
  }

  Future<String?> removeGifticonFromBox(Gifticon gifticon) async {
    final isActive = gifticon.status == 'assigned' &&
        (gifticon.expiresAt == null ||
            !gifticon.expiresAt!.isBefore(DateTime.now()));
    if (isActive) {
      final err = await markGifticonUsed(gifticon.id);
      if (err != null) return err;
    }

    _hiddenGifticonIds.add(gifticon.id);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _kHiddenGifticons,
      _hiddenGifticonIds.toList(),
    );
    notifyListeners();
    return null;
  }
}
