import type { ReactNode } from "react";
import { Tabs, type AdminTab } from "./Tabs";

interface Props {
  children: ReactNode;
  activeTab: AdminTab;
  onTabChange: (tab: AdminTab) => void;
  onSignOut: () => void;
  onExport?: () => void;
  updatedAt: Date | null;
  onRefresh: () => void;
  refreshing: boolean;
}

export function Layout({
  children,
  activeTab,
  onTabChange,
  onSignOut,
  onExport,
  updatedAt,
  onRefresh,
  refreshing,
}: Props) {
  return (
    <div className="app-shell">
      <header className="topbar">
        <div>
          <p className="eyebrow">Campus Lunch</p>
          <h1>관리자 대시보드</h1>
        </div>
        <div className="topbar-actions">
          {updatedAt && (
            <span className="muted">
              갱신 {updatedAt.toLocaleTimeString("ko-KR")} · 60초 자동
            </span>
          )}
          {onExport && activeTab === "metrics" && (
            <button type="button" className="btn outline" onClick={onExport}>
              지표 내보내기
            </button>
          )}
          <button
            type="button"
            className="btn ghost"
            onClick={onRefresh}
            disabled={refreshing}
          >
            {refreshing ? "불러오는 중…" : "새로고침"}
          </button>
          <button type="button" className="btn ghost" onClick={onSignOut}>
            로그아웃
          </button>
        </div>
      </header>

      <Tabs active={activeTab} onChange={onTabChange} />
      <main>{children}</main>
    </div>
  );
}
