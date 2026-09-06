import { TAB_GROUPS, type AdminTab } from "./Tabs";

interface Props {
  active: AdminTab;
  onChange: (tab: AdminTab) => void;
}

export function Sidebar({ active, onChange }: Props) {
  return (
    <nav className="sidebar" aria-label="관리자 메뉴">
      <div className="sidebar-brand">
        <p className="sidebar-brand-title">캠퍼스런치</p>
        <p className="sidebar-brand-subtitle">캠퍼스런치 관리자 시트</p>
      </div>

      {TAB_GROUPS.map((group) => (
        <div key={group.id} className="sidebar-group">
          <p className="sidebar-group-label">{group.label}</p>
          {group.tabs.map((tab) => (
            <button
              key={tab.id}
              type="button"
              className={`sidebar-link${active === tab.id ? " active" : ""}`}
              onClick={() => onChange(tab.id)}
            >
              {tab.label}
            </button>
          ))}
        </div>
      ))}
    </nav>
  );
}
