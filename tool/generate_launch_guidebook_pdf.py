#!/usr/bin/env python3
"""캠퍼스런치 앱 출시 가이드북 PDF 생성.

사용법:
  python3 tool/generate_launch_guidebook_pdf.py
"""
from __future__ import annotations

from pathlib import Path

from fpdf import FPDF
from fpdf.enums import XPos, YPos

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "docs" / "LAUNCH_GUIDEBOOK.pdf"
FONT = "/Library/Fonts/Arial Unicode.ttf"

# 프로젝트 정본 (비밀값 제외)
PACKAGE = "com.campuslunch.app"
SUPABASE_REF = "vkacsvoknnlmcyplprft"
AUTH_CALLBACK = f"https://{SUPABASE_REF}.supabase.co/auth/v1/callback"
APP_SCHEME = "campuslunch://login-callback"
CONTACT = "hungreez@hungreez.site"


def _wrap_line(pdf: FPDF, text: str, width: float, size: float) -> list[str]:
    pdf.set_font("KR", "", size)
    if not text:
        return [""]
    if pdf.get_string_width(text) <= width:
        return [text]
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
        self.set_margins(14, 16, 14)
        self.set_auto_page_break(auto=True, margin=16)

    def footer(self) -> None:
        self.set_y(-12)
        self.set_font("KR", "", 8)
        self.set_text_color(156, 163, 175)
        self.cell(0, 8, f"캠퍼스런치 출시 가이드북  ·  {self.page_no()}", align="C")

    def _write(
        self,
        text: str,
        *,
        size: float = 9.5,
        h: float = 4.8,
        color: tuple[int, int, int] | None = None,
    ) -> None:
        self.set_x(self.l_margin)
        self.set_text_color(*(color or (30, 30, 30)))
        self.set_font("KR", "", size)
        self.cell(self.epw, h, text, new_x=XPos.LMARGIN, new_y=YPos.NEXT)

    def cover(self) -> None:
        self.add_page()
        self.ln(28)
        self.set_fill_color(94, 140, 74)
        self.rect(14, 40, self.epw, 8, style="F")
        self.ln(20)
        self._write("캠퍼스런치", size=28, h=12, color=(94, 140, 74))
        self._write("앱 출시 가이드북", size=20, h=10)
        self.ln(6)
        self._write(
            "스토어 심사 · Supabase · OAuth · 도메인 · App Links까지",
            size=11,
            h=6,
            color=(107, 114, 128),
        )
        self._write(
            "프로젝트 코드·docs 기준으로 정리한 실무 체크리스트",
            size=11,
            h=6,
            color=(107, 114, 128),
        )
        self.ln(16)
        for line in [
            f"패키지 / Bundle ID: {PACKAGE}",
            f"문의: {CONTACT}",
            "관련 문서: docs/DEPLOY_SUPABASE_CHECKLIST.md,",
            "  PRODUCTION_SETUP.md, EMAIL_OTP_SETUP.md, SMTP_SETUP.md,",
            "  KAKAO_SUPABASE_SETUP.md, GOOGLE_SUPABASE_SETUP.md,",
            "  DEPLOY_AUTH_WEB.md, LEGAL_POLICIES.pdf",
        ]:
            self._write(line, size=9.5, h=5, color=(75, 85, 99))
        self.ln(20)
        self.note_box(
            "이 문서는 비밀키·토큰 값을 포함하지 않습니다.\n"
            "실제 키는 .env / android/keys.properties / ios Secrets.xcconfig 를 사용하세요."
        )

    def chapter(self, num: int, title: str) -> None:
        self.add_page()
        self.set_fill_color(94, 140, 74)
        self.set_text_color(255, 255, 255)
        self.set_font("KR", "", 13)
        self.set_x(self.l_margin)
        self.cell(self.epw, 10, f"  {num}. {title}", fill=True)
        self.ln(12)
        self.set_text_color(30, 30, 30)

    def h2(self, text: str) -> None:
        self.ln(3)
        self._write(text, size=11.5, h=6, color=(94, 140, 74))

    def h3(self, text: str) -> None:
        self.ln(1)
        self._write(text, size=10.5, h=5.5, color=(55, 65, 81))

    def body(self, text: str) -> None:
        for paragraph in text.split("\n"):
            if not paragraph.strip():
                self.ln(1.5)
                continue
            for line in _wrap_line(self, paragraph.strip(), self.epw, 9.5):
                self._write(line, size=9.5, h=4.8)

    def bullets(self, items: list[str], *, checkbox: bool = False) -> None:
        prefix0 = "☐  " if checkbox else "•  "
        indent = "    " if checkbox else "    "
        for item in items:
            for i, line in enumerate(_wrap_line(self, item, self.epw - 6, 9.5)):
                prefix = prefix0 if i == 0 else indent
                self._write(prefix + line, size=9.5, h=4.7)

    def numbered(self, items: list[str]) -> None:
        for n, item in enumerate(items, 1):
            for i, line in enumerate(_wrap_line(self, item, self.epw - 8, 9.5)):
                prefix = f"{n}. " if i == 0 else "   "
                self._write(prefix + line, size=9.5, h=4.7)

    def note_box(self, text: str) -> None:
        self.ln(1)
        self.set_fill_color(243, 248, 240)
        self.set_draw_color(218, 255, 202)
        y0 = self.get_y()
        self.set_x(self.l_margin)
        self.set_font("KR", "", 9)
        lines: list[str] = []
        for p in text.split("\n"):
            lines.extend(_wrap_line(self, p, self.epw - 8, 9))
        h = max(12, len(lines) * 4.8 + 6)
        if y0 + h > self.h - self.b_margin:
            self.add_page()
            y0 = self.get_y()
        self.rect(self.l_margin, y0, self.epw, h, style="DF")
        self.set_xy(self.l_margin + 4, y0 + 3)
        for line in lines:
            self.set_text_color(55, 65, 81)
            self.cell(self.epw - 8, 4.8, line, new_x=XPos.LMARGIN, new_y=YPos.NEXT)
            self.set_x(self.l_margin + 4)
        self.set_y(y0 + h + 2)
        self.set_text_color(30, 30, 30)

    def warn_box(self, text: str) -> None:
        self.ln(1)
        self.set_fill_color(254, 242, 242)
        self.set_draw_color(252, 165, 165)
        y0 = self.get_y()
        lines: list[str] = []
        for p in text.split("\n"):
            lines.extend(_wrap_line(self, p, self.epw - 8, 9))
        h = max(12, len(lines) * 4.8 + 6)
        if y0 + h > self.h - self.b_margin:
            self.add_page()
            y0 = self.get_y()
        self.rect(self.l_margin, y0, self.epw, h, style="DF")
        self.set_xy(self.l_margin + 4, y0 + 3)
        for line in lines:
            self.set_text_color(127, 29, 29)
            self.cell(self.epw - 8, 4.8, line, new_x=XPos.LMARGIN, new_y=YPos.NEXT)
            self.set_x(self.l_margin + 4)
        self.set_y(y0 + h + 2)
        self.set_text_color(30, 30, 30)

    def code_line(self, text: str) -> None:
        self.set_fill_color(249, 250, 251)
        self.set_font("KR", "", 8.5)
        self.set_text_color(31, 41, 55)
        for line in _wrap_line(self, text, self.epw - 6, 8.5):
            self.set_x(self.l_margin)
            self.cell(self.epw, 5, f"  {line}", fill=True, new_x=XPos.LMARGIN, new_y=YPos.NEXT)
        self.set_text_color(30, 30, 30)
        self.ln(1)


