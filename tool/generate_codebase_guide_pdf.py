#!/usr/bin/env python3
# ignore_for_file: avoid_print
"""캠퍼스런치 코드베이스 디버깅 가이드 PDF 생성.

사용법:
  python3 tool/generate_codebase_guide_pdf.py
"""
from __future__ import annotations

from datetime import date
from pathlib import Path

from fpdf import FPDF
from fpdf.enums import XPos, YPos

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "docs" / "CODEBASE_DEBUG_GUIDE.pdf"
FONT = "/Library/Fonts/Arial Unicode.ttf"


def _wrap_line(pdf: FPDF, text: str, width: float, size: float) -> list[str]:
    """페이지 너비에 맞게 줄바꿈 (가로 잘림 방지)."""
    pdf.set_font("KR", "", size)
    if not text:
        return [""]
    if pdf.get_string_width(text) <= width:
        return [text]

    # 공백이 있으면 단어 단위, 없으면 문자 단위
    if " " in text:
        words = text.split(" ")
        lines: list[str] = []
        current = words[0]
        for word in words[1:]:
            trial = f"{current} {word}"
            if pdf.get_string_width(trial) <= width:
                current = trial
            else:
                lines.append(current)
                current = word
        lines.append(current)
        return lines

    lines: list[str] = []
    current = ""
    for ch in text:
        trial = current + ch
        if pdf.get_string_width(trial) <= width:
            current = trial
        else:
            if current:
                lines.append(current)
            current = ch
    if current:
        lines.append(current)
    return lines


class GuidePDF(FPDF):
    def __init__(self) -> None:
        super().__init__()
        self.add_font("KR", "", FONT)
        self.set_margins(12, 12, 12)
        self.set_auto_page_break(auto=True, margin=12)

    def _write(
        self,
        text: str,
        *,
        size: float = 9.5,
        h: float = 4.5,
        fill: bool = False,
    ) -> None:
        self.set_x(self.l_margin)
        self.set_font("KR", "", size)
        if fill:
            self.set_fill_color(245, 245, 245)
        self.multi_cell(
            self.epw,
            h,
            text,
            fill=fill,
            new_x=XPos.LMARGIN,
            new_y=YPos.NEXT,
        )

    def section(self, title: str, level: int = 1) -> None:
        sizes = {1: 14, 2: 11, 3: 10}
        heights = {1: 6, 2: 5, 3: 4.5}
        if level == 1:
            self.ln(2.5)
        else:
            self.ln(1)
        self._write(title, size=sizes.get(level, 10), h=heights.get(level, 5))

    def body(self, text: str) -> None:
        for paragraph in text.split("\n"):
            if not paragraph.strip():
                self.ln(1)
                continue
            for line in _wrap_line(self, paragraph, self.epw, 9.5):
                self._write(line, size=9.5, h=4.5)

    def item(self, title: str, desc: str) -> None:
        """제목+설명을 한 덩어리로 (폴더·컨벤션 목록용)."""
        self.ln(0.8)
        self._write(title, size=10, h=4.5)
        for line in _wrap_line(self, desc, self.epw, 9):
            self._write(line, size=9, h=4.2)

    def bullets(self, items: list[str]) -> None:
        for item in items:
            for i, line in enumerate(_wrap_line(self, item, self.epw - 4, 9.5)):
                prefix = "• " if i == 0 else "  "
                self._write(f"{prefix}{line}", size=9.5, h=4.3)

    def code(self, text: str) -> None:
        self.ln(0.5)
        code_size = 7.8
        line_h = 3.8
        for raw in text.split("\n"):
            if raw == "":
                self.ln(1.2)
                continue
            safe = raw.replace("\t", "  ")
            for part in _wrap_line(self, safe, self.epw, code_size):
                self._write(part, size=code_size, h=line_h, fill=True)
        self.ln(0.8)


