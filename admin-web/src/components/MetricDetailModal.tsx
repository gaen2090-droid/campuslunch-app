import type { ReactNode } from "react";
import { TrendChart } from "./TrendChart";
import { Modal } from "./Modal";
import { RestaurantBarList } from "./RestaurantBarList";
import { last6MonthLabels, last7DayLabels } from "../lib/metrics";
import type { AdminRestaurant } from "../types/restaurant";
import type { OwnerApplication } from "../types/ownerApplication";
import type { DashboardMetrics } from "../types/metrics";

export type MetricDetailKey =
  | "dau"
  | "mau"
  | "reports"
  | "weekAvg"
  | "clickRate"
  | "pushOpenRate"
  | "coverage"
  | "ownerRegistration"
  | "coupon"
  | "newUsers";

interface Props {
  detailKey: MetricDetailKey;
  metrics: DashboardMetrics;
  restaurants: AdminRestaurant[];
  /** coverage/ownerRegistration 상세용 — 이미 crowd_enabled로 걸러진 매장만 넘길 것 */
  crowdEnabledRestaurants?: AdminRestaurant[];
  /** newUsers 상세용 최근 7일 일별 신규 가입자 수 */
  dailyNewUsers?: number[];
  /** ownerRegistration 상세용 — 오늘 승인된 오너 신청 목록 */
  todayApprovedOwners?: OwnerApplication[];
  onClose: () => void;
}

function DauDetail({ metrics }: { metrics: DashboardMetrics }) {
  const vals = metrics.dailyDau;
  const current = vals.length ? vals[vals.length - 1] : 0;
  const prev = vals.length >= 2 ? vals[vals.length - 2] : 0;
  const diff = current - prev;

  return (
    <div className="dau-detail">
      <p className="dau-hero">
        <strong>{current}</strong>
        <span className="muted">명</span>
        <span className={diff >= 0 ? "diff-up" : "diff-down"}>
          {diff >= 0 ? "+" : ""}
          {diff}
        </span>
      </p>
      <TrendChart
        title=""
        labels={last7DayLabels()}
        values={vals}
        hideTitle
      />
      <p className="muted xs center">로그인 사용자 기준 · KST 일별 집계</p>
    </div>
  );
}

function titleFor(key: MetricDetailKey, metrics: DashboardMetrics): string {
  switch (key) {
    case "dau":
      return "DAU (일간 활성 사용자)";
    case "mau":
      return `MAU (최근 30일 ${metrics.mau}명)`;
    case "reports":
      return "오늘 매장별 제보 수";
    case "weekAvg":
      return "최근 7일 매장별 제보 수";
    case "clickRate":
      return "추천 배너 클릭률 추이";
    case "pushOpenRate":
      return "푸시 오픈율 추이";
    case "coverage":
      return "오늘 제보 없는 매장";
    case "ownerRegistration":
      return "오늘 오너 등록";
    case "coupon":
      return "쿠폰 제공 추이 (최근 7일)";
    case "newUsers":
      return "신규 가입자 추이 (최근 7일)";
  }
}

function RestaurantNameList({
  restaurants,
  emptyText,
}: {
  restaurants: AdminRestaurant[];
  emptyText: string;
}) {
  if (restaurants.length === 0) {
    return <p className="muted center">{emptyText}</p>;
  }
  return (
    <ul className="feedback-list">
      {restaurants.map((r) => (
        <li key={r.id} className="feedback-row">
          <div className="feedback-row-head">
            <strong>{r.name}</strong>
            <span className="muted sm">
              {r.area} · {r.category}
            </span>
          </div>
        </li>
      ))}
    </ul>
  );
}

export function MetricDetailModal({
  detailKey,
  metrics,
  restaurants,
  crowdEnabledRestaurants,
  dailyNewUsers,
  todayApprovedOwners,
  onClose,
}: Props) {
  let body: ReactNode;

  if (detailKey === "dau") {
    body = <DauDetail metrics={metrics} />;
  } else if (detailKey === "coverage") {
    const base = crowdEnabledRestaurants ?? restaurants;
    const uncovered = base.filter(
      (r) => (metrics.todayByRestaurant[r.id] ?? 0) === 0,
    );
    body = (
      <RestaurantNameList
        restaurants={uncovered}
        emptyText="모든 제보 대상 매장에 오늘 제보가 있어요."
      />
    );
  } else if (detailKey === "ownerRegistration") {
    const list = todayApprovedOwners ?? [];
    body =
      list.length === 0 ? (
        <p className="muted center">오늘 등록된 사장님이 없어요.</p>
      ) : (
        <ul className="feedback-list">
          {list.map((a) => (
            <li key={a.id} className="feedback-row">
              <div className="feedback-row-head">
                <strong>{a.restaurantName}</strong>
                <span className="muted sm">{a.userNickname}</span>
              </div>
            </li>
          ))}
        </ul>
      );
  } else if (detailKey === "reports") {
    body = (
      <RestaurantBarList
        restaurants={crowdEnabledRestaurants ?? restaurants}
        countById={metrics.todayByRestaurant}
        total={metrics.todayReports}
      />
    );
  } else if (detailKey === "weekAvg") {
    body = (
      <RestaurantBarList
        restaurants={crowdEnabledRestaurants ?? restaurants}
        countById={metrics.weekByRestaurant}
        total={metrics.weekReports}
      />
    );
  } else if (detailKey === "mau") {
    body = (
      <>
        <TrendChart
          title=""
          labels={last6MonthLabels()}
          values={metrics.monthlyMau}
          kind="bar"
          hideTitle
        />
        <p className="muted xs center">KST 기준 실시간 집계</p>
      </>
    );
  } else if (detailKey === "coupon") {
    body = (
      <>
        <TrendChart
          title=""
          labels={last7DayLabels()}
          values={metrics.dailyGifticonsAssigned}
          hideTitle
        />
        <p className="muted xs center">
          이번 달 총 {metrics.monthGifticonsAssigned}개 제공
        </p>
      </>
    );
  } else if (detailKey === "newUsers") {
    body = (
      <>
        <TrendChart
          title=""
          labels={last7DayLabels()}
          values={dailyNewUsers ?? []}
          hideTitle
        />
        <p className="muted xs center">가입일(KST) 기준 집계</p>
      </>
    );
  } else if (detailKey === "clickRate") {
    body = (
      <>
        <TrendChart
          title=""
          labels={last7DayLabels()}
          values={metrics.dailyClickRates}
          suffix="%"
          hideTitle
        />
        <p className="muted xs center">KST 기준 실시간 집계</p>
      </>
    );
  } else {
    body = (
      <>
        <TrendChart
          title=""
          labels={last7DayLabels()}
          values={metrics.dailyPushOpenRates}
          suffix="%"
          hideTitle
        />
        <p className="muted xs center">KST 기준 실시간 집계</p>
      </>
    );
  }

  return (
    <Modal title={titleFor(detailKey, metrics)} onClose={onClose} wide>
      {body}
    </Modal>
  );
}
