import { Modal } from "../Modal";
import { TrendChart } from "../TrendChart";
import { formatCount, lastNDayLabels } from "../../lib/metrics";
import type { RealtimeMetrics } from "../../types/realtimeMetrics";

interface Props {
  metrics: RealtimeMetrics;
  onClose: () => void;
}

export function NewSignupsModal({ metrics, onClose }: Props) {
  return (
    <Modal title="신규 가입자" onClose={onClose} wide>
      <div className="two-col">
        <TrendChart
          title="최근 7일 일별 신규 가입자"
          labels={lastNDayLabels(7)}
          values={metrics.dailySignups7d}
          kind="bar"
        />
        <TrendChart
          title="최근 30일 일별 신규 가입자"
          labels={lastNDayLabels(30)}
          values={metrics.dailySignups30d}
          kind="bar"
        />
      </div>
      <p className="muted sm mt-8">
        총 누적 가입자 수: {formatCount(metrics.totalSignups)}명
      </p>
    </Modal>
  );
}