def build() -> None:
    pdf = GuidePDF()
    pdf.cover()

    # ── 1. 로드맵 ──
    pdf.chapter(1, "출시 로드맵 (타임라인)")
    pdf.body(
        "아래는 권장 순서입니다. 앞 단계를 건너뛰면 스토어 심사·로그인·메일에서 "
        "막히는 경우가 많습니다."
    )
    pdf.h2("Week 0 — 기반 (1~2일)")
    pdf.numbered(
        [
            "Supabase 보안 SQL·RLS 최종 적용 (deploy_prelaunch_security.sql)",
            "스탬프 일일 한도 999 → 운영값으로 변경 후 SQL 재적용",
            "Resend 도메인 인증 + Supabase SMTP 연동",
            "이메일 OTP 템플릿(Magic Link) 적용",
            "관리자 계정 role=admin SQL 부여",
        ]
    )
    pdf.h2("Week 1 — 인증·키 (1~2일)")
    pdf.numbered(
        [
            "카카오: 릴리스 키 해시 / Bundle ID / OpenID / Supabase Provider",
            "Google: 릴리스 SHA-1·iOS Client ID / Supabase Web Client ID",
            "dart run tool/sync_env_to_native.dart 후 릴리스 빌드 테스트",
            "이메일·카카오·Google 가입/로그인/탈퇴 E2E",
        ]
    )
    pdf.h2("Week 2 — 스토어 준비 (2~3일)")
    pdf.numbered(
        [
            "Android: key.properties + 릴리스 keystore, appbundle 빌드",
            "iOS: Apple Developer 계정, 인증서·프로비저닝, Archive",
            "개인정보처리방침 URL 공개 (웹 또는 PDF 호스팅)",
            "스크린샷·설명·연령등급·Data safety / Privacy labels",
            "Play Console / App Store Connect 앱 등록",
        ]
    )
    pdf.h2("Week 3 — 제출·심사")
    pdf.numbered(
        [
            "내부 테스트(Play) / TestFlight(iOS)로 릴리스 빌드 검증",
            "심사 제출 + 리뷰어 계정·메모 준비",
            "반려 시 수정 → 재제출",
            "승인 후: 공유 링크·웹 폴백에 스토어 URL 반영 (선택, 핫픽스)",
        ]
    )
    pdf.note_box(
        "스토어 공개 링크는 심사·등록 후에야 생깁니다.\n"
        "App Links용 https 도메인은 심사 전에 미리 준비할 수 있습니다.\n"
        "공유 URL의 example.com 은 심사 전에도 제거하거나 텍스트만 공유하세요."
    )

    # ── 2. 마스터 체크리스트 ──
    pdf.chapter(2, "해야 할 일 체크박스 (마스터)")
    pdf.h2("백엔드 · 보안")
    pdf.bullets(
        [
            "deploy_prelaunch_security.sql Dashboard 실행 완료",
            "users_nickname_unique.sql 등 미적용 SQL 확인",
            "스탬프 일일 한도 운영값 반영 (현재 코드/SQL은 999=디버그)",
            "앱에 anon(publishable) 키만 포함, service_role 미포함",
            "Storage gifticons 버킷 private + policy",
            "관리자: update public.users set role='admin' where email=...",
        ],
        checkbox=True,
    )
    pdf.h2("인증 · 메일")
    pdf.bullets(
        [
            "Supabase Site URL / Redirect = campuslunch://login-callback",
            "이메일 Confirm email ON + Magic Link OTP 템플릿",
            "Resend SMTP 연동 (실서비스 도메인 발신)",
            "카카오 Provider = 네이티브 앱 키, OpenID Connect ON",
            "Google Provider = 웹 Client ID",
            "Android 릴리스 SHA-1 / 카카오 릴리스 키 해시 등록",
        ],
        checkbox=True,
    )
    pdf.h2("앱 빌드 · 스토어")
    pdf.bullets(
        [
            "dart run tool/sync_env_to_native.dart",
            "flutter build appbundle (Play)",
            "flutter build ipa / Xcode Archive (App Store)",
            "android/key.properties + 릴리스 keystore",
            "개인정보처리방침 URL (스토어 필수)",
            "Play Data safety / Apple Privacy labels",
            "스크린샷·스토어 설명·문의 메일",
        ],
        checkbox=True,
    )
    pdf.h2("콘텐츠 · 운영")
    pdf.bullets(
        [
            "매장 데이터 등록 완료",
            "기프티콘 재고 등록 (admin / CSV)",
            "권한 안내 → 로그인 → 약관 → 메인 플로우 릴리스 빌드 검증",
            "제보·스탬프·쿠폰·사장님 코드·탈퇴 테스트",
            "공유 링크 example.com 제거 또는 도메인/텍스트만",
        ],
        checkbox=True,
    )

    # ── 3. 스토어 등록 순서 ──
    pdf.chapter(3, "App Store / Play Console 등록 순서")
    pdf.h2("공통 준비물")
    pdf.bullets(
        [
            f"앱 이름: 캠퍼스런치 / 패키지: {PACKAGE}",
            f"문의: {CONTACT}",
            "아이콘, 스크린샷 (폰 기준 각 스토어 규격)",
            "개인정보처리방침 URL (docs/LEGAL_POLICIES.pdf 또는 웹)",
            "짧은 설명 / 긴 설명 / 키워드",
        ]
    )
    pdf.h2("Google Play Console")
    pdf.numbered(
        [
            "play.google.com/console 개발자 계정 (1회 등록비)",
            "앱 만들기 → 앱 이름·기본 언어·무료/유료",
            "패키지명 com.campuslunch.app (최초 업로드 시 확정)",
            "설정 → 앱 서명: Play App Signing 사용 권장",
            "프로덕션/내부 테스트 트랙에 AAB 업로드 "
            "(flutter build appbundle → build/app/outputs/bundle/release/)",
            "스토어 설정: 설명, 그래픽, 카테고리, 연락처",
            "앱 콘텐츠: 개인정보처리방침 URL, Data safety "
            "(위치·계정·앱 활동 등 수집 항목을 방침과 일치)",
            "콘텐츠 등급 설문 완료",
            "국가/지역, 가격(무료)",
            "내부 테스트 → 닫힌/공개 테스트(선택) → 프로덕션 제출",
        ]
    )
    pdf.note_box(
        "Play는 내부 테스트 트랙에 먼저 올리면 심사 전에 릴리스 서명 빌드를 "
        "실기기로 검증할 수 있습니다."
    )
    pdf.h2("Apple App Store Connect")
    pdf.numbered(
        [
            "developer.apple.com 유료 멤버십",
            "Certificates, Identifiers & Profiles: App ID = com.campuslunch.app",
            "Capabilities: Associated Domains(앱 링크 시), Sign in with Apple은 "
            "미사용이면 불필요",
            "Xcode: Team 선택, Release 서명, Product → Archive",
            "Organizer → Distribute App → App Store Connect",
            "appstoreconnect.apple.com 에서 앱 생성 (번들 ID 연결)",
            "버전 정보: 스크린샷, 설명, 키워드, 지원 URL, 마케팅 URL(선택)",
            "App Privacy: 수집 데이터 유형 선언 (위치, 연락처 정보 등)",
            "연령 등급, 암호화(ITSAppUsesNonExemptEncryption — HTTPS만이면 보통 No)",
            "TestFlight 내부 테스트 후 「심사 제출」",
            "심사 메모: 테스트 계정(이메일/비번), 위치 권한 필요 이유, "
            "중앙대 인근 혼잡도 앱 설명",
        ]
    )
    pdf.warn_box(
        "iPhone + flutter run 에서 뜨는 「로컬 네트워크」팝업은 디버그 연결용입니다.\n"
        "릴리스/TestFlight 빌드에서는 Flutter 디버거가 없어 시작 시 뜨지 않습니다."
    )

    # ── 4. Supabase ──
    pdf.chapter(4, "Supabase 점검")
    pdf.h2("필수 SQL (배포 전)")
    pdf.body("docs/DEPLOY_SUPABASE_CHECKLIST.md 기준:")
    pdf.bullets(
        [
            "기존 스키마(schema 1~14 등) 적용된 상태인지 확인",
            "supabase/deploy_prelaunch_security.sql 실행",
            "push_analytics.sql 의 admin_dashboard_metrics 구간 반영",
            "supabase/users_nickname_unique.sql (미실행 시)",
        ],
        checkbox=True,
    )
    pdf.h2("보안 패치가 막는 것")
    pdf.bullets(
        [
            "JWT user_metadata.role 로 admin 자가 승격",
            "grant_stamp 직접 호출로 스탬프 조작",
            "user_rewards 직접 UPDATE",
            "admin_dashboard_metrics anon 유출",
            "가입 시 metadata role=admin 반영",
            "app_feedback RLS 부재",
        ]
    )
    pdf.h2("Dashboard 수동 확인")
    pdf.bullets(
        [
            "Authentication → Providers: Email, Kakao, Google ON",
            "URL Configuration: Site URL = campuslunch://login-callback",
            "Redirect URLs에 campuslunch://login-callback 및 /**",
            "localhost 리다이렉트는 프로덕션에서 제거 권장",
            "API: 앱에는 anon 키만",
            "Storage: gifticons private",
            "Authentication → Users: 관리자 존재 + public.users.role=admin",
        ],
        checkbox=True,
    )
    pdf.h2("스탬프 한도 (출시 차단 이슈)")
    pdf.warn_box(
        "현재 grant_stamp 일일 상한이 999(디버깅용)입니다.\n"
        "rewards.sql / deploy_prelaunch_security.sql 을 운영 한도(예: 3~10)로 "
        "수정한 뒤 Dashboard에서 다시 실행하세요."
    )
    pdf.h2("관리자 부여 SQL")
    pdf.code_line(
        "update public.users set role = 'admin' where email = 'your-admin@example.com';"
    )
    pdf.note_box(
        "앱의 admin/admin123, user/user123, owner/owner123 은 kDebugMode 전용입니다.\n"
        "릴리스 빌드에는 포함되지 않으며 DB 권한이 없습니다."
    )

    # ── 5. 카카오/구글 ──
    pdf.chapter(5, "카카오 / 구글 로그인 최종 체크")
    pdf.h2("공통")
    pdf.bullets(
        [
            ".env 수정 후: dart run tool/sync_env_to_native.dart",
            "그다음 flutter clean && 릴리스 빌드 (키 미동기화 시 OAuth 실패)",
            f"패키지/번들: {PACKAGE}",
            f"Supabase Auth callback: {AUTH_CALLBACK}",
        ],
        checkbox=True,
    )
    pdf.h2("카카오 (developers.kakao.com)")
    pdf.bullets(
        [
            "네이티브 앱 키 = .env KAKAO_NATIVE_APP_KEY = Supabase Kakao Provider 키",
            "OpenID Connect 활성화 (ID 토큰)",
            f"Redirect URI: {AUTH_CALLBACK}",
            "Android 패키지 com.campuslunch.app + 키 해시(디버그·릴리스 둘 다)",
            "iOS Bundle ID com.campuslunch.app",
            "동의항목: 닉네임, 프로필(선택)",
        ],
        checkbox=True,
    )
    pdf.h3("릴리스 키 해시 확인")
    pdf.code_line("dart run tool/print_kakao_android_key_hash.dart --release")
    pdf.note_box(
        "Supabase Kakao 칸 이름이 REST API Key여도 Flutter 네이티브 로그인은 "
        "네이티브 앱 키를 넣어야 합니다. REST만 넣으면 Unacceptable audience 오류."
    )
    pdf.h2("Google (Google Cloud Console)")
    pdf.bullets(
        [
            "OAuth 클라이언트 3종: Android / iOS / Web",
            "Supabase Google Provider Client ID = 웹 Client ID",
            ".env GOOGLE_OAUTH_WEB_CLIENT_ID = 웹 Client ID",
            ".env GOOGLE_OAUTH_IOS_CLIENT_ID = iOS Client ID",
            "Android 클라이언트에 디버그 SHA-1 + 릴리스 SHA-1",
            "Play App Signing 사용 시 Play Console의 앱 서명 SHA-1도 등록",
        ],
        checkbox=True,
    )
    pdf.h3("SHA-1 확인")
    pdf.code_line("cd android && ./gradlew :app:signingReport")
    pdf.h2("릴리스 빌드 스모크 테스트")
    pdf.bullets(
        [
            "이메일 가입 → OTP 6자리 → 약관 동의 → 메인",
            "카카오 신규/기존 로그인",
            "Google 신규/기존 로그인",
            "로그아웃 후 재로그인",
            "회원 탈퇴",
        ],
        checkbox=True,
    )

    # ── 6. 도메인 / Resend ──
    pdf.chapter(6, "도메인 / Resend 설정")
    pdf.h2("왜 필요한가")
    pdf.body(
        "Supabase 기본 메일은 시간당 약 2통이라 실서비스에 부족합니다. "
        "Resend SMTP를 쓰면 한도가 크게 늘어나고, 발신 주소도 브랜드 도메인으로 "
        "맞출 수 있습니다."
    )
    pdf.h2("테스트만 (도메인 없음)")
    pdf.numbered(
        [
            "resend.com 가입 → API Key 발급",
            ".env.secrets 에 RESEND_API_KEY, SMTP_ADMIN_EMAIL=onboarding@resend.dev",
            "dart run tool/setup_supabase_smtp.dart",
            "수신은 Resend 가입 메일로 제한될 수 있음",
        ]
    )
    pdf.h2("실서비스 (도메인 권장)")
    pdf.bullets(
        [
            "도메인 구매 (예: campuslunch.app)",
            "Resend → Domains → 도메인 추가 → DNS(TXT/MX/CNAME) 인증",
            "SMTP_ADMIN_EMAIL=noreply@내도메인.com",
            "dart run tool/setup_supabase_smtp.dart",
            "가입 메일 From 이 브랜드 주소인지 확인",
        ],
        checkbox=True,
    )
    pdf.h2("이메일 OTP 템플릿")
    pdf.bullets(
        [
            "Supabase Access Token → .env.secrets SUPABASE_ACCESS_TOKEN",
            "dart run tool/apply_supabase_email_templates.dart",
            "또는 Dashboard → Email Templates → Magic Link 에 {{ .Token }} 6자리",
            "메일에 링크만 오면 템플릿 미적용 — Magic Link 템플릿을 고쳐야 함",
        ],
        checkbox=True,
    )
    pdf.h2("개인정보처리방침 URL (스토어 필수)")
    pdf.bullets(
        [
            "같은 도메인에 /privacy 페이지 또는 LEGAL_POLICIES.pdf 호스팅",
            "Play / App Store 메타데이터에 URL 입력",
            "앱 내 약관 전문은 assets/legal/*.md (회원가입 동의 화면)",
        ],
        checkbox=True,
    )

    # ── 7. App Links & Redirect ──
    pdf.chapter(7, "App Links & Redirect URL")
    pdf.h2("지금 앱에 있는 것")
    pdf.bullets(
        [
            f"인증 딥링크(커스텀 스킴): {APP_SCHEME}",
            "공유 URL: lib/widgets/share_sheet.dart 의 example.com (출시 전 교체/제거)",
        ]
    )
    pdf.h2("Supabase Redirect (필수)")
    pdf.body("Authentication → URL Configuration")
    pdf.bullets(
        [
            f"Site URL: {APP_SCHEME}",
            f"Redirect URLs: {APP_SCHEME}",
            f"Redirect URLs: {APP_SCHEME}/**",
            f"OAuth callback(자동): {AUTH_CALLBACK}",
        ]
    )
    pdf.code_line(".env 에 AUTH_REDIRECT_URL=campuslunch://login-callback (선택, 기본값과 동일)")
    pdf.h2("https App Links (선택, 심사 전에도 가능)")
    pdf.body(
        "스토어 링크와 다릅니다. 본인 도메인으로 앱 특정 화면을 엽니다. "
        "스토어 URL은 심사 후에 생깁니다."
    )
    pdf.h3("서버에 올릴 파일")
    pdf.bullets(
        [
            "Android: https://내도메인/.well-known/assetlinks.json "
            "(package_name + 릴리스 SHA-256)",
            "iOS: https://내도메인/.well-known/apple-app-site-association "
            "(TEAMID.com.campuslunch.app, paths)",
        ]
    )
    pdf.h3("앱 설정")
    pdf.bullets(
        [
            "AndroidManifest: https intent-filter autoVerify=true",
            "iOS: Associated Domains → applinks:내도메인",
            "Flutter: app_links 등으로 URI → 상세 화면 라우팅",
            "share_sheet _shareBaseUrl 을 https://내도메인/restaurant 로 변경",
        ]
    )
    pdf.h3("앱 미설치 시")
    pdf.body(
        "같은 URL을 웹에서 열면 랜딩 페이지를 보여 주고, "
        "심사 통과 후 App Store / Play 버튼을 넣으면 됩니다."
    )
    pdf.note_box(
        "첫 출시 최소안: 공유에서 링크를 빼거나 텍스트만 공유 → "
        "승인 후 1.0.1에서 스토어/앱 링크 반영."
    )

    # ── 8. 심사 대응 ──
    pdf.chapter(8, "심사 대응 체크리스트")
    pdf.h2("제출 직전")
    pdf.bullets(
        [
            "릴리스 빌드(디버그 아님)로 전체 플로우 통과",
            "크래시·흰 화면·로그인 실패 없음",
            "위치 권한: 안내 화면 후 OS 팝업 (필수 거부 시 앱 사용 제한 UI)",
            "약관·개인정보: 앱 내 전문 보기 동작",
            "만 14세 미만 가입 불가 등 약관과 스토어 연령 일치",
            "테스트 계정(이메일/비밀번호) 심사 메모에 기재",
            "위치 권한이 필요한 이유 한 줄 설명",
        ],
        checkbox=True,
    )
    pdf.h2("리뷰어에게 적을 내용 예시")
    pdf.body(
        "캠퍼스런치는 중앙대학교 인근 식당 혼잡도를 제보·조회하는 앱입니다. "
        "위치는 지도·제보 검증에 사용합니다. "
        "테스트 계정: (이메일) / (비밀번호). "
        "로그인 → 홈에서 매장 목록 확인 → 상세에서 제보 가능."
    )
    pdf.h2("자주 반려되는 포인트")
    pdf.bullets(
        [
            "개인정보처리방침 URL 없음/접속 불가",
            "로그인만 되고 핵심 기능 테스트 불가 (계정·데이터 없음)",
            "권한 사용 목적과 실제 기능 불일치",
            "깨진 링크(example.com) 공유",
            "크래시, Placeholder 텍스트, 미완성 화면",
            "구독/결제 미구현인데 결제 UI만 있는 경우(해당 없음이면 OK)",
        ]
    )
    pdf.h2("승인 후")
    pdf.bullets(
        [
            "스토어 URL 확보",
            "웹 랜딩·공유 링크·마케팅 채널에 반영",
            "App Links 폴백 페이지에 스토어 버튼",
            "크래시·리뷰 모니터링",
            "핫픽스 시 versionCode / CFBundleVersion 증가",
        ],
        checkbox=True,
    )
    pdf.h2("빌드 명령 요약")
    pdf.code_line("dart run tool/sync_env_to_native.dart")
    pdf.code_line("flutter build appbundle")
    pdf.code_line("flutter build ipa")
    pdf.ln(4)
    pdf.note_box(
        "문의: hungreez@hungreez.site\n"
        "상세 설정은 docs/ 하위 개별 가이드를 함께 보세요.\n"
        "이 가이드북 재생성: python3 tool/generate_launch_guidebook_pdf.py"
    )

    OUT.parent.mkdir(parents=True, exist_ok=True)
    pdf.output(OUT)
    print(f"Generated: {OUT} ({OUT.stat().st_size // 1024} KB)")


if __name__ == "__main__":
    build()
