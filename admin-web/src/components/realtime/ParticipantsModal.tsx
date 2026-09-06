import { Modal } from "../Modal";
import { TrendChart } from "../TrendChart";
import { lastNDayLabels } from "../../lib/metrics";
import type { RealtimeMetrics } from "../../types/realtimeMetrics";

interface Props {
  metrics: RealtimeMetrics;
  onClose: () => void;
}

export function ParticipantsModal({ metrics, onClose }: Props) {
  return (
    <Modal title="오늘 제보 참여자" onClose={onClose} wide>
      <div className="two-col">
        <TrendChart
          title="최근 7일 일별 제보 참여자 수"
          labels={lastNDayLabels(7)}
          values={metrics.dailyParticipants7d}
          kind="bar"
        />
        <TrendChart
          title="최근 30일 일별 제보 참여자 수"
          labels={lastNDayLabels(30)}
          values={metrics.dailyParticipants30d}
          kind="bar"
        />
      </div>

      <p className="muted sm mt-8">
        오늘 참여자 1인당 평균 제보 수: {metrics.avgReportsPerParticipant}건
      </p>

      <div className="panel-head mt-8">
        <h3>오늘 제보 횟수 분포</h3>
      </div>
      <div className="table-wrap">
        <table className="data-table">
          <thead>
            <tr>
              <th>제보 횟수</th>
              <th>사용자 수</th>
            </tr>
          </thead>
          <tbody>
            <tr>
              <td>1회</td>
              <td>{metrics.participantDist1}명</td>
            </tr>
            <tr>
              <td>2회</td>
              <td>{metrics.participantDist2}명</td>
            </tr>
            <tr>
              <td>3회 이상</td>
              <td>{metrics.participantDist3plus}명</td>
            </tr>
          </tbody>
        </table>
      </div>

      <p className="muted sm mt-8">
        최근 7일 기준 재제보 사용자 비율: {metrics.repeatReporterRate}%
      </p>
    </Modal>
  );
}
