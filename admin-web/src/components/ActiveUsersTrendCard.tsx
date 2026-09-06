import { useState } from "react";
import { TrendChart } from "./TrendChart";
import {
  last6MonthLabels,
  last8WeekLabels,
  lastNDayLabels,
} from "../lib/metrics";
import type { KpiMetricsV2 } from "../types/kpiMetrics";

type Tab = "dau" | "wau" | "mau";
type Period = "7d" | "30d";

interface Props {
  kpiMetrics: KpiMetricsV2;
}

function diffLabel(current: number, prev: number): string {
  const diff = current - prev;
  return `${diff >= 0 ? "+" : ""}${diff}명`;
}

export function ActiveUsersTrendCard({ kpiMetrics }: Props) {
  const [tab, setTab] = useState<Tab>("dau");
  const [period, setPeriod] = useState<Period>("7d");

  return (
    <section className="panel">
      <div className="panel-head">
        <h2>활성 사용자 추이</h2>
        <div className="row-actions">
          <button
            type="button"
            className={`btn sm${tab === "dau" ? " primary" : " outline"}`}
            onClick={() => setTab("dau")}
          >
            DAU
          </button>
          <button
            type="button"
            className={`btn sm${tab === "wau" ? " primary" : " outline"}`}
            onClick={() => setTab("wau")}
          >
            WAU
          </button>
          <button
            type="button"
            className={`btn sm${tab === "mau" ? " primary" : " outline"}`}
            onClick={() => setTab("mau")}
          >
            MAU
          </button>
        </div>
      </div>

      {tab === "dau" && (
        <>
          <div className="row-actions" style={{ justifyContent: "flex-end" }}>
            <button
              type="button"
              className={`btn sm${period === "7d" ? " primary" : " outline"}`}
              onClick={() => setPeriod("7d")}
            >
              최근 7일
            </button>
            <button
              type="button"
              className={`btn sm${period === "30d" ? " primary" : " outline"}`}
              onClick={() => setPeriod("30d")}
            >
              최근 30일
            </button>
          </div>
          <TrendChart
            title=""
            labels={lastNDayLabels(period === "7d" ? 7 : 30)}
            values={period === "7d" ? kpiMetrics.activeDaily7d : kpiMetrics.activeDaily30d}
            hideTitle
          />
          <p className="muted sm mt-8">
            전일 대비 {diffLabel(kpiMetrics.activeToday, kpiMetrics.activeYesterday)} · 기간 평균{" "}
            {period === "7d" ? kpiMetrics.activeAvg7d : kpiMetrics.activeAvg30d}명
          </p>
        </>
      )}

      {tab === "wau" && (
        <>
          <TrendChart
            title=""
            labels={last8WeekLabels()}
            values={kpiMetrics.wau8w}
            kind="bar"
            hideTitle
          />
          <p className="muted sm mt-8">
            전주 대비 {diffLabel(kpiMetrics.wauCurrent, kpiMetrics.wauPrevWeek)}
          </p>
        </>
      )}

      {tab === "mau" && (
        <>
          <TrendChart
            title=""
            labels={last6MonthLabels()}
            values={kpiMetrics.activeMonthly6m}
            kind="bar"
            hideTitle
          />
          <p className="muted sm mt-8">
            전월 대비 {diffLabel(kpiMetrics.activeMonthCurrent, kpiMetrics.activeMonthPrev)}
          </p>
        </>
      )}
    </section>
  );
}
