import { Modal } from "../Modal";
import { TrendChart } from "../TrendChart";
import { LUNCH_30MIN_LABELS, lastNDayLabels } from "../../lib/metrics";
import type { RealtimeMetrics } from "../../types/realtimeMetrics";

interface Props {
  metrics: RealtimeMetrics;
  onClose: () => void;
}

export function LunchUsersModal({ metrics, onClose }: Props) {
  const ratio =
    metrics.activeToday > 0
      ? Math.round((metrics.lunchUsersToday / metrics.activeToday) * 100)
      : 0;

  return (
    <Modal title="점심시간 사용자 (11:00~14:00)" onClose={onClose} wide>
      <TrendChart
        title="30분 단위 사용자 수"
        labels={LUNCH_30MIN_LABELS}
        values={metrics.lunch30min}
        kind="bar"
      />
      <div className="two-col mt-8">
        <TrendChart
          title="최근 7일 점심시간 사용자 추이"
          labels={lastNDayLabels(7)}
          values={metrics.lunchDaily7d}
        />
        <TrendChart
          title="최근 30일 점심시간 사용자 추이"
          labels={lastNDayLabels(30)}
          values={metrics.lunchDaily30d}
        />
      </div>
      <p className="muted sm mt-8">
        오늘 전체 활성 사용자 중 점심시간 사용자 비율: {ratio}%
      </p>
    </Modal>
  );
}
