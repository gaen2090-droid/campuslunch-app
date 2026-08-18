#!/usr/bin/env python3
# ignore_for_file: avoid_print
"""캠퍼스런치 법적 문서 PDF 생성 (개인정보처리방침·이용약관·운영정책·리워드·커뮤니티).

사용법:
  python3 tool/generate_legal_docs_pdf.py
"""
from __future__ import annotations

from datetime import date
from pathlib import Path

from fpdf import FPDF
from fpdf.enums import XPos, YPos

ROOT = Path(__file__).resolve().parents[1]
LEGAL_DIR = ROOT / "docs" / "legal"
OUT = ROOT / "docs" / "LEGAL_POLICIES.pdf"
FONT = "/Library/Fonts/Arial Unicode.ttf"
EFFECTIVE = "2026년 7월 9일"
EFFECTIVE_COMMUNITY = "2026년 7월 9일"


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


class LegalPDF(FPDF):
    def __init__(self) -> None:
        super().__init__()
        self.add_font("KR", "", FONT)
        self.set_margins(14, 14, 14)
        self.set_auto_page_break(auto=True, margin=14)

    def _write(
        self,
        text: str,
        *,
        size: float = 9.5,
        h: float = 4.8,
        style: str = "",
        fill: bool = False,
        color: tuple[int, int, int] | None = None,
    ) -> None:
        self.set_x(self.l_margin)
        if color:
            self.set_text_color(*color)
        else:
            self.set_text_color(30, 30, 30)
        self.set_font("KR", style, size)
        if fill:
            self.set_fill_color(243, 248, 240)
        self.multi_cell(
            self.epw,
            h,
            text,
            fill=fill,
            new_x=XPos.LMARGIN,
            new_y=YPos.NEXT,
        )

    def cover(self) -> None:
        self.add_page()
        self.ln(40)
        self._write("캠퍼스런치", size=22, h=10, color=(94, 140, 74))
        self.ln(4)
        self._write("법적 고지 및 운영 정책", size=16, h=8)
        self.ln(8)
        self._write(f"최종 개정일: {EFFECTIVE}", size=11, h=6, color=(107, 114, 128))
        self.ln(12)
        for i, title in enumerate(
            [
                "1. 개인정보 처리방침",
                "2. 이용약관",
                "3. 제보 운영정책",
                "4. 리워드 지급 정책",
                "5. 커뮤니티 이용방침",
            ],
            1,
        ):
            self._write(title, size=12, h=7)
        self.ln(8)
        self._write(
            "문의: hungreez@hungreez.site",
            size=10,
            h=5,
            color=(107, 114, 128),
        )

    def part_title(self, num: int, title: str) -> None:
        self.add_page()
        self.set_fill_color(94, 140, 74)
        self.set_text_color(255, 255, 255)
        self.set_font("KR", "", 14)
        self.set_x(self.l_margin)
        self.cell(self.epw, 10, f"  {num}. {title}", fill=True)
        self.ln(12)
        self.set_text_color(30, 30, 30)

    def h2(self, text: str) -> None:
        self.ln(2)
        self._write(text, size=11.5, h=6, color=(94, 140, 74))

    def h3(self, text: str) -> None:
        self.ln(1)
        self._write(text, size=10.5, h=5.5)

    def body(self, text: str) -> None:
        for paragraph in text.split("\n"):
            if not paragraph.strip():
                self.ln(1.5)
                continue
            for line in _wrap_line(self, paragraph.strip(), self.epw, 9.5):
                self._write(line, size=9.5, h=4.8)

    def bullets(self, items: list[str]) -> None:
        for item in items:
            for i, line in enumerate(_wrap_line(self, item, self.epw - 5, 9.5)):
                prefix = "•  " if i == 0 else "    "
                self._write(prefix + line, size=9.5, h=4.6)

    def note_box(self, text: str) -> None:
        self.ln(1)
        self.set_fill_color(249, 250, 251)
        self.set_draw_color(229, 231, 235)
        y0 = self.get_y()
        self.set_x(self.l_margin)
        self.set_font("KR", "", 9)
        lines: list[str] = []
        for p in text.split("\n"):
            lines.extend(_wrap_line(self, p, self.epw - 8, 9))
        h = max(12, len(lines) * 4.8 + 6)
        self.rect(self.l_margin, y0, self.epw, h, style="DF")
        self.set_xy(self.l_margin + 4, y0 + 3)
        for line in lines:
            self.cell(self.epw - 8, 4.8, line, new_x=XPos.LMARGIN, new_y=YPos.NEXT)
        self.set_y(y0 + h + 2)


