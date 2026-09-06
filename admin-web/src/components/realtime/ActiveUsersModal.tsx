import { Modal } from "../Modal";
import { TrendChart } from "../TrendChart";
import { hourlyLabels, lastNDayLabels } from "../../lib/metrics";
import type { RealtimeMetrics } from "../../types/realtimeMetrics";

interface Props {
  metrics: RealtimeMetrics;
  onClose: () => void;
}

export function ActiveUsersModal({ metrics, onClose }: Props) {
  return (
    <Modal title="오늘 활성 사용자" onClose={onClose} wide>
      <TrendChart
        title="오늘 시간대별 활성 사용자"
        labels={hourlyLabels()}
        values={metrics.hourlyActive}
      />
      <div className="two-col mt-8">
        <TrendChart
          title="최근 7일 일별 활성 사용자"
          labels={lastNDayLabels(7)}
          values={metrics.dailyActive7d}
          kind="bar"
        />
        <TrendChart
          title="최근 30일 일별 활성 사용자"
          labels={lastNDayLabels(30)}
          values={metrics.dailyActive30d}
          kind="bar"
        />
      </div>
      <p className="muted sm mt-8">
        오늘 신규 사용자 {metrics.newUsersToday}명 · 기존 사용자{" "}
        {metrics.existingUsersToday}명
      </p>
    </Modal>
  );
}