def build(pdf: GuidePDF) -> None:
    today = date.today().isoformat()

    pdf.add_page()
    pdf.set_font("KR", "", 20)
    pdf.set_x(pdf.l_margin)
    pdf.multi_cell(
        pdf.epw, 10, "캠퍼스런치\n코드베이스 디버깅 가이드",
        new_x=XPos.LMARGIN, new_y=YPos.NEXT,
    )
    pdf.ln(3)
    pdf.body(
        f"작성일: {today}\n"
        "목적: 파일 구조, 모듈 연결, DB 연결, 코딩·디버깅 방법, 기능별 플로우\n"
        "대상: develop 브랜치 (파트너 pull + 버그 수정 + 사장님 탭 개편 반영)",
    )

    pdf.add_page()
    pdf.section("목차", 1)
    toc = """
1. 프로젝트 한눈에 보기
2. 레이어 구조 (화면 -> 상태 -> 데이터 -> DB)
3. lib/ 폴더별 역할
4. 앱 시작·화면 전환 흐름
5. 기능별 플로우
   5.1 회원·인증
   5.2 혼잡도 (표시·제보·계산·실시간)
   5.3 사장님 (코드 인증·탭·입장 인원)
   5.4 관리자
   5.5 푸시·북마크·홈 필터
   5.6 리워드(스탬프·기프티콘)
   5.7 APK 테스트·소셜 로그인
6. Supabase SQL 맵
7. DB 연결 상세 (앱 <-> Supabase)
8. 코딩 컨벤션
9. 디버깅 방법
10. 외부 서비스·환경 변수
11. 증상별 디버깅 체크리스트
12. 최근 주요 변경 요약
"""
    pdf.body(toc.strip())

    pdf.add_page()
    pdf.section("1. 프로젝트 한눈에 보기", 1)
    pdf.body(
        "Flutter 앱 + Supabase 백엔드 구조입니다.\n"
        "상태 관리는 Provider 패턴 하나(AppProvider)로 중앙 집중됩니다.\n"
        "화면(Screens)은 AppProvider를 watch/read 하고, DB 접근은 data/ 레포지토리가 담당합니다."
    )
    pdf.code(
        "campuslunch-app/\n"
        "  lib/           ← Flutter 앱 (UI + 상태 + 데이터)\n"
        "  supabase/      ← SQL (테이블·RPC·RLS·트리거)\n"
        "  docs/          ← 설정·가이드 문서\n"
        "  tool/          ← 시드·유틸 스크립트\n"
        "  test/          ← 단위 테스트\n"
        "  .env           ← Supabase URL, API 키 (Git 포함)\n"
        "  .env.secrets   ← Secret 키 (시드용, Git 포함 private repo)"
    )

    pdf.section("2. 레이어 구조", 1)
    pdf.body(
        "데이터는 항상 아래 방향으로, UI 이벤트는 위에서 아래로 흐릅니다."
    )
    pdf.code(
        "[ Screens / Widgets ]  home_screen, detail_screen, owner_screen ...\n"
        "         |  onTap / watch\n"
        "         v\n"
        "[ AppProvider ]        stage, restaurants, reportStatus, verifyOwnerCode ...\n"
        "         |  repository 호출\n"
        "         v\n"
        "[ data/ + services/ ]  supabase_restaurant_repository, profile_repository ...\n"
        "         |  SupabaseClient RPC / from('table')\n"
        "         v\n"
        "[ Supabase ]           PostgreSQL + Auth + Realtime + Storage"
    )
    pdf.body(
        "혼잡도 계산은 DB 트리거(recalculate)가 주력이고, 앱은 crowd_status_algorithm.dart로 "
        "클라이언트 폴백·표시를 합니다."
    )

    pdf.section("3. lib/ 폴더별 역할", 1)

    folders = [
        (
            "main.dart",
            "앱 진입점. .env 로드 -> Kakao/Google/Supabase/Push 초기화 -> AppProvider.init()",
        ),
        (
            "providers/app_provider.dart",
            "* 핵심. stage(화면 단계), 로그인, restaurants 목록, 제보, 사장님, 북마크, "
            "푸시, Realtime 구독, admin 설정 전부 여기.",
        ),
        (
            "screens/",
            "화면 단위 UI. main_screen=하단탭, home/map/my/owner/admin/login 등.",
        ),
        (
            "widgets/",
            "재사용 UI. restaurant_card, report_sheet, owner_verify_sheet, status_badge 등.",
        ),
        (
            "data/",
            "DB 접근·매핑. supabase_restaurant_repository(매장·혼잡도), profile_repository(users), "
            "auth_repository, analytics_repository, reward_repository.",
        ),
        (
            "data/crowd_*",
            "혼잡도 전용. level_mapper(enum<->한글), algorithm(v2 계산), helpers(제보 집계).",
        ),
        (
            "services/",
            "외부 SDK 래퍼. supabase_service, kakao/google_auth, push_notification, places.",
        ),
        (
            "models/",
            "데이터 클래스. Restaurant, Account, CrowdReport, OwnerSeatUpdate, Reward 등.",
        ),
        (
            "utils/",
            "순수 헬퍼. business_hours, available_restaurant_ranking, report_feedback, 라벨.",
        ),
        (
            "config/env.dart",
            "SUPABASE_URL, ANON_KEY, Kakao, Google Maps/OAuth 키 읽기.",
        ),
    ]
    for name, desc in folders:
        pdf.item(name, desc)

    pdf.section("4. 앱 시작·화면 전환 흐름", 1)
    pdf.code(
        "main() -> AppProvider.init()\n"
        "  +- Supabase 세션 있음 -> _onSupabaseSignedIn -> stage=app/admin\n"
        "  +- 로컬 세션 있음 -> prefs 복원 -> stage=app/admin\n"
        "  +- 없음 -> onboarding 또는 login\n"
        "\n"
        "AppProvider.stage -> main.dart _Root switch:\n"
        "  splash | onboarding | login\n"
        "  location_permission | notification_permission\n"
        "  app -> MainScreen (하단 탭)\n"
        "  admin -> AdminScreen"
    )
    pdf.body(
        "MainScreen 하단 탭:\n"
        "• 일반 유저: [홈] [지도] [MY]\n"
        "• 사장님(hasOwnerTab): [사장님] [홈] [지도] [MY] — 인증 후 기본 탭=사장님\n"
        "IndexedStack으로 탭 전환 (상태 유지)."
    )

    pdf.add_page()
    pdf.section("5. 기능별 플로우", 1)

    pdf.section("5.1 회원·인증", 2)
    pdf.code(
        "LoginScreen\n"
        "  -> AppProvider.login / register / loginWithKakao / loginWithGoogle\n"
        "  -> Supabase Auth + ProfileRepository.upsertFromAuthUser (public.users)\n"
        "  -> _saveSession (SharedPreferences + stage 결정)\n"
        "\n"
        "RPC: email_signup_status, oauth_login_email_check, is_nickname_available\n"
        "탈퇴: delete_own_account"
    )

    pdf.section("5.2 혼잡도", 2)
    pdf.code(
        "[표시]\n"
        "SupabaseRestaurantRepository.fetchAll()\n"
        "  ← restaurants + crowd_reports + crowd_status\n"
        "  -> _mergeRow() + computeStatusFromReports()\n"
        "  -> Restaurant.status (여유로움/약간혼잡/자리없음/영업안함)\n"
        "  -> HomeScreen / MapScreen / DetailScreen / RestaurantCard\n"
        "\n"
        "[제보]\n"
        "ReportSheet -> report_feedback.submitCrowdReportFeedback()\n"
        "  -> AppProvider.reportStatus()\n"
        "     source = owner (본인 매장+role owner) | user (그 외)\n"
        "     user: 5분 쿨다운 + GPS 150m (AppProvider, kDebugMode 우회)\n"
        "     제한 검증: 서버 RPC X, 클라이언트 전담\n"
        "  -> RPC submit_crowd_report\n"
        "  -> crowd_reports INSERT -> 트리거 -> recalculate_crowd_status\n"
        "\n"
        "[실시간]\n"
        "AppProvider._subscribeRealtime()\n"
        "  crowd_status | crowd_reports | owner_seat_updates 변경 -> fetchAll()"
    )
    pdf.body(
        "DB enum: crowd_level (normal/full/closed), crowd_source (user/owner/system). "
        "한글 UI는 metadata.status + CrowdLevelMapper로 변환."
    )

    pdf.section("5.3 사장님", 2)
    pdf.code(
        "[코드 인증]\n"
        "MyScreen / OwnerVerifySheet -> verifyOwnerCode()\n"
        "  -> RPC claim_owner_by_code (로그인 필수)\n"
        "  -> restaurants.owner_id, users.role=owner\n"
        "  -> stage=app, mainTabIndex=0 (사장님 탭)\n"
        "\n"
        "[혼잡도 변경]\n"
        "OwnerScreen -> reportStatus() — 본인 매장만 owner source\n"
        "\n"
        "[입장 인원]\n"
        "OwnerScreen -> submitOwnerSeatUpdate()\n"
        "  -> RPC submit_owner_seat_update\n"
        "  -> DetailScreen: get_owner_seat_update (1시간 표시)"
    )
    pdf.body(
        "소유 매장 ID: fetchOwnedRestaurantIds() (restaurants.owner_id) + "
        "JWT metadata restaurant_ids 폴백."
    )

    pdf.section("5.4 관리자", 2)
    pdf.code(
        "login admin/admin123 (debug) 또는 Supabase role=admin\n"
        "  -> AdminScreen\n"
        "  -> fetchMetrics (admin_dashboard_metrics)\n"
        "  -> 매장 CRUD, owner_code 생성, manual_rank, owner_influence\n"
        "  -> AdminMapRegisterTab + PlacesService (Google Places)"
    )

    pdf.section("5.5 푸시·북마크·홈", 2)
    pdf.code(
        "[푸시] FCM 원격 푸시 (앱 종료 시에도 수신)\n"
        "  FcmPushService — 토큰 upsert + 포그라운드 로컬 표시\n"
        "  Edge: send-peak-push (cron), send-community-push (댓글)\n"
        "  테이블: user_push_tokens, user_notification_prefs, peak_push_sent_log\n"
        "  SQL: fcm_push.sql / 배포: docs/FCM_PUSH_SETUP.md\n"
        "  어드민 PushSettingsPage -> push_notification_config\n"
        "\n"
        "[북마크] toggleBookmark -> SharedPreferences + Auth metadata\n"
        "  BookmarkListScreen, HomeScreen 북마크 필터\n"
        "\n"
        "[홈 필터] HomeScreen 로컬 state\n"
        "  정렬·지역·카테고리·검색·북마크만\n"
        "  available_restaurant_ranking.dart"
    )

    pdf.section("5.6 리워드", 2)
    pdf.code(
        "제보 성공 -> submit_crowd_report.sql -> 스탬프 JSON\n"
        "  -> AppProvider.lastStampResult, UserReward 로컬 갱신\n"
        "  -> RewardScreen (MY 탭), redeem_gifticon RPC\n"
        "  lib/data/reward_repository.dart, lib/models/reward.dart\n"
        "\n"
        "스탬프 일일 한도: grant_stamp 하루 최대 3 (KST 10–19시).\n"
        "grant_stamp / _perform_gifticon_redeem / grant_referral_stamp 는\n"
        "  클라이언트 execute 금지 (SECURITY DEFINER 내부 전용).\n"
        "정본 제보 RPC: supabase/submit_crowd_report.sql 만 CREATE OR REPLACE.\n"
        "  (jsonb 스탬프 + 50m + advisory lock). 옛 본문은 supabase/archive/."
    )

    pdf.section("5.7 APK 테스트·소셜 로그인", 2)
    pdf.code(
        "flutter build apk --release\n"
        "  key.properties 있음 -> 릴리스 keystore 서명\n"
        "  없음 -> debug keystore로 release APK 서명\n"
        "\n"
        "flutter run(디버그) OK, APK만 실패 -> 코드 버그가 아니라\n"
        "  OAuth 콘솔에 APK 서명 SHA-1/키 해시 미등록 가능성 큼\n"
        "\n"
        "Google: Cloud Console Android OAuth + SHA-1\n"
        "  cd android && ./gradlew :app:signingReport\n"
        "Kakao: developers.kakao.com Android 키 해시\n"
        "  dart run tool/print_kakao_android_key_hash.dart\n"
        "  dart run tool/print_kakao_android_key_hash.dart --release\n"
        "Apple(iOS): Developer Sign in with Apple + Supabase Provider\n"
        "  앱 .env Client ID 불필요 — docs/APPLE_SUPABASE_SETUP.md\n"
        "iOS 카카오톡: kakao{KEY}://oauth 는 SceneDelegate가 AppDelegate로 전달.\n"
        "  AppDelegate는 카카오 OAuth URL을 Flutter 딥링크(supabase PKCE)로 넘기지 않음.\n"
        "  Native signInWithIdToken. issuer 차단 시 Dashboard Kakao Enabled +\n"
        "  Native App Key. 그래도 실패면 Auth 게이트웨이 issuer 허용 필요.\n"
        "\n"
        "「로그인이 취소되었어요」= SDK가 설정 오류를 cancel로 반환하는 경우 많음"
    )

    pdf.add_page()
    pdf.section("6. Supabase SQL 실행 순서", 1)
    pdf.code(
        "1.  users_auth.sql           users + Auth 트리거\n"
        "2.  policies.sql             RLS (restaurants, crowd_reports)\n"
        "3.  rpc_email_signup_status.sql\n"
        "4.  rpc_claim_owner.sql       사장 코드 인증\n"
        "5.  rpc_delete_own_account.sql\n"
        "6.  rpc_nickname_available.sql\n"
        "7.  rpc_oauth_login_email_check.sql\n"
        "8.  analytics_events.sql\n"
        "9.  crowd_status.sql          헬퍼 (제보 RPC 없음)\n"
        "10. crowd_status_v2_compute.sql  v2 계산 + 트리거\n"
        "11. push_analytics.sql\n"
        "12. fcm_push.sql / owner_seat_updates.sql\n"
        "13. rewards.sql               스탬프·기프티콘 (제보 RPC 없음)\n"
        "14. stamp_hours_10_to_19.sql / rewards_daily_cap_to_3.sql\n"
        "15. submit_crowd_report.sql   제보 RPC 정본\n"
        "16. hotfix_prelaunch_audit_fixes.sql  grant 회수·약관·푸시\n"
        "17. community_block.sql       차단 테이블·피드/댓글 필터\n"
        "\n"
        "crowd_status.sql 하단: Realtime publication 추가 블록 (재실행)\n"
        "schema.sql — 문서용 (실행 X)\n"
        "supabase/archive/ — 일회성 핫픽스. 재실행 금지"
    )
    pdf.body(
        "주요 테이블: users, restaurants, crowd_reports, crowd_status, "
        "owner_seat_updates, analytics_events, gifticons, system_settings, "
        "community_blocks."
    )

    pdf.add_page()
    pdf.section("7. DB 연결 상세 (앱 <-> Supabase)", 1)
    pdf.body(
        "앱은 supabase_flutter SDK 하나로 PostgreSQL·Auth·Realtime·Storage에 "
        "접속합니다. 화면은 DB를 직접 호출하지 않고, 항상 Repository 경유입니다."
    )
    pdf.code(
        "[연결 초기화]\n"
        "main.dart\n"
        "  dotenv.load('.env')\n"
        "  Env.isSupabaseConfigured  (URL + ANON_KEY 둘 다 있어야 true)\n"
        "  SupabaseService.initialize()\n"
        "    -> Supabase.initialize(url, anonKey)\n"
        "    -> SupabaseService.client == Supabase.instance.client\n"
        "\n"
        "[요청 경로]\n"
        "Screen/Widget\n"
        "  -> AppProvider (비즈니스 로직·세션·캐시)\n"
        "  -> *Repository (SupabaseClient 주입 가능, 기본=SupabaseService.client)\n"
        "  -> client.from('table') | client.rpc('fn') | client.storage\n"
        "  -> PostgREST + RLS + PostgreSQL 함수"
    )

    pdf.section("7.1 Auth 연동", 2)
    pdf.code(
        "Supabase Auth (auth.users)\n"
        "  email OTP / Kakao / Google -> JWT 세션\n"
        "  trigger handle_new_user() -> public.users 자동 upsert\n"
        "\n"
        "앱 로그인 후:\n"
        "  ProfileRepository.upsertFromAuthUser()  (닉네임·provider 동기화)\n"
        "  ProfileRepository.fetch()               (role, nickname)\n"
        "  AppProvider._saveSession()              (SharedPreferences 백업)\n"
        "\n"
        "JWT role: app_metadata.role / user_metadata.role\n"
        "  admin 판별: SupabaseService.isAdmin\n"
        "  owner 매장: restaurants.owner_id = auth.uid()"
    )

    pdf.section("7.2 테이블·RPC 매핑", 2)
    pdf.code(
        "Repository              DB 접근\n"
        "----------------------------------------\n"
        "SupabaseRestaurantRepo  restaurants (SELECT/CRUD)\n"
        "                        crowd_reports (SELECT/INSERT/RPC)\n"
        "                        crowd_status (SELECT)\n"
        "                        owner_seat_updates (SELECT/RPC)\n"
        "                        system_settings (SELECT/UPSERT)\n"
        "                        storage (매장 이미지 업로드)\n"
        "                        RPC: submit_crowd_report, claim_owner_by_code,\n"
        "                             submit_owner_seat_update, admin_dashboard_metrics\n"
        "ProfileRepository       public.users (SELECT/UPDATE/UPSERT)\n"
        "                        RPC: is_nickname_available, delete_own_account\n"
        "AuthRepository          RPC: email_signup_status,\n"
        "                             oauth_login_email_check\n"
        "LegalConsentRepository  RPC: record_legal_consent,\n"
        "                             has_required_legal_consents,\n"
        "                             fetch_marketing_consent\n"
        "CommunityRepository     싱글톤. RPC: community_feed,\n"
        "                        block_user / unblock_user /\n"
        "                        my_blocked_users (차단 관리)\n"
        "FeedbackRepository      app_feedback INSERT\n"
        "AnalyticsRepository     analytics_events (INSERT)\n"
        "RewardRepository        gifticons, RPC: redeem_gifticon,\n"
        "                        storage signed URL\n"
        "Push (간접)             RPC: record_push_event"
    )

    pdf.section("7.3 RLS·보안", 2)
    pdf.body(
        "anon key는 클라이언트에 노출되므로, 접근 제어는 RLS + SECURITY DEFINER RPC로 합니다.\n"
        "• users: 본인 row만 SELECT/UPDATE (auth.uid() = id)\n"
        "• crowd_reports: INSERT는 RPC submit_crowd_report 경유 (소유·GPS 50m·쿨다운).\n"
        "  RLS: user_id=auth.uid(), owner source는 is_restaurant_owner 만.\n"
        "• grant_stamp / _perform_gifticon_redeem / grant_referral_stamp:\n"
        "  authenticated 실행 금지. 푸시 시크릿은 push_edge_runtime_config 만.\n"
        "• 필수 약관: has_required_legal_consents() (로컬 prefs는 캐시).\n"
        "• community_blocks: 본인(blocker_id)만 SELECT/INSERT/DELETE.\n"
        "  피드·댓글 RPC는 is_blocked_with()로 양방향 차단 필터.\n"
        "  block_user는 community_reports에 운영자 통지용 신고를 함께 남김.\n"
        "  정본 SQL: supabase/community_block.sql\n"
        "• restaurants: owner_id 변경은 claim_owner_by_code RPC만\n"
        "• admin CRUD: is_admin() 함수 + JWT role=admin\n"
        "Secret key(.env.secrets)는 앱에 넣지 않음 — tool/ 시드·관리 스크립트 전용."
    )

    pdf.section("7.4 Realtime·로컬 폴백", 2)
    pdf.code(
        "[Realtime] AppProvider._subscribeRealtime()\n"
        "  channel 'crowd_realtime'\n"
        "  postgres_changes: crowd_status (all)\n"
        "                  crowd_reports (insert)\n"
        "                  owner_seat_updates (insert)\n"
        "  -> _loadRestaurantsFromSupabase() -> notifyListeners()\n"
        "\n"
        "[Supabase 미설정/로드 실패]\n"
        "  initialRestaurants (lib/data/restaurants.dart) 시드 데이터\n"
        "  SharedPreferences cl_restaurant_overrides (혼잡도 로컬 저장)\n"
        "  제보: RPC 대신 로컬 override만 갱신\n"
        "  _supabaseRestaurantsLoaded == true 이면 override 무시"
    )

    pdf.section("7.5 Dart 모델 <-> DB 컬럼", 2)
    pdf.code(
        "Restaurant (Dart)     restaurants + crowd_status + reports 집계\n"
        "  id, name, category, area, status(한글), updated(분)\n"
        "\n"
        "CrowdReport           crowd_reports\n"
        "  level: crowd_level enum (normal/full/closed/relaxed)\n"
        "  source: crowd_source enum (user/owner/system)\n"
        "  metadata.status: 한글 UI ('여유로움' 등) — CrowdLevelMapper\n"
        "\n"
        "UserProfile           public.users\n"
        "  role: user | owner | admin\n"
        "  provider: email | kakao | google | apple"
    )

    pdf.add_page()
    pdf.section("8. 코딩 컨벤션", 1)
    pdf.body(
        "이 프로젝트는 '단일 Provider + Repository' 패턴을 일관되게 따릅니다. "
        "새 기능 추가 시 아래 규칙을 지키면 디버깅·리뷰가 쉬워집니다."
    )

    conventions = [
        (
            "상태 관리",
            "전역 상태는 AppProvider(ChangeNotifier) 하나. "
            "화면은 context.watch(리빌드) / context.read(이벤트)만 사용. "
            "홈 필터처럼 화면 전용 state는 StatefulWidget 로컬 state 허용.",
        ),
        (
            "레이어 분리",
            "Screens/Widgets: UI + 사용자 입력만. "
            "AppProvider: 검증·세션·목록 갱신·Realtime. "
            "data/*Repository: Supabase 호출·JSON 매핑. "
            "utils/: 순수 함수(영업시간, 정렬, 라벨). "
            "Screen에서 SupabaseClient 직접 import 금지.",
        ),
        (
            "Repository 패턴",
            "각 Repository는 SupabaseClient? client 생성자 주입 "
            "(테스트 mock용). 기본값 SupabaseService.client. "
            "try/catch + debugPrint('[태그] ...') 후 null/기본값 반환 또는 rethrow.",
        ),
        (
            "에러·피드백",
            "AppProvider 메서드는 String? err 반환 (null=성공). "
            "UI는 report_feedback.dart처럼 SnackBar 표시. "
            "async 후 context.mounted 체크 필수 (admin_screen 등).",
        ),
        (
            "로컬 저장",
            "SharedPreferences: 세션, 북마크, 푸시 설정, owner IDs. "
            "가입 비밀번호는 메모리만 (prefs에 평문 저장 금지). "
            "필수 약관은 서버 has_required_legal_consents가 정본, 로컬은 캐시. "
            "Supabase 로드 성공 시 cl_restaurant_overrides는 쓰지 않음. "
            "키 이름은 AppProvider 상단 _k* 상수로 관리.",
        ),
        (
            "혼잡도 이중 계산",
            "DB: crowd_status_v2_compute.sql 트리거가 정본. "
            "앱: crowd_status_algorithm.dart + helpers는 fetchAll 병합·폴백. "
            "SQL과 Dart 알고리즘 불일치 가능 — 버그 시 양쪽 비교.",
        ),
        (
            "디버그 전용",
            "kDebugMode: admin/admin123, owner/owner123 로컬 계정. "
            "제보 GPS·쿨다운 자동 우회(flutter run 테스트). "
            "debugPrint 태그: [Supabase] [Profile] [Auth] [Kakao] [Google] [Analytics].",
        ),
        (
            "파일 배치",
            "screens/ = 전체 화면, widgets/ = 재사용 조각, "
            "models/ = 불변 데이터 클래스(copyWith), "
            "constants/ = 이메일 OTP 등 고정값, config/ = Env.",
        ),
    ]
    for title, desc in conventions:
        pdf.item(title, desc)

    pdf.section("8.1 새 기능 추가 순서 (권장)", 2)
    pdf.code(
        "1. supabase/*.sql — 테이블/RPC/RLS 정의 (Dashboard에서 실행)\n"
        "2. lib/models/ — Dart 모델\n"
        "3. lib/data/*_repository.dart — DB 호출\n"
        "4. lib/providers/app_provider.dart — 상태·비즈니스 로직\n"
        "5. lib/screens/ 또는 widgets/ — UI\n"
        "6. test/ — 알고리즘·순수 로직 단위 테스트 (선택)"
    )

    pdf.add_page()
    pdf.section("9. 디버깅 방법", 1)
    pdf.body(
        "증상이 나왔을 때 '어디를 먼저 볼지' 순서입니다. "
        "아래 11장 체크리스트와 함께 쓰면 됩니다."
    )

    pdf.section("9.1 Flutter 앱 디버깅", 2)
    pdf.code(
        "실행: flutter run (또는 IDE Run)\n"
        "로그: Debug Console에서 태그 필터\n"
        "  [Supabase] Auth·세션·매장 로드\n"
        "  [Profile]  users 테이블\n"
        "  [Auth]     RPC email/oauth\n"
        "\n"
        "Release APK: adb logcat | grep -E 'Kakao|Google|SignIn'\n"
        "Hot reload: UI 변경. Hot restart: init()·세션 재실행.\n"
        "Provider 상태 확인: AppProvider 필드 breakpoint\n"
        "  restaurants, _userRole, _ownerRestaurantIds, stage"
    )

    pdf.section("9.2 Supabase Dashboard", 2)
    pdf.code(
        "Table Editor\n"
        "  restaurants.owner_id, users.role 확인\n"
        "  crowd_reports.level/source/metadata\n"
        "  crowd_status 최신 row\n"
        "\n"
        "SQL Editor\n"
        "  supabase/*.sql 순서대로 재실행\n"
        "  RPC 수동 호출: select submit_crowd_report(...)\n"
        "\n"
        "Authentication > Users\n"
        "  email confirmed?, provider, metadata.role\n"
        "\n"
        "Database > Replication\n"
        "  crowd_status, crowd_reports Realtime 활성화 확인\n"
        "\n"
        "Logs (API / Postgres)\n"
        "  RLS 거부, enum 타입 오류, RPC not found"
    )

    pdf.section("9.3 단위 테스트", 2)
    pdf.code(
        "flutter test\n"
        "  test/crowd_status_algorithm_test.dart\n"
        "    -> 혼잡도 v2 알고리즘 (DB 트리거와 대조)\n"
        "  test/widget_test.dart\n"
        "\n"
        "알고리즘 변경 시: Dart 테스트 + SQL recalculate 결과 비교"
    )

    pdf.section("9.4 단계별 추적 (기능별)", 2)
    pdf.code(
        "[혼잡도 표시 안 맞음]\n"
        "  1) Dashboard crowd_status vs 앱 Restaurant.status\n"
        "  2) fetchAll() _mergeRow + computeStatusFromReports\n"
        "  3) Realtime 구독 동작? stale fetch (_refreshGen)?\n"
        "  4) Supabase 로드됐는데 override prefs 잔존?\n"
        "\n"
        "[제보 실패]\n"
        "  1) 콘솔 AuthException / RPC error message\n"
        "  2) submit_crowd_report 배포 + enum 타입\n"
        "  3) user/owner: GPS 50m + user 5분 쿨다운 (AppProvider, kDebugMode 우회)\n"
        "     lastKnownPosition 사용 금지 — getCurrentPosition 만\n"
        "  4) owner: _ownsRestaurant + role=owner\n"
        "\n"
        "[사장님 인증]\n"
        "  1) 로그인 상태? claim_owner_by_code -> LOGIN_REQUIRED\n"
        "  2) restaurants.owner_code, owner_id\n"
        "  3) users.role = owner\n"
        "  4) fetchOwnedRestaurantIds() 결과 vs _ownerRestaurantIds"
    )

    pdf.section("9.5 알려진 함정", 2)
    pdf.bullets([
        "report_source enum 없음 — 실제 타입은 crowd_source",
        "profiles 테이블 없음 — public.users 사용",
        "영업시간: 앱은 description JSON hours_periods, SQL은 hours 문자열만 — "
        "영업안함 판정 불일치 가능",
        "제보 RPC는 submit_crowd_report.sql 만 수정. archive/ 및 옛 hotfix 재실행 금지",
        "스탬프 일일 한도 3 + KST 10–19시. grant_stamp 클라이언트 실행 금지",
        "푸시 Edge 시크릿을 SQL에 하드코딩하지 말 것 (push_edge_runtime_config)",
        "APK 소셜 로그인 실패 -> signingReport / 카카오 릴리스 키 해시 등록",
        "iOS 카카오톡 첫 로그인 「API 응답이 없습니다」: UIScene이 "
        "kakao{KEY}://oauth 를 google_sign_in_ios가 가로챌 수 있음. "
        "SceneDelegate가 OAuth URL만 AppDelegate로 전달하고, "
        "KakaoAuthService는 Talk 1회 재시도 후 Account 폴백",
        "Supabase 미설정 시 Realtime·RPC 전부 스킵, 로컬만 동작",
    ])

    pdf.section("10. 외부 서비스·환경 변수", 1)
    pdf.body(
        ".env: SUPABASE_URL, SUPABASE_ANON_KEY, KAKAO_NATIVE_APP_KEY, "
        "GOOGLE_MAPS_API_KEY, GOOGLE_OAUTH_* \n"
        ".env.secrets: SUPABASE_SECRET_KEY (시드·관리 스크립트용)\n"
        "android/key.properties + keystore: 릴리스 APK 서명 (git 제외)\n"
        "Supabase 미설정 시 -> initialRestaurants 시드 데이터 + 로컬 SharedPreferences만 사용."
    )

    pdf.section("11. 증상별 디버깅 체크리스트", 1)
    checks = [
        "혼잡도 제보 실패 -> submit_crowd_report.sql 적용? 50m GPS? enum?",
        "사장님 '본인 매장만' -> owner_id 연결? 로그인 후 코드 재인증?",
        "표시가 이상함 -> Realtime 갱신 vs 로컬 override(cl_restaurant_overrides) 잔존?",
        "영업안함 vs 여유로움 -> business_hours / hours_periods 불일치 (앱 vs SQL)?",
        "사장 홈 제보 -> 본인 매장=owner source, 타 매장=user source (GPS 필요)",
        "Auth 문제 -> public.users row 존재? email 미인증?",
        "Admin CRUD 실패 -> is_admin() / JWT role / RLS",
        "APK 카카오/구글 -> 로그인 취소? -> 릴리스 SHA-1·키 해시 콘솔 등록",
        "iOS 카카오톡 첫 로그인 API 응답 없음 -> SceneDelegate oauth 전달 / Talk 재시도",
    ]
    pdf.bullets(checks)

    pdf.section("12. 최근 주요 변경 요약", 1)
    pdf.body(
        "[75aa50a] 제보 제한 AppProvider 전담, kDebugMode 우회, GPS 150m\n"
        "  어드민 제보 제한 Supabase 토글 제거, 24h 영업 business_hours 수정\n"
        "  Realtime publication SQL, 스탬프 일일 한도 3 (rewards_daily_cap_to_3.sql)\n"
        "[48dd69d] Android 릴리스 서명 key.properties\n"
        "[4d4bdb3] 리워드 시스템 (RewardScreen, rewards.sql)\n"
        "[출시 감사] hotfix_prelaunch_audit_fixes.sql — RPC grant 회수, 약관 서버 게이트,\n"
        "  카카오 OAuth 이메일 체크, FCM 콜드스타트, 비밀번호 prefs 제거, 푸시 시크릿 테이블화\n"
        "[이전] 홈 필터/정렬, Realtime 구독, 사장님 MainScreen 탭, owner enum 수정"
    )

    pdf.section("핵심 파일 빠른 참조", 2)
    pdf.code(
        "상태 허브     lib/providers/app_provider.dart\n"
        "매장·혼잡도   lib/data/supabase_restaurant_repository.dart\n"
        "제보 UI       lib/widgets/report_sheet.dart\n"
        "제보 연결     lib/utils/report_feedback.dart\n"
        "혼잡도 계산   lib/data/crowd_status_algorithm.dart\n"
        "             supabase/crowd_status_v2_compute.sql\n"
        "사장 RPC      supabase/rpc_claim_owner.sql\n"
        "             supabase/owner_seat_updates.sql\n"
        "리워드        lib/data/reward_repository.dart, lib/screens/reward_screen.dart\n"
        "             supabase/rewards.sql\n"
        "하단 탭       lib/screens/main_screen.dart"
    )


def main() -> None:
    OUT.parent.mkdir(parents=True, exist_ok=True)
    pdf = GuidePDF()
    build(pdf)
    pdf.output(str(OUT))
    print(f"PDF 생성 완료: {OUT}")


if __name__ == "__main__":
    main()
