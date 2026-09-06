import { Modal } from "../Modal";
import { TrendChart } from "../TrendChart";
import { hourlyLabels, lastNDayLabels } from "../../lib/metrics";
import type { RealtimeMetrics } from "../../types/realtimeMetrics";

interface Props {
  metrics: RealtimeMetrics;
  onClose: () => void;
}

const LEVEL_LABELS: Record<string, string> = {
  normal: "여유로움",
  relaxed: "여유로움",
  full: "혼잡/만석",
  closed: "영업종료",
};

export function ReportsModal({ metrics, onClose }: Props) {
  const total = metrics.reportsUserToday + metrics.reportsOwnerToday;
  const userPct = total > 0 ? Math.round((metrics.reportsUserToday / total) * 100) : 0;
  const ownerPct = total > 0 ? 100 - userPct : 0;

  return (
    <Modal title="제보 현황" onClose={onClose} wide>
      <TrendChart
        title="오늘 시간대별 제보 수"
        labels={hourlyLabels()}
        values={metrics.hourlyReports}
      />
      <div className="two-col mt-8">
        <TrendChart
          title="최근 7일 일별 제보 수"
          labels={lastNDayLabels(7)}
          values={metrics.dailyReports7d}
          kind="bar"
        />
        <TrendChart
          title="최근 30일 일별 제보 수"
          labels={lastNDayLabels(30)}
          values={metrics.dailyReports30d}
          kind="bar"
        />
      </div>

      <p className="muted sm mt-8">
        사용자 제보 {metrics.reportsUserToday}건 ({userPct}%) · 사장님 제보{" "}
        {metrics.reportsOwnerToday}건 ({ownerPct}%)
      </p>

      <div className="panel-head mt-8">
        <h3>혼잡도 상태별 제보 수</h3>
      </div>
      {Object.keys(metrics.reportsByLevel).length === 0 ? (
        <p className="muted center">오늘 제보가 없어요.</p>
      ) : (
        <div className="table-wrap">
          <table className="data-table">
            <thead>
              <tr>
                <th>혼잡도 상태</th>
                <th>제보 수</th>
              </tr>
            </thead>
            <tbody>
              {Object.entries(metrics.reportsByLevel).map(([level, count]) => (
                <tr key={level}>
                  <td>{LEVEL_LABELS[level] ?? level}</td>
                  <td>{count}건</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}

      <div className="panel-head mt-8">
        <h3>매장별 제보 수 TOP 10</h3>
      </div>
      {metrics.topRestaurantsByReports.length === 0 ? (
        <p className="muted center">오늘 제보가 없어요.</p>
      ) : (
        <div className="table-wrap">
          <table className="data-table">
            <thead>
              <tr>
                <th>순위</th>
                <th>매장명</th>
                <th>제보 수</th>
              </tr>
            </thead>
            <tbody>
              {metrics.topRestaurantsByReports.map((row, i) => (
                <tr key={row.restaurantId}>
                  <td>{i + 1}</td>
                  <td>{row.name}</td>
                  <td>{row.count}건</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}
    </Modal>
  );
}