def _privacy(pdf: LegalPDF) -> None:
    pdf.part_title(1, "개인정보 처리방침")
    pdf.body(
        "캠퍼스런치(이하 「회사」)는 「개인정보 보호법」 등 관련 법령을 준수하며, "
        "이용자의 개인정보를 보호하기 위해 본 처리방침을 수립·공개합니다."
    )

    pdf.h2("1. 수집하는 개인정보")
    pdf.h3("가. 회원가입·로그인 (필수)")
    pdf.bullets(
        [
            "이메일 주소 — 이메일 가입, Google·카카오 OAuth (Supabase Auth, public.users)",
            "회원 고유 ID — auth.users.id / public.users.id",
            "로그인 수단(provider) — email, google, kakao 등",
            "닉네임 — 가입·프로필 설정, 제보 표시",
            "카카오 회원번호 — 카카오 로그인 시 (kakao_user_id)",
            "프로필 이미지 URL — Google·카카오 제공 시 선택 (avatar_url, 외부 URL)",
        ]
    )
    pdf.h3("나. 서비스 이용 (필수)")
    pdf.bullets(
        [
            "혼잡도 제보 내역 — crowd_reports (상태, 매장 ID, 시각)",
            "제보 시 GPS 좌표·닉네임 — metadata (lat, lng, nickname)",
            "스탬프·리워드 — user_rewards (total_stamps, today_stamps 등)",
            "기프티콘 배정·사용 — gifticons (브랜드, 상품명, 유효기간, 배정 회원)",
            "즐겨찾기 — auth.users user_metadata (bookmarks)",
            "앱 접속·배너·푸시 반응 — analytics_events (app_session, banner_*, push_*)",
            "문의·피드백 — app_feedback (카테고리, 내용)",
        ]
    )
    pdf.h3("다. 기기 권한")
    pdf.bullets(
        [
            "위치(GPS) — 필수 동의. 지도·길찾기·제보 검증 (OS 허용 시)",
            "알림 — 선택. 평일 12:00·18:00 로컬 추천 알림",
        ]
    )
    pdf.note_box(
        "회사는 OS 버전·기기 모델을 별도 DB 컬럼으로 저장하지 않습니다.\n"
        "Supabase·OAuth 제공사 서버 로그에 IP 등이 기록될 수 있습니다."
    )

    pdf.h2("2. 이용 목적")
    pdf.bullets(
        [
            "회원 식별·로그인·계정 관리",
            "혼잡도·웨이팅 정보 제공 및 제보 반영",
            "위치 기반 지도·매장 탐색",
            "스탬프·기프티콘(쿠폰) 리워드",
            "이용 통계·지표 분석 및 서비스 품질·기능 개선",
            "부정 이용 방지, 문의 대응",
        ]
    )

    pdf.h2("3. 보관 기간")
    pdf.bullets(
        [
            "회원·제보·리워드 — 탈퇴 시 지체 없이 삭제 (delete_own_account, cascade)",
            "분석 이벤트 — 통계 목적 달성 후 1년 이내 파기·익명화",
            "피드백 — 처리 완료 후 1년",
            "법령상 보관 — 관련 법령에 따른 기간",
        ]
    )

    pdf.h2("4. 제3자 제공·위탁")
    pdf.body("원칙적으로 판매·임의 제공하지 않습니다. 서비스 제공을 위한 처리 위탁:")
    pdf.bullets(
        [
            "Supabase Inc. — DB·인증·Storage(쿠폰 이미지)",
            "Google LLC — Google 로그인",
            "Kakao Corp. — 카카오 로그인, 카카오맵 SDK",
            "이메일 발송 — Supabase Auth / SMTP(가입 인증)",
        ]
    )
    pdf.note_box(
        "앱이 종료된 상태에서도 알림을 보내기 위해 Firebase Cloud Messaging(FCM)을 "
        "사용합니다. FCM 기기 토큰은 user_push_tokens에 저장되며 로그아웃·탈퇴 시 삭제됩니다. "
        "Firebase Analytics는 사용하지 않습니다."
    )

    pdf.h2("5. 이용자 권리")
    pdf.bullets(["열람·정정·삭제·처리정지", "앱 내 회원 탈퇴"])

    pdf.h2("6. 문의")
    pdf.body("이메일: hungreez@hungreez.site\n앱 내: 문의·피드백")


