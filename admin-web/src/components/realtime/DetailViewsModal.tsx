import { Modal } from "../Modal";
import { TrendChart } from "../TrendChart";
import { hourlyLabels, lastNDayLabels } from "../../lib/metrics";
import type { RealtimeMetrics } from "../../types/realtimeMetrics";

interface Props {
  metrics: RealtimeMetrics;
  onClose: () => void;
}

export function DetailViewsModal({ metrics, onClose }: Props) {
  return (
    <Modal title="오늘 매장 상세 조회" onClose={onClose} wide>
      <TrendChart
        title="오늘 시간대별 상세 조회 수"
        labels={hourlyLabels()}
        values={metrics.hourlyDetailViews}
      />
      <div className="two-col mt-8">
        <TrendChart
          title="최근 7일 일별 조회 수"
          labels={lastNDayLabels(7)}
          values={metrics.dailyDetailViews7d}
          kind="bar"
        />
        <TrendChart
          title="최근 30일 일별 조회 수"
          labels={lastNDayLabels(30)}
          values={metrics.dailyDetailViews30d}
          kind="bar"
        />
      </div>

      <div className="panel-head mt-8">
        <h3>조회 수 많은 매장 TOP 10</h3>
      </div>
      {metrics.topRestaurantsByViews.length === 0 ? (
        <p className="muted center">오늘 조회가 없어요.</p>
      ) : (
        <div className="table-wrap">
          <table className="data-table">
            <thead>
              <tr>
                <th>순위</th>
                <th>매장명</th>
                <th>조회 수</th>
              </tr>
            </thead>
            <tbody>
              {metrics.topRestaurantsByViews.map((row, i) => (
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
