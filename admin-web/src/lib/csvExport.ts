import type { AdminRestaurant } from "../types/restaurant";
import type { DashboardMetrics } from "../types/metrics";
import { totalReports } from "./adminApi";
import { formatRate } from "./metrics";

export const EXPORT_SECTIONS = [
  "사용자 지표",
  "리텐션",
  "시간대 분석",
  "오너 참여 현황",
  "유저 제보 참여 현황",
  "전환 지표",
  "매장 현황",
] as const;

export type ExportSection = (typeof EXPORT_SECTIONS)[number];

function fmtDate(d: Date): string {
  const y = d.getFullYear();
  const m = String(d.getMonth() + 1).padStart(2, "0");
  const day = String(d.getDate()).padStart(2, "0");
  return `${y}.${m}.${day}`;
}

function escapeCell(value: string): string {
  return `"${value.replace(/"/g, '""')}"`;
}

export function buildMetricsCsv(params: {
  startDate: Date;
  endDate: Date;
  sections: Set<ExportSection>;
  metrics: DashboardMetrics;
  restaurants: AdminRestaurant[];
}): string {
  const { startDate, endDate, sections, metrics, restaurants } = params;
  const buf: string[] = [];
  const period = `${fmtDate(startDate)} ~ ${fmtDate(endDate)}`;

  function section(title: string, rows: string[][]) {
    buf.push(`[${title}] 기간: ${period}`);
    for (const row of rows) {
      buf.push(row.map(escapeCell).join(","));
    }
    buf.push("");
  }

  if (sections.has("사용자 지표")) {
    section("사용자 지표", [
      ["항목", "값"],
      ["DAU (오늘)", `${metrics.dauToday}명`],
      ["MAU (최근 30일)", `${metrics.mau}명`],
      ["오늘 누적 제보", `${metrics.todayReports}건`],
      ["최근 7일 누적 제보", `${metrics.weekReports}건`],
      ["추천 배너 클릭률 (오늘)", `${formatRate(metrics.bannerClickRate)}%`],
      ["푸시 오픈율 (오늘)", `${formatRate(metrics.pushOpenRate)}%`],
    ]);
  }

  if (sections.has("매장 현황")) {
    section("매장 현황", [
      ["매장명", "구역", "카테고리", "현재 상태", "누적 제보", "영업시간"],
      ...restaurants.map((r) => [
        r.name,
        r.area,
        r.category,
        r.status,
        `${totalReports(r)}건`,
        r.hours,
      ]),
    ]);
  }

  if (sections.has("유저 제보 참여 현황")) {
    section("유저 제보 참여 현황", [
      ["매장명", "여유로움", "약간혼잡", "자리없음", "합계"],
      ...restaurants.map((r) => [
        r.name,
        String(r.reports["여유로움"] ?? 0),
        String(r.reports["약간혼잡"] ?? 0),
        String(r.reports["자리없음"] ?? 0),
        String(totalReports(r)),
      ]),
    ]);
  }

  if (sections.has("오너 참여 현황")) {
    section("오너 참여 현황", [
      ["매장명", "오너 등록"],
      ...restaurants.map((r) => [
        r.name,
        r.ownerRegistered ? "등록됨" : "미등록",
      ]),
    ]);
  }

  for (const label of ["리텐션", "시간대 분석", "전환 지표"] as ExportSection[]) {
    if (sections.has(label)) {
      section(label, [["※ 백엔드 연동 후 실데이터로 교체 예정"]]);
    }
  }

  return buf.join("\n");
}

export function downloadCsv(
  filename: string,
  csv: string,
): void {
  const bom = new Uint8Array([0xef, 0xbb, 0xbf]);
  const body = new TextEncoder().encode(csv);
  const blob = new Blob([bom, body], { type: "text/csv;charset=utf-8" });
  const url = URL.createObjectURL(blob);
  const a = document.createElement("a");
  a.href = url;
  a.download = filename;
  a.click();
  URL.revokeObjectURL(url);
}

export { fmtDate };
