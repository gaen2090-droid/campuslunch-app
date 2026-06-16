import type { ReactNode } from "react";
import { TrendChart } from "./TrendChart";
import { Modal } from "./Modal";
import { last6MonthLabels, last7DayLabels } from "../lib/metrics";
import type { AdminRestaurant } from "../types/restaurant";
import type { DashboardMetrics } from "../types/metrics";

export type MetricDetailKey =
  | "dau"
  | "mau"
  | "reports"
  | "weekAvg"
  | "clickRate"
  | "pushOpenRate";

interface Props {
  detailKey: MetricDetailKey;
  metrics: DashboardMetrics;
  restaurants: AdminRestaurant[];
  onClose: () => void;
}

function RestaurantBarList({
  restaurants,
  countById,
  total,
}: {
  restaurants: AdminRestaurant[];
  countById: Record<string, number>;
  total: number;
}) {
  const data = restaurants
    .map((r) => ({ name: r.name, count: countById[r.id] ?? 0 }))
    .sort((a, b) => b.count - a.count);
  const maxV = Math.max(1, ...data.map((d) => d.count));
  const avg =
    restaurants.length > 0
      ? Math.round((total / restaurants.length) * 10) / 10
      : 0;

  return (
    <div className="restaurant-bar-list">
      <div className="avg-pill">
        <span>평균</span>
        <strong>{avg}건</strong>
      </div>
      <ul>
        {data.map((row) => (
          <li key={row.name}>
            <span className="bar-name">{row.name}</span>
            <div className="bar-track-wrap">
              <div className="bar-track">
                <div
                  className="bar-fill"
                  style={{ width: `${(row.count / maxV) * 100}%` }}
                />
              </div>
              <span className="bar-count">{row.count}</span>
            </div>
          </li>
        ))}
      </ul>
    </div>
  );
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
  }
}

export function MetricDetailModal({
  detailKey,
  metrics,
  restaurants,
  onClose,
}: Props) {
  let body: ReactNode;

  if (detailKey === "dau") {
    body = <DauDetail metrics={metrics} />;
  } else if (detailKey === "reports") {
    body = (
      <RestaurantBarList
        restaurants={restaurants}
        countById={metrics.todayByRestaurant}
        total={metrics.todayReports}
      />
    );
  } else if (detailKey === "weekAvg") {
    body = (
      <RestaurantBarList
        restaurants={restaurants}
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
