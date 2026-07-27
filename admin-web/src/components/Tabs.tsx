export type AdminTab =
  | "metrics"
  | "restaurants"
  | "popularity"
  | "map_register"
  | "gifticons"
  | "feedback"
  | "community"
  | "collections"
  | "users"
  | "push"
  | "owner_applications";

export const ADMIN_TABS: { id: AdminTab; label: string }[] = [
  { id: "metrics", label: "핵심 지표" },
  { id: "restaurants", label: "매장 관리" },
  { id: "owner_applications", label: "사장님 인증" },
  { id: "popularity", label: "인기 관리" },
  { id: "map_register", label: "지도 등록" },
  { id: "gifticons", label: "기프티콘" },
  { id: "feedback", label: "피드백" },
  { id: "community", label: "커뮤니티" },
  { id: "collections", label: "맛집 컬렉션" },
  { id: "users", label: "회원 관리" },
  { id: "push", label: "푸시 설정" },
];

interface Props {
  active: AdminTab;
  onChange: (tab: AdminTab) => void;
}

export function Tabs({ active, onChange }: Props) {
  return (
    <nav className="tab-bar" aria-label="관리자 메뉴">
      {ADMIN_TABS.map((tab) => (
        <button
          key={tab.id}
          type="button"
          className={`tab-pill${active === tab.id ? " active" : ""}`}
          onClick={() => onChange(tab.id)}
        >
          {tab.label}
        </button>
      ))}
    </nav>
  );
}
