import { Modal } from "../Modal";
import type { RealtimeMetrics, CoverageRestaurantRow } from "../../types/realtimeMetrics";

interface Props {
  metrics: RealtimeMetrics;
  onClose: () => void;
}

function formatLastReport(d: Date | null): string {
  if (!d) return "-";
  return d.toLocaleString("ko-KR", { month: "numeric", day: "numeric", hour: "2-digit", minute: "2-digit" });
}

function CoveredTable({ rows }: { rows: CoverageRestaurantRow[] }) {
  if (rows.length === 0) {
    return <p className="muted center">해당하는 매장이 없어요.</p>;
  }
  return (
    <div className="table-wrap">
      <table className="data-table">
        <thead>
          <tr>
            <th>매장명</th>
            <th>마지막 제보</th>
          </tr>
        </thead>
        <tbody>
          {rows.map((r) => (
            <tr key={r.restaurantId}>
              <td>{r.name}</td>
              <td>{formatLastReport(r.lastReportAt)}</td>
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );
}

function UncoveredTable({ rows }: { rows: CoverageRestaurantRow[] }) {
  if (rows.length === 0) {
    return <p className="muted center">해당하는 매장이 없어요.</p>;
  }
  return (
    <div className="table-wrap">
      <table className="data-table">
        <thead>
          <tr>
            <th>매장명</th>
          </tr>
        </thead>
        <tbody>
          {rows.map((r) => (
            <tr key={r.restaurantId}>
              <td>{r.name}</td>
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );
}

export function CoverageModal({ metrics, onClose }: Props) {
  return (
    <Modal title="실시간 혼잡도 커버리지" onClose={onClose} wide>
      <p className="muted sm">
        운영 대상 {metrics.coverageTotalRestaurants}개 매장 중 최근 15분 이내 제보가 있는
        매장 {metrics.coverageRestaurantsWithReport}개 ({metrics.coverageRate}%)
      </p>

      <div className="two-col mt-8">
        <div>
          <div className="panel-head">
            <h3>최신 제보 있는 매장 ({metrics.coveredRestaurants.length})</h3>
          </div>
          <CoveredTable rows={metrics.coveredRestaurants} />
        </div>
        <div>
          <div className="panel-head">
            <h3>최신 제보 없는 매장 ({metrics.uncoveredRestaurants.length})</h3>
          </div>
          <UncoveredTable rows={metrics.uncoveredRestaurants} />
        </div>
      </div>
    </Modal>
  );
}