def _terms(pdf: LegalPDF) -> None:
    pdf.part_title(2, "이용약관")
    sections = [
        (
            "제1조 (목적)",
            "중앙대 인근 식당 혼잡도·제보·리워드·커뮤니티 모바일 서비스 이용에 관한 권리·의무를 규정합니다.",
        ),
        (
            "제2조 (정의)",
            "서비스, 회원, 제보, 스탬프, 기프티콘(쿠폰), 커뮤니티, 커뮤니티 이용방침의 정의를 둡니다.",
        ),
        (
            "제3조 (효력·변경)",
            "회원가입 시 동의로 효력 발생. 변경 시 사전 공지.",
        ),
        (
            "제4조 (회원가입)",
            "이메일·Google·카카오 가입 가능. 최초 가입 전 개인정보·필수 권한 동의 필요. "
            "만 14세 미만 가입 불가.",
        ),
        (
            "제5조 (서비스)",
            "매장 조회, 지도, 제보, 북마크, 스탬프·쿠폰, 로컬 추천 알림, "
            "커뮤니티(자유 게시판·댓글·맛집 컬렉션), 피드백.",
        ),
        (
            "제6조 (혼잡도)",
            "제보·알고리즘 기반 정보로 실시간 정확성 미보증.",
        ),
        (
            "제7조 (회원 의무)",
            "허위·도배 제보, 욕설·광고, 커뮤니티 이용방침 위반, 부정 리워드, 시스템 악용 금지.",
        ),
        (
            "제8조 (리워드)",
            "리워드 지급 정책에 따름. 변경·종료 가능. 위반 시 회수.",
        ),
        (
            "제9조 (게시물)",
            "제보·커뮤니티 게시글·댓글 책임은 회원. 커뮤니티 이용방침 준수. 위반 시 숨김·삭제·신고 검토.",
        ),
        (
            "제10조 (이용 제한)",
            "위반 시 제보·커뮤니티·리워드·계정 제한. 탈퇴 가능.",
        ),
        (
            "제11조 (변경·중단)",
            "운영·기술상 변경·중단 가능, 가능 시 사전 공지.",
        ),
        (
            "제12조 (면책)",
            "제보 정확성 미보증. 불가항력·외부 서비스 장애 등.",
        ),
        (
            "제13조 (지식재산)",
            "서비스 콘텐츠 무단 이용 금지.",
        ),
        (
            "제14조 (준거법)",
            "대한민국 법 적용.",
        ),
    ]
    for title, body in sections:
        pdf.h2(title)
        pdf.body(body)
    pdf.ln(2)
    pdf.body(
        f"부칙 — 본 약관은 2026년 6월 1일부터 시행합니다. "
        f"커뮤니티 관련 조항은 {EFFECTIVE_COMMUNITY}부터 적용합니다."
    )


def _community_policy(pdf: LegalPDF) -> None:
    pdf.part_title(5, "커뮤니티 이용방침")
    pdf.body(
        "커뮤니티 탭(자유 게시판, 댓글, 맛집 컬렉션 등) 이용에 관한 허용·금지 행위, "
        "신고·제재 절차를 정합니다. 이용약관·개인정보 처리방침과 함께 적용됩니다."
    )

    pdf.h2("1. 적용 범위")
    pdf.bullets(
        [
            "자유 게시판: 게시글·댓글·좋아요, 이미지(최대 4장), 등록 매장 연결, 댓글 알림 구독",
            "맛집 컬렉션: 운영자 큐레이션 목록 열람(이용자 직접 작성 불가)",
            "컬렉션 댓글·좋아요(제공 시), 커뮤니티 공지",
        ]
    )

    pdf.h2("2. 금지 행위 (요약)")
    pdf.bullets(
        [
            "욕설·비방·혐오·괴롭힘, 은유·줄임말 포함",
            "홍보·판매·스팸·바이럴 마케팅(맛집 후기 목적 매장 1곳 연결은 예외)",
            "정치·사회 논쟁 유발 게시(맛집·캠퍼스 생활 무관)",
            "개인정보 노출, 불법 촬영물·음란물, 저작권 침해",
            "허위 매장 정보·부정 이용·필터 우회",
        ]
    )
    pdf.note_box(
        "앱은 금칙어 필터 등 1차 자동 검사를 수행할 수 있으며, "
        "통과하더라도 사후 삭제·제재될 수 있습니다."
    )

    pdf.h2("3. 게시물·댓글 운영")
    pdf.bullets(
        [
            "내용 책임은 작성 회원에게 있음",
            "본인 게시글 수정·삭제 가능(앱 제공 범위)",
            "위반·신고 검토 시 숨김(is_hidden)·삭제·표시 제한",
        ]
    )

    pdf.h2("4. 신고 및 모더레이션")
    pdf.bullets(
        [
            "회원은 게시글·댓글 신고 가능",
            "운영자 검토 후 숨김·삭제·이용 제한",
            "중대·반복 위반 시 계정 정지·강제 탈퇴 가능",
            "신고 처리 결과를 개별 통지하지 않을 수 있음",
        ]
    )

    pdf.h2("5. 맛집 컬렉션")
    pdf.bullets(
        [
            "운영자가 선정·편집, 이용자 직접 추가 불가",
            "매장 정보·한줄평은 참고용, 방문 전 직접 확인 필요",
            "컬렉션 댓글·좋아요에도 동일 게시 규정 적용",
        ]
    )

    pdf.h2("6. 알림·개인정보")
    pdf.bullets(
        [
            "게시글 댓글 알림 구독 선택 가능",
            "게시글·댓글에 닉네임 표시, 이미지는 Storage 보관",
            "신고·운영 기록은 부정 이용 방지 목적 보관 가능",
        ]
    )

    pdf.h2("7. 이용 안내·면책")
    pdf.bullets(
        [
            "커뮤니티 탭 최초 진입 시 이용 안내 1회 표시 가능",
            "이용자 게시물의 정확성·신뢰성 미보증",
            "커뮤니티 정보 기반 방문·거래 분쟁 책임 제한(법령 허용 범위)",
        ]
    )

    pdf.h2("8. 방침 변경·문의")
    pdf.body(
        f"개정 시 앱 내 공지 등으로 알립니다. "
        f"문의: hungreez@hungreez.site / 앱 내 문의·피드백\n"
        f"부칙 — 본 방침은 {EFFECTIVE_COMMUNITY}부터 시행합니다."
    )


