import { useState } from "react";
import { MetricCard } from "../components/MetricCard";
import { ActiveUsersModal } from "../components/realtime/ActiveUsersModal";
import { LunchUsersModal } from "../components/realtime/LunchUsersModal";
import { NewSignupsModal } from "../components/realtime/NewSignupsModal";
import { ReportsModal } from "../components/realtime/ReportsModal";
import { ParticipantsModal } from "../components/realtime/ParticipantsModal";
import { CoverageModal } from "../components/realtime/CoverageModal";
import { DetailViewsModal } from "../components/realtime/DetailViewsModal";
import { Top10RestaurantsModal } from "../components/realtime/Top10RestaurantsModal";
import { RestaurantDetailModal } from "../components/realtime/RestaurantDetailModal";
import { formatCount, levelToLabel } from "../lib/metrics";
import type { RealtimeMetrics, Top5RestaurantRow } from "../types/realtimeMetrics";

type ModalKey =
  | "active"
  | "lunch"
  | "signups"
  | "reports"
  | "participants"
  | "coverage"
  | "detailViews"
  | "top10";

interface Props {
  metrics: RealtimeMetrics;
}

function diffPct(current: number, prev: number): string {
  if (prev === 0) return current > 0 ? "+100%" : "0%";
  const pct = Math.round(((current - prev) / prev) * 100);
  return `${pct >= 0 ? "+" : ""}${pct}%`;
}

export function DashboardPage({ metrics }: Props) {
  const [modalKey, setModalKey] = useState<ModalKey | null>(null);
  const [selectedRestaurant, setSelectedRestaurant] =
    useState<Top5RestaurantRow | null>(null);

  const top5 = metrics.top5RestaurantsByReports.slice(0, 5);

  return (
    <div className="dashboard">
      <section className="metric-grid metric-grid--primary">
        <MetricCard
          size="primary"
          label="오늘 활성 사용자"
          value={formatCount(metrics.activeToday)}
          unit={`명 · 전일 ${diffPct(metrics.activeToday, metrics.activeYesterday)}`}
          onClick={() => setModalKey("active")}
        />
        <MetricCard
          size="primary"
          label="점심시간 사용자"
          value={formatCount(metrics.lunchUsersToday)}
          unit={`명 · 전일 ${diffPct(metrics.lunchUsersToday, metrics.lunchUsersYesterday)}`}
          onClick={() => setModalKey("lunch")}
        />
        <MetricCard
          size="primary"
          label="신규 가입자"
          value={formatCount(metrics.newSignupsToday)}
          unit={`명 · 전일 ${diffPct(metrics.newSignupsToday, metrics.newSignupsYesterday)}`}
          onClick={() => setModalKey("signups")}
        />
        <MetricCard
          size="primary"
          label="제보 현황"
          value={formatCount(metrics.reportsToday)}
          unit={`건 · 전일 ${diffPct(metrics.reportsToday, metrics.reportsYesterday)}`}
          onClick={() => setModalKey("reports")}
        />
      </section>
      <p className="muted xs">
        최근 7일 누적 제보 {formatCount(metrics.reportsWeek)}건 · 총 누적 제보{" "}
        {formatCount(metrics.reportsTotal)}건
      </p>

      <section className="metric-grid">
        <MetricCard
          label="오늘 제보 참여자"
          value={formatCount(metrics.participantsToday)}
          unit={`명 · 전일 ${diffPct(metrics.participantsToday, metrics.participantsYesterday)}`}
          onClick={() => setModalKey("participants")}
        />
        <MetricCard
          label="실시간 혼잡도 커버리지"
          value={`${metrics.coverageRestaurantsWithReport} / ${metrics.coverageTotalRestaurants}개`}
          unit={`매장 · ${metrics.coverageRate}%`}
          onClick={() => setModalKey("coverage")}
        />
        <MetricCard
          label="오늘 매장 상세 조회"
          value={formatCount(metrics.detailViewsToday)}
          unit={`건 · 전일 ${diffPct(metrics.detailViewsToday, metrics.detailViewsYesterday)}`}
          onClick={() => setModalKey("detailViews")}
        />
      </section>

      <section className="panel">
        <div className="panel-head">
          <h2>오늘 제보 많은 매장 TOP 5</h2>
          <button type="button" className="btn outline sm" onClick={() => setModalKey("top10")}>
            TOP 10 보기
          </button>
        </div>
        {top5.length === 0 ? (
          <p className="muted center">오늘 제보가 없어요.</p>
        ) : (
          <div className="table-wrap">
            <table className="data-table">
              <thead>
                <tr>
                  <th>순위</th>
                  <th>매장명</th>
                  <th>오늘 제보</th>
                  <th>현재 혼잡도</th>
                  <th>마지막 제보</th>
                </tr>
              </thead>
              <tbody>
                {top5.map((r, i) => (
                  <tr
                    key={r.restaurantId}
                    className="clickable-row"
                    onClick={() => setSelectedRestaurant(r)}
                  >
                    <td>{i + 1}</td>
                    <td>{r.name}</td>
                    <td>{r.todayReports}건</td>
                    <td>{levelToLabel(r.currentLevel)}</td>
                    <td>
                      {r.lastReportAt
                        ? r.lastReportAt.toLocaleString("ko-KR", {
                            month: "numeric",
                            day: "numeric",
                            hour: "2-digit",
                            minute: "2-digit",
                          })
                        : "-"}
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
      </section>

      {modalKey === "active" && (
        <ActiveUsersModal metrics={metrics} onClose={() => setModalKey(null)} />
      )}
      {modalKey === "lunch" && (
        <LunchUsersModal metrics={metrics} onClose={() => setModalKey(null)} />
      )}
      {modalKey === "signups" && (
        <NewSignupsModal metrics={metrics} onClose={() => setModalKey(null)} />
      )}
      {modalKey === "reports" && (
        <ReportsModal metrics={metrics} onClose={() => setModalKey(null)} />
      )}
      {modalKey === "participants" && (
        <ParticipantsModal metrics={metrics} onClose={() => setModalKey(null)} />
      )}
      {modalKey === "coverage" && (
        <CoverageModal metrics={metrics} onClose={() => setModalKey(null)} />
      )}
      {modalKey === "detailViews" && (
        <DetailViewsModal metrics={metrics} onClose={() => setModalKey(null)} />
      )}
      {modalKey === "top10" && (
        <Top10RestaurantsModal
          rows={metrics.top5RestaurantsByReports}
          onClose={() => setModalKey(null)}
        />
      )}
      {selectedRestaurant && (
        <RestaurantDetailModal
          restaurant={selectedRestaurant}
          onClose={() => setSelectedRestaurant(null)}
        />
      )}
    </div>
  );
}
