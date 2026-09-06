import { useState } from "react";
import { ActiveUsersTrendCard } from "../components/ActiveUsersTrendCard";
import { KpiGoalModal } from "../components/KpiGoalModal";
import { MetricCard } from "../components/MetricCard";
import { Modal } from "../components/Modal";
import { ProgressBar } from "../components/ProgressBar";
import { RestaurantBarList } from "../components/RestaurantBarList";
import { TrendChart } from "../components/TrendChart";
import { formatCount, last8WeekLabels, thisMonthDayLabels } from "../lib/metrics";
import type { AdminRestaurant } from "../types/restaurant";
import type { AdminUser } from "../types/user";
import type { OwnerApplication } from "../types/ownerApplication";
import type { KpiMetricsV2 } from "../types/kpiMetrics";
import {
  KPI_METRIC_LABELS,
  KPI_METRIC_KIND,
  currentMonthKey,
  monthKeyOf,
  type KpiMetricKey,
  type KpiTarget,
} from "../types/kpiTarget";

interface Props {
  users: AdminUser[];
  restaurants: AdminRestaurant[];
  ownerApplications: OwnerApplication[];
  kpiMetrics: KpiMetricsV2 | null;
  targets: KpiTarget[];
  onSaveTarget: (
    metricKey: KpiMetricKey,
    periodMonth: Date,
    targetValue: number,
  ) => Promise<void>;
}

const GOAL_METRICS: KpiMetricKey[] = [
  "new_users",
  "lunch_dau",
  "wau",
  "reports",
  "report_participants",
  "coverage",
];

function progressLabel(current: number, target: number, unit: string): string {
  if (target <= 0) return "목표 미설정";
  const pct = Math.round((current / target) * 100);
  return `목표 ${target.toLocaleString("ko-KR")}${unit} 중 ${current.toLocaleString("ko-KR")}${unit} 달성 (${pct}%)`;
}