def _report_policy(pdf: LegalPDF) -> None:
    pdf.part_title(3, "제보 운영정책")
    pdf.h2("허용 제보")
    pdf.bullets(
        [
            "여유로움·약간혼잡·자리없음 (실제 현장 상황)",
            "사장님(매장 owner) 운영·좌석 업데이트",
        ]
    )
    pdf.h2("금지")
    pdf.bullets(
        [
            "허위·원격 제보, 5분 이내 동일 매장 재제보",
            "욕설·비방·광고·스팸, 제한 우회",
        ]
    )
    pdf.h2("기술 기준 (실제 구현)")
    pdf.bullets(
        [
            "로그인 필수 (submit_crowd_report RPC)",
            "이용자 제보에 GPS metadata 저장 가능",
            "서버 5분 쿨다운 검증",
            "사장님 제보는 스탬프 미지급",
        ]
    )
    pdf.h2("운영 조치")
    pdf.bullets(
        [
            "제보 삭제, 스탬프·쿠폰 회수",
            "제보·계정 이용 제한",
        ]
    )


def _reward_policy(pdf: LegalPDF) -> None:
    pdf.part_title(4, "리워드 지급 정책")
    pdf.body(
        "혼잡도 제보 참여에 감사하여 스탬프를 지급하고, "
        "20개 누적 시 운영 재고에 등록된 모바일 기프티콘(쿠폰)을 자동 배정합니다."
    )

    pdf.h2("1. 스탬프 적립")
    pdf.bullets(
        [
            "대상: 이용자 제보(source=user) 정상 등록 시만",
            "영업 세션 내 해당 매장 첫 제보: 2개 / 이후: 1개",
            "일일 한도: KST 기준 서버(grant_stamp) 검증, 운영 중 조정 가능",
            "미지급: 미로그인, 5분 재제보, 거부된 제보, 위반 제보",
        ]
    )

    pdf.h2("2. 쿠폰 지급")
    pdf.bullets(
        [
            "누적 20스탬프 → gifticons 미배정 재고 1장 자동 배정",
            "재고 없음(sold_out): 스탬프 차감 없음",
            "상품: 관리자 등록 재고(브랜드·상품명·유효기간)",
            "유효기간(expires_at) 경과 시 사용 불가",
        ]
    )

    pdf.h2("3. 쿠폰 이용")
    pdf.bullets(
        [
            "앱 쿠폰함에서 이미지·바코드 확인 후 매장 제시",
            "사용 완료 시 mark_gifticon_used 처리",
            "양도·판매·현금 교환 불가",
        ]
    )

    pdf.h2("4. 회수·변경")
    pdf.bullets(
        [
            "허위·부정 적립 시 스탬프·쿠폰 회수",
            "적립률·한도·교환 개수·품목 변경·프로그램 종료 가능 (사전 공지)",
        ]
    )
    pdf.h2("5. 문의")
    pdf.body("hungreez@hungreez.site / 앱 내 문의·피드백")


def main() -> None:
    if not Path(FONT).exists():
        raise SystemExit(f"한글 폰트 없음: {FONT}")

    pdf = LegalPDF()
    pdf.cover()
    _privacy(pdf)
    _terms(pdf)
    _report_policy(pdf)
    _reward_policy(pdf)
    _community_policy(pdf)

    OUT.parent.mkdir(parents=True, exist_ok=True)
    pdf.output(str(OUT))
    print(f"Generated: {OUT} ({OUT.stat().st_size // 1024} KB)")


if __name__ == "__main__":
    main()
