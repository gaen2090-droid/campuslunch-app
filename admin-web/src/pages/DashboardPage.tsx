import { useState } from "react";
import { MetricCard } from "../components/MetricCard";
import {
  MetricDetailModal,
  type MetricDetailKey,
} from "../components/MetricDetailModal";
import { TrendChart } from "../components/TrendChart";
import {
  displayReporterName,
  formatCount,
  formatRate,
  last6MonthLabels,
  last7DayLabels,
} from "../lib/metrics";
import type { AdminRestaurant } from "../types/restaurant";
import type { DashboardMetrics } from "../types/metrics";

const rankEmoji = ["🥇", "🥈", "🥉"];

interface Props {
  metrics: DashboardMetrics;
  restaurants: AdminRestaurant[];
}

export function DashboardPage({ metrics, restaurants }: Props) {
  const [detailKey, setDetailKey] = useState<MetricDetailKey | null>(null);

  const topRestaurants = [...restaurants]
    .sort(
      (a, b) =>
        (metrics.todayByRestaurant[b.id] ?? 0) -
        (metrics.todayByRestaurant[a.id] ?? 0),
    )
    .slice(0, 3);

  const registeredOwners = restaurants.filter((r) => r.ownerId).length;

  return (
    <div className="dashboard">
      <section className="metric-grid">
        <MetricCard
          label="DAU"
          value={String(metrics.dauToday)}
          unit="명"
          onClick={() => setDetailKey("dau")}
        />
        <MetricCard
          label="MAU"
          value={formatCount(metrics.mau)}
          unit="명"
          onClick={() => setDetailKey("mau")}
        />
        <MetricCard
          label="오늘 누적 제보"
          value={String(metrics.todayReports)}
          unit="건"
          onClick={() => setDetailKey("reports")}
        />
        <MetricCard
          label="최근 7일 누적 제보"
          value={String(metrics.weekReports)}
          unit="건"
          onClick={() => setDetailKey("weekAvg")}
        />
        <MetricCard
          label="추천 배너 클릭률"
          value={formatRate(metrics.bannerClickRate)}
          unit="%"
          onClick={() => setDetailKey("clickRate")}
        />
        <MetricCard
          label="푸시 오픈율"
          value={formatRate(metrics.pushOpenRate)}
          unit="%"
          onClick={() => setDetailKey("pushOpenRate")}
        />
      </section>

      {detailKey && (
        <MetricDetailModal
          detailKey={detailKey}
          metrics={metrics}
          restaurants={restaurants}
          onClose={() => setDetailKey(null)}
        />
      )}

      <section className="panel owner-stats">
        <p className="field-label">오너 등록 현황</p>
        <p className="owner-stats-value">
          <strong>{registeredOwners}</strong>
          <span className="muted"> / {restaurants.length} 매장</span>
        </p>
        <p className="muted xs">
          푸시: 평일 12:00·18:00 KST, 추천 배너 매장 구역 기준
        </p>
      </section>

      <div className="two-col">
        <TrendChart
          title="DAU 추이 (최근 7일)"
          labels={last7DayLabels()}
          values={metrics.dailyDau}
        />
        <TrendChart
          title="MAU 추이 (최근 6개월)"
          labels={last6MonthLabels()}
          values={metrics.monthlyMau}
          kind="bar"
        />
      </div>

      <div className="two-col">
        <TrendChart
          title="배너 클릭률 (최근 7일, %)"
          labels={last7DayLabels()}
          values={metrics.dailyClickRates}
          suffix="%"
        />
        <TrendChart
          title="푸시 오픈율 (최근 7일, %)"
          labels={last7DayLabels()}
          values={metrics.dailyPushOpenRates}
          suffix="%"
        />
      </div>

      <div className="two-col">
        <section className="panel">
          <h2>오늘 제보 많은 매장 Top 3</h2>
          {topRestaurants.length === 0 ? (
            <p className="muted">매장 데이터 없음</p>
          ) : (
            <ul className="rank-list">
              {topRestaurants.map((r, i) => (
                <li key={r.id}>
                  <span>{rankEmoji[i]}</span>
                  <span className="rank-name">{r.name}</span>
                  <strong>{metrics.todayByRestaurant[r.id] ?? 0}건</strong>
                </li>
              ))}
            </ul>
          )}
        </section>

        <section className="panel">
          <h2>오늘 제보 많은 유저 Top 3</h2>
          {metrics.topReporters.length === 0 ? (
            <p className="muted">아직 제보 데이터가 없어요</p>
          ) : (
            <ul className="rank-list">
              {metrics.topReporters.map(([name, count], i) => (
                <li key={`${name}-${i}`}>
                  <span>{rankEmoji[i]}</span>
                  <span className="rank-name">{displayReporterName(name)}</span>
                  <strong>{count}건</strong>
                </li>
              ))}
            </ul>
          )}
        </section>
      </div>
    </div>
  );
}