export function KPIPage({
  restaurants,
  ownerApplications: _ownerApplications,
  kpiMetrics,
  targets,
  onSaveTarget,
}: Props) {
  const [showGoalModal, setShowGoalModal] = useState(false);
  const [showPartneredModal, setShowPartneredModal] = useState(false);
  const [showReportsModal, setShowReportsModal] = useState(false);
  const [detailKey, setDetailKey] = useState<KpiMetricKey | null>(null);

  const crowdEnabledRestaurants = restaurants.filter((r) => r.crowdEnabled);
  const partneredRestaurants = crowdEnabledRestaurants.filter((r) => r.ownerId);

  const thisMonthKey = currentMonthKey();
  const targetMap = new Map(
    targets
      .filter((t) => monthKeyOf(t.periodMonth) === thisMonthKey)
      .map((t) => [t.metricKey, t.targetValue]),
  );

  const currentValues: Record<KpiMetricKey, number> = {
    new_users: kpiMetrics?.newUsersThisMonth ?? 0,
    lunch_dau: kpiMetrics?.lunchAvgThisMonth ?? 0,
    wau: kpiMetrics?.wauCurrent ?? 0,
    reports: kpiMetrics?.reportsThisMonth ?? 0,
    report_participants: kpiMetrics?.participantsAvgThisMonth ?? 0,
    coverage: kpiMetrics?.coverageAvgThisMonth ?? 0,
  };

  const daysElapsed = kpiMetrics?.newUsersDailyThisMonth.length ?? 0;
  const monthDayLabels = thisMonthDayLabels(daysElapsed);

  return (
    <div className="dashboard">
      <section className="metric-grid metric-grid--primary">
        <MetricCard
          size="primary"
          label="총 가입자"
          value={formatCount(kpiMetrics?.totalSignups ?? 0)}
          unit="명"
        />
        <MetricCard
          size="primary"
          label="총 제휴 매장"
          value={formatCount(partneredRestaurants.length)}
          unit="개"
          onClick={() => setShowPartneredModal(true)}
        />
        <MetricCard
          size="primary"
          label="누적 제보"
          value={formatCount(kpiMetrics?.totalReports ?? 0)}
          unit="건"
          onClick={() => setShowReportsModal(true)}
        />
        <MetricCard
          size="primary"
          label="누적 게시글"
          value={formatCount(kpiMetrics?.totalPosts ?? 0)}
          unit="개"
        />
      </section>

      <section className="panel">
        <div className="panel-head">
          <h2>이번 달 목표 달성률</h2>
          <button
            type="button"
            className="btn outline sm"
            onClick={() => setShowGoalModal(true)}
          >
            목표 설정
          </button>
        </div>
        <div className="two-col">
          {GOAL_METRICS.map((key) => {
            const current = currentValues[key];
            const target = targetMap.get(key) ?? 0;
            const isAverage = KPI_METRIC_KIND[key] === "average";
            return (
              <div
                key={key}
                onClick={() => setDetailKey(key)}
                style={{ cursor: "pointer" }}
              >
                <p className="metric-label">{KPI_METRIC_LABELS[key]}</p>
                <ProgressBar current={current} target={target} />
                <p className="muted xs">
                  {isAverage ? "일평균 기준" : "이번 달 누적 기준"}
                </p>
              </div>
            );
          })}
        </div>
      </section>

      {kpiMetrics && <ActiveUsersTrendCard kpiMetrics={kpiMetrics} />}

      <div className="two-col">
        <TrendChart
          title="이번 달 일자별 신규 가입자"
          labels={monthDayLabels}
          values={kpiMetrics?.newUsersDailyThisMonth ?? []}
          kind="bar"
        />
        <TrendChart
          title="이번 달 일자별 제보 수"
          labels={monthDayLabels}
          values={kpiMetrics?.reportsDailyThisMonth ?? []}
          kind="bar"
        />
      </div>

      <div className="two-col">
        <TrendChart
          title="이번 달 날짜별 점심시간 사용자"
          labels={monthDayLabels}
          values={kpiMetrics?.lunchDailyThisMonth ?? []}
        />
      </div>

      {showGoalModal && (
        <KpiGoalModal
          targets={targets}
          onSave={onSaveTarget}
          onClose={() => setShowGoalModal(false)}
        />
      )}

      {showPartneredModal && (
        <Modal title="제휴 매장 목록" onClose={() => setShowPartneredModal(false)}>
          {partneredRestaurants.length === 0 ? (
            <p className="muted center">아직 제휴된 매장이 없어요.</p>
          ) : (
            <div className="table-wrap">
              <table className="data-table">
                <thead>
                  <tr>
                    <th>매장명</th>
                    <th>지역</th>
                    <th>카테고리</th>
                  </tr>
                </thead>
                <tbody>
                  {partneredRestaurants.map((r) => (
                    <tr key={r.id}>
                      <td>{r.name}</td>
                      <td>{r.area}</td>
                      <td>{r.category}</td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          )}
        </Modal>
      )}

      {showReportsModal && (
        <Modal
          title="매장별 누적 제보 수"
          onClose={() => setShowReportsModal(false)}
          wide
        >
          <RestaurantBarList
            restaurants={crowdEnabledRestaurants}
            countById={kpiMetrics?.totalByRestaurant ?? {}}
            total={kpiMetrics?.totalReports ?? 0}
          />
        </Modal>
      )}

      {detailKey && kpiMetrics && (
        <KpiGoalDetailModal
          metricKey={detailKey}
          kpiMetrics={kpiMetrics}
          target={targetMap.get(detailKey) ?? 0}
          current={currentValues[detailKey]}
          monthDayLabels={monthDayLabels}
          onClose={() => setDetailKey(null)}
        />
      )}
    </div>
  );
}

function KpiGoalDetailModal({
  metricKey,
  kpiMetrics,
  target,
  current,
  monthDayLabels,
  onClose,
}: {
  metricKey: KpiMetricKey;
  kpiMetrics: KpiMetricsV2;
  target: number;
  current: number;
  monthDayLabels: string[];
  onClose: () => void;
}) {
  const unit =
    metricKey === "coverage" ? "%" : metricKey === "reports" ? "건" : "명";

  const body = (() => {
    switch (metricKey) {
      case "new_users":
        return (
          <>
            <TrendChart
              title="이번 달 일자별 신규 가입자"
              labels={monthDayLabels}
              values={kpiMetrics.newUsersDailyThisMonth}
              kind="bar"
            />
            <p className="muted sm mt-8">
              전월 동일 시점 신규 가입자: {kpiMetrics.newUsersPrevMonthSamePoint}명
            </p>
          </>
        );
      case "lunch_dau":
        return (
          <>
            <TrendChart
              title="이번 달 날짜별 점심시간 사용자"
              labels={monthDayLabels}
              values={kpiMetrics.lunchDailyThisMonth}
            />
            <p className="muted sm mt-8">
              최근 7일 평균: {kpiMetrics.lunchAvg7d}명
            </p>
            <div className="panel-head mt-8">
              <h3>요일별 평균</h3>
            </div>
            <div className="table-wrap">
              <table className="data-table">
                <thead>
                  <tr>
                    <th>요일</th>
                    <th>평균 사용자</th>
                  </tr>
                </thead>
                <tbody>
                  {["일", "월", "화", "수", "목", "금", "토"].map((label, i) => (
                    <tr key={i}>
                      <td>{label}요일</td>
                      <td>{kpiMetrics.lunchByWeekday[String(i)] ?? 0}명</td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
            <div className="panel-head mt-8">
              <h3>30분 단위 평균 사용자 수 (오늘)</h3>
            </div>
            <TrendChart
              title=""
              labels={["11:00", "11:30", "12:00", "12:30", "13:00", "13:30"]}
              values={kpiMetrics.lunch30minAvg}
              kind="bar"
              hideTitle
            />
          </>
        );
      case "wau":
        return (
          <>
            <TrendChart
              title="최근 8주 WAU 추이"
              labels={last8WeekLabels()}
              values={kpiMetrics.wau8w}
              kind="bar"
            />
            <p className="muted sm mt-8">
              전주 대비: {kpiMetrics.wauCurrent - kpiMetrics.wauPrevWeek >= 0 ? "+" : ""}
              {kpiMetrics.wauCurrent - kpiMetrics.wauPrevWeek}명 · 신규 사용자{" "}
              {kpiMetrics.wauNewRatio}% · 기존 사용자 {kpiMetrics.wauExistingRatio}%
            </p>
          </>
        );
      case "reports":
        return (
          <>
            <TrendChart
              title="이번 달 일자별 제보 수"
              labels={monthDayLabels}
              values={kpiMetrics.reportsDailyThisMonth}
              kind="bar"
            />
            <p className="muted sm mt-8">
              사용자 제보 {kpiMetrics.reportsUserMonth}건 · 사장님 제보{" "}
              {kpiMetrics.reportsOwnerMonth}건 · 전월 동일 시점 대비{" "}
              {kpiMetrics.reportsThisMonth - kpiMetrics.reportsPrevMonthSamePoint >= 0
                ? "+"
                : ""}
              {kpiMetrics.reportsThisMonth - kpiMetrics.reportsPrevMonthSamePoint}건
            </p>
            <div className="panel-head mt-8">
              <h3>매장별 제보 수 TOP 10</h3>
            </div>
            {kpiMetrics.topRestaurantsMonth.length === 0 ? (
              <p className="muted center">이번 달 제보가 없어요.</p>
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
                    {kpiMetrics.topRestaurantsMonth.map((row, i) => (
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
          </>
        );
      case "report_participants":
        return (
          <>
            <TrendChart
              title="날짜별 제보 참여자 수"
              labels={monthDayLabels}
              values={kpiMetrics.participantsDailyThisMonth}
              kind="bar"
            />
            <p className="muted sm mt-8">
              최근 7일 평균: {kpiMetrics.participantsAvg7d}명 · 1인당 평균 제보 수:{" "}
              {kpiMetrics.avgReportsPerParticipantMonth}건 · 최근 7일 재제보 사용자 비율:{" "}
              {kpiMetrics.repeatRate7d}%
            </p>
          </>
        );
      case "coverage":
        return (
          <>
            <TrendChart
              title="이번 달 일별 평균 커버리지 (%)"
              labels={monthDayLabels}
              values={kpiMetrics.coverageDailyThisMonth}
              suffix="%"
            />
            <p className="muted sm mt-8">
              최근 7일 평균: {kpiMetrics.coverageAvg7d}% · 현재 실시간 커버리지:{" "}
              {kpiMetrics.coverageCurrent}%
            </p>
            <div className="panel-head mt-8">
              <h3>제보 공백이 자주 발생하는 매장 TOP 10</h3>
            </div>
            {kpiMetrics.sparseRestaurants.length === 0 ? (
              <p className="muted center">데이터 없음</p>
            ) : (
              <div className="table-wrap">
                <table className="data-table">
                  <thead>
                    <tr>
                      <th>순위</th>
                      <th>매장명</th>
                      <th>이번 달 제보 수</th>
                    </tr>
                  </thead>
                  <tbody>
                    {kpiMetrics.sparseRestaurants.map((row, i) => (
                      <tr key={row.restaurantId}>
                        <td>{i + 1}</td>
                        <td>{row.name}</td>
                        <td>{row.reportCount}건</td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
            )}
          </>
        );
      default:
        return null;
    }
  })();

  return (
    <Modal title={KPI_METRIC_LABELS[metricKey]} onClose={onClose} wide>
      <p className="muted sm">{progressLabel(current, target, unit)}</p>
      {body}
    </Modal>
  );
}
