export type AdminTab =
  | "metrics"
  | "kpi"
  | "ops"
  | "restaurants"
  | "popularity"
  | "map_register"
  | "gifticons"
  | "feedback"
  | "community"
  | "community_banned_words"
  | "collections"
  | "users"
  | "nickname_words"
  | "trust_signals"
  | "push"
  | "owner_applications";

interface TabDef {
  id: AdminTab;
  label: string;
}

interface TabGroup {
  id: string;
  label: string;
  tabs: TabDef[];
}

export const TAB_GROUPS: TabGroup[] = [
  {
    id: "dashboard",
    label: "대시보드",
    tabs: [
      { id: "metrics", label: "실시간 지표" },
      { id: "kpi", label: "KPI" },
      { id: "ops", label: "운영 성과" },
    ],
  },
  {
    id: "restaurants",
    label: "매장",
    tabs: [
      { id: "restaurants", label: "전체 매장" },
      { id: "map_register", label: "신규 등록" },
      { id: "popularity", label: "인기 순위" },
      { id: "owner_applications", label: "사장님 인증 심사" },
    ],
  },
  {
    id: "community",
    label: "커뮤니티",
    tabs: [
      { id: "community", label: "신고·게시글 관리" },
      { id: "collections", label: "맛집 컬렉션" },
      { id: "community_banned_words", label: "금칙어 관리" },
    ],
  },
  {
    id: "members",
    label: "회원",
    tabs: [
      { id: "users", label: "회원 관리" },
      { id: "nickname_words", label: "닉네임 금칙어·예약어" },
      { id: "trust_signals", label: "신뢰·어뷰징 지표" },
      { id: "feedback", label: "피드백함" },
    ],
  },
  {
    id: "rewards",
    label: "리워드",
    tabs: [{ id: "gifticons", label: "기프티콘" }],
  },
  {
    id: "settings",
    label: "설정",
    tabs: [{ id: "push", label: "푸시 알림" }],
  },
];

/** 전체 탭 목록 평탄화 (헤더 타이틀 조회 등에 사용) */
export const ADMIN_TABS: TabDef[] = TAB_GROUPS.flatMap((g) => g.tabs);
