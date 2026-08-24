import type { Workbook, Worksheet, Row, Fill, Font } from "exceljs";
import type { AdminRestaurant } from "../types/restaurant";
import type { DashboardMetrics } from "../types/metrics";
import type { RewardSpendReport } from "./adminApi";
import { totalReports } from "./adminApi";
import { last6MonthLabels, last7DayLabels } from "./metrics";
import type { TrustSignalsReport } from "../types/trustAbuse";

export const EXPORT_SECTIONS = [
  "사용자 지표",
  "리텐션",
  "시간대 분석",
  "오너 참여 현황",
  "유저 제보 참여 현황",
  "전환 지표",
  "매장 현황",
  "리워드 지출",
] as const;

export type ExportSection = (typeof EXPORT_SECTIONS)[number];

/** 핵심 지표와 목적이 다른 신뢰·어뷰징 원본 수집용 */
export const TRUST_EXPORT_SHEETS = [
  "유저 요약",
  "같매장 간격(분)",
  "이동거리(m)",
  "구역 전환",
] as const;

export type TrustExportSheet = (typeof TRUST_EXPORT_SHEETS)[number];

const AREA_ORDER = ["정문", "중문", "후문"] as const;

const HEADER_FILL: Fill = {
  type: "pattern",
  pattern: "solid",
  fgColor: { argb: "FF1F2937" },
};
const HEADER_FONT: Partial<Font> = {
  bold: true,
  color: { argb: "FFFFFFFF" },
  size: 11,
  name: "맑은 고딕",
};
const BODY_FONT: Partial<Font> = {
  size: 11,
  name: "맑은 고딕",
};
const ZEBRA_FILL: Fill = {
  type: "pattern",
  pattern: "solid",
  fgColor: { argb: "FFF3F4F6" },
};
const TITLE_FONT: Partial<Font> = {
  bold: true,
  size: 14,
  name: "맑은 고딕",
  color: { argb: "FF111827" },
};
const META_LABEL_FONT: Partial<Font> = {
  bold: true,
  size: 11,
  name: "맑은 고딕",
  color: { argb: "FF4B5563" },
};
const TOTAL_FILL: Fill = {
  type: "pattern",
  pattern: "solid",
  fgColor: { argb: "FFFEF3C7" },
};

type CellValue = string | number | boolean | null | undefined;

export function fmtDate(d: Date): string {
  const y = d.getFullYear();
  const m = String(d.getMonth() + 1).padStart(2, "0");
  const day = String(d.getDate()).padStart(2, "0");
  return `${y}-${m}-${day}`;
}

function fmtDateTime(d: Date): string {
  const hh = String(d.getHours()).padStart(2, "0");
  const mm = String(d.getMinutes()).padStart(2, "0");
  return `${fmtDate(d)} ${hh}:${mm}`;
}

function todayKstLabel(): string {
  const parts = new Intl.DateTimeFormat("en-CA", {
    timeZone: "Asia/Seoul",
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
  }).formatToParts(new Date());
  const y = parts.find((p) => p.type === "year")?.value ?? "";
  const m = parts.find((p) => p.type === "month")?.value ?? "";
  const d = parts.find((p) => p.type === "day")?.value ?? "";
  return `${y}-${m}-${d}`;
}

function mauMonthLabel(): string {
  const parts = new Intl.DateTimeFormat("en-CA", {
    timeZone: "Asia/Seoul",
    year: "numeric",
    month: "2-digit",
  }).formatToParts(new Date());
  const y = parts.find((p) => p.type === "year")?.value ?? "";
  const m = parts.find((p) => p.type === "month")?.value ?? "";
  return `${y}-${m}`;
}

function sortedRestaurants(list: AdminRestaurant[]): AdminRestaurant[] {
  return [...list].sort((a, b) => {
    const ai = AREA_ORDER.indexOf(a.area as (typeof AREA_ORDER)[number]);
    const bi = AREA_ORDER.indexOf(b.area as (typeof AREA_ORDER)[number]);
    const aOrd = ai === -1 ? 99 : ai;
    const bOrd = bi === -1 ? 99 : bi;
    if (aOrd !== bOrd) return aOrd - bOrd;
    return a.name.localeCompare(b.name, "ko");
  });
}

function reportCount(r: AdminRestaurant, ...keys: string[]): number {
  const reports = r.reports ?? {};
  return keys.reduce((sum, k) => sum + (Number(reports[k]) || 0), 0);
}

function sheetName(label: string): string {
  return label.replace(/[\\/?*[\]:]/g, "").slice(0, 31);
}

function applyHeaderRow(row: Row, colCount: number) {
  row.height = 22;
  for (let c = 1; c <= colCount; c++) {
    const cell = row.getCell(c);
    cell.fill = HEADER_FILL;
    cell.font = HEADER_FONT;
    cell.alignment = {
      vertical: "middle",
      horizontal: "center",
      wrapText: true,
    };
    cell.border = {
      top: { style: "thin", color: { argb: "FF374151" } },
      left: { style: "thin", color: { argb: "FF374151" } },
      bottom: { style: "thin", color: { argb: "FF374151" } },
      right: { style: "thin", color: { argb: "FF374151" } },
    };
  }
}

function applyBodyRow(row: Row, colCount: number, zebra: boolean) {
  row.height = 18;
  for (let c = 1; c <= colCount; c++) {
    const cell = row.getCell(c);
    cell.font = BODY_FONT;
    cell.alignment = { vertical: "middle" };
    if (zebra) cell.fill = ZEBRA_FILL;
    cell.border = {
      top: { style: "hair", color: { argb: "FFE5E7EB" } },
      left: { style: "hair", color: { argb: "FFE5E7EB" } },
      bottom: { style: "hair", color: { argb: "FFE5E7EB" } },
      right: { style: "hair", color: { argb: "FFE5E7EB" } },
    };
    if (typeof cell.value === "number") {
      cell.alignment = { vertical: "middle", horizontal: "right" };
    }
  }
}

function applyTotalRow(row: Row, colCount: number) {
  row.height = 20;
  for (let c = 1; c <= colCount; c++) {
    const cell = row.getCell(c);
    cell.font = { ...BODY_FONT, bold: true };
    cell.fill = TOTAL_FILL;
    cell.alignment = {
      vertical: "middle",
      horizontal: typeof cell.value === "number" ? "right" : "left",
    };
    cell.border = {
      top: { style: "thin", color: { argb: "FFF59E0B" } },
      left: { style: "hair", color: { argb: "FFFDE68A" } },
      bottom: { style: "thin", color: { argb: "FFF59E0B" } },
      right: { style: "hair", color: { argb: "FFFDE68A" } },
    };
  }
}

function setColumnWidths(ws: Worksheet, widths: number[]) {
  widths.forEach((w, i) => {
    ws.getColumn(i + 1).width = w;
  });
}

function writeDataSheet(
  wb: Workbook,
  title: string,
  metaLines: Array<[string, string]>,
  headers: string[],
  rows: CellValue[][],
  widths: number[],
  options?: { totalRowIndexes?: number[] },
) {
  const headerRowIndex = 1 + metaLines.length + 2;
  const ws = wb.addWorksheet(sheetName(title), {
    views: [{ state: "frozen", ySplit: headerRowIndex }],
  });

  let r = 1;
  ws.mergeCells(r, 1, r, Math.max(headers.length, 2));
  const titleCell = ws.getCell(r, 1);
  titleCell.value = title;
  titleCell.font = TITLE_FONT;
  titleCell.alignment = { vertical: "middle" };
  ws.getRow(r).height = 26;
  r += 1;

  for (const [k, v] of metaLines) {
    ws.getCell(r, 1).value = k;
    ws.getCell(r, 1).font = META_LABEL_FONT;
    ws.getCell(r, 2).value = v;
    ws.getCell(r, 2).font = BODY_FONT;
    r += 1;
  }

  r += 1;
  const headerRow = ws.getRow(r);
  headers.forEach((h, i) => {
    headerRow.getCell(i + 1).value = h;
  });
  applyHeaderRow(headerRow, headers.length);
  r += 1;

  const totalSet = new Set(options?.totalRowIndexes ?? []);
  rows.forEach((values, idx) => {
    const dataRow = ws.getRow(r);
    values.forEach((v, i) => {
      const cell = dataRow.getCell(i + 1);
      if (v == null) cell.value = "";
      else if (typeof v === "boolean") cell.value = v ? "Y" : "N";
      else cell.value = v;
    });
    if (totalSet.has(idx)) applyTotalRow(dataRow, headers.length);
    else applyBodyRow(dataRow, headers.length, idx % 2 === 1);
    r += 1;
  });

  setColumnWidths(ws, widths);

  if (rows.length > 0) {
    ws.autoFilter = {
      from: { row: headerRowIndex, column: 1 },
      to: { row: headerRowIndex + rows.length, column: headers.length },
    };
  }
}

export interface MetricsExportParams {
  startDate: Date;
  endDate: Date;
  sections: Set<ExportSection>;
  metrics: DashboardMetrics;
  restaurants: AdminRestaurant[];
  rewardSpend?: RewardSpendReport | null;
}

async function loadExcelJS() {
  const mod = await import("exceljs");
  return mod.default;
}

export async function buildMetricsWorkbook(
  params: MetricsExportParams,
): Promise<Workbook> {
  const ExcelJS = await loadExcelJS();
  const { startDate, endDate, sections, metrics, restaurants, rewardSpend } =
    params;
  const periodStart = fmtDate(startDate);
  const periodEnd = fmtDate(endDate);
  const exportedAt = fmtDateTime(new Date());
  const restaurantsSorted = sortedRestaurants(restaurants);
  const dayLabels = last7DayLabels();
  const monthLabels = last6MonthLabels();
  const ownerCount = restaurants.filter((r) => r.ownerId).length;
  const dauDate = todayKstLabel();
  const mauMonth = mauMonthLabel();

  const meta: Array<[string, string]> = [
    ["기간", `${periodStart} ~ ${periodEnd}`],
    ["내보낸 시각", exportedAt],
  ];

  const wb = new ExcelJS.Workbook();
  wb.creator = "CampusLunch Admin";
  wb.created = new Date();

  writeDataSheet(
    wb,
    "요약",
    meta,
    ["지표", "값", "단위", "설명"],
    [
      [
        `DAU (${dauDate})`,
        metrics.dauToday,
        "명",
        `기준일 ${dauDate} (KST) 활성 사용자`,
      ],
      [
        `MAU (${mauMonth})`,
        metrics.mau,
        "명",
        "매월 1일 갱신 · 해당 월 활성 사용자",
      ],
      ["오늘 누적 제보", metrics.todayReports, "건", "오늘 혼잡도 제보 수"],
      ["최근 7일 누적 제보", metrics.weekReports, "건", "최근 7일 제보 합계"],
      ["추천 배너 클릭률 (오늘)", metrics.bannerClickRate, "%", "오늘 배너 클릭률"],
      ["푸시 오픈율 (오늘)", metrics.pushOpenRate, "%", "오늘 푸시 오픈율"],
      ["오너 등록 매장", ownerCount, "개", "사장님 연결된 매장"],
      ["전체 매장", restaurants.length, "개", "등록된 매장 수"],
      ...(rewardSpend
        ? ([
            [
              "리워드 총 지급 건수",
              rewardSpend.totalRewardCount,
              "건",
              "배정된 기프티콘 누적",
            ],
            [
              "리워드 총 지출 액수",
              rewardSpend.totalAmountKrw,
              "원",
              "현재까지 리워드 지출 합계",
            ],
          ] as CellValue[][])
        : []),
      ["선택 섹션", [...sections].join(", "), "", "이번 파일에 포함된 시트"],
    ],
    [28, 14, 8, 40],
  );

  if (sections.has("사용자 지표")) {
    writeDataSheet(
      wb,
      "사용자 지표",
      [
        ["내보낸 시각", exportedAt],
        [
          "참고",
          "지표별 기준일·갱신 주기는 '기준'·'비고' 열을 보세요 (기간 중복 제거)",
        ],
      ],
      ["지표", "값", "단위", "기준", "비고"],
      [
        [
          "DAU",
          metrics.dauToday,
          "명",
          dauDate,
          `기준일 ${dauDate} (KST) · 해당일 활성 사용자`,
        ],
        [
          "MAU",
          metrics.mau,
          "명",
          `${mauMonth}-01`,
          "매월 1일 갱신 · 해당 월 활성 사용자",
        ],
        [
          "오늘 누적 제보",
          metrics.todayReports,
          "건",
          dauDate,
          "기준일 당일 제보 수",
        ],
        [
          "최근 7일 누적 제보",
          metrics.weekReports,
          "건",
          `~${dauDate}`,
          "기준일 포함 최근 7일",
        ],
        [
          "추천 배너 클릭률",
          metrics.bannerClickRate,
          "%",
          dauDate,
          "기준일 당일",
        ],
        ["푸시 오픈율", metrics.pushOpenRate, "%", dauDate, "기준일 당일"],
        [
          "오너 등록 매장 수",
          ownerCount,
          "개",
          exportedAt,
          "내보내기 시점 스냅샷",
        ],
        [
          "전체 매장 수",
          restaurants.length,
          "개",
          exportedAt,
          "내보내기 시점 스냅샷",
        ],
      ],
      [18, 12, 8, 18, 40],
    );
  }

  if (sections.has("리텐션")) {
    writeDataSheet(
      wb,
      "리텐션",
      meta,
      ["구분", "날짜_또는_월", "값", "단위"],
      [
        ...dayLabels.map((label, i) => [
          "DAU 추이 (최근 7일)",
          label,
          metrics.dailyDau[i] ?? 0,
          "명",
        ]),
        ...monthLabels.map((label, i) => [
          "MAU 추이 (최근 6개월)",
          label,
          metrics.monthlyMau[i] ?? 0,
          "명",
        ]),
      ],
      [22, 14, 10, 8],
    );
  }

  if (sections.has("시간대 분석")) {
    writeDataSheet(
      wb,
      "시간대 분석",
      [...meta, ["참고", "시간대 raw 미연동 · 최근 7일 일자별 지표"]],
      ["날짜", "DAU", "배너클릭률(%)", "푸시오픈율(%)"],
      dayLabels.map((label, i) => [
        label,
        metrics.dailyDau[i] ?? 0,
        metrics.dailyClickRates[i] ?? 0,
        metrics.dailyPushOpenRates[i] ?? 0,
      ]),
      [12, 10, 14, 14],
    );
  }

  if (sections.has("전환 지표")) {
    writeDataSheet(
      wb,
      "전환 지표",
      meta,
      ["지표", "날짜", "값", "단위"],
      [
        ["배너 클릭률 (오늘)", periodEnd, metrics.bannerClickRate, "%"],
        ["푸시 오픈율 (오늘)", periodEnd, metrics.pushOpenRate, "%"],
        ...dayLabels.map((label, i) => [
          "배너 클릭률 (일별)",
          label,
          metrics.dailyClickRates[i] ?? 0,
          "%",
        ]),
        ...dayLabels.map((label, i) => [
          "푸시 오픈율 (일별)",
          label,
          metrics.dailyPushOpenRates[i] ?? 0,
          "%",
        ]),
      ],
      [22, 12, 10, 8],
    );
  }

  if (sections.has("오너 참여 현황")) {
    writeDataSheet(
      wb,
      "오너 참여 현황",
      [...meta, ["등록 요약", `${ownerCount} / ${restaurantsSorted.length} 매장`]],
      ["매장명", "구역", "카테고리", "오너등록"],
      restaurantsSorted.map((r) => [
        r.name,
        r.area,
        r.category,
        r.ownerId ? "등록" : "미등록",
      ]),
      [24, 10, 12, 10],
    );
  }

  if (sections.has("유저 제보 참여 현황")) {
    writeDataSheet(
      wb,
      "유저 제보 참여",
      meta,
      [
        "매장명",
        "구역",
        "여유로움",
        "약간혼잡",
        "자리없음",
        "합계",
        "오늘제보",
        "7일제보",
      ],
      restaurantsSorted.map((r) => [
        r.name,
        r.area,
        reportCount(r, "여유로움"),
        reportCount(r, "약간혼잡"),
        reportCount(r, "자리없음", "웨이팅많음"),
        totalReports(r),
        metrics.todayByRestaurant[r.id] ?? 0,
        metrics.weekByRestaurant[r.id] ?? 0,
      ]),
      [22, 8, 10, 10, 10, 8, 10, 10],
    );
  }

  if (sections.has("매장 현황")) {
    writeDataSheet(
      wb,
      "매장 현황",
      meta,
      [
        "매장명",
        "구역",
        "카테고리",
        "현재상태",
        "오너등록",
        "누적제보",
        "영업시간",
        "활성",
        "주소",
      ],
      restaurantsSorted.map((r) => [
        r.name,
        r.area,
        r.category,
        r.status,
        r.ownerId ? "등록" : "미등록",
        totalReports(r),
        r.hours,
        r.isActive ? "Y" : "N",
        r.address,
      ]),
      [22, 8, 12, 12, 10, 10, 16, 6, 36],
    );
  }

  if (sections.has("리워드 지출")) {
    const report = rewardSpend ?? {
      totalRewardCount: 0,
      totalAmountKrw: 0,
      attributedCount: 0,
      unattributedCount: 0,
      missingFaceValueCount: 0,
      users: [],
    };
    const userRows: CellValue[][] = [
      ["(합계)", "", "", report.totalRewardCount, report.totalAmountKrw],
      ...report.users.map((u) => [
        u.userId,
        u.nickname || "",
        u.email || "",
        u.rewardCount,
        u.amountKrw,
      ]),
    ];
    writeDataSheet(
      wb,
      "리워드 지출",
      [
        ["내보낸 시각", exportedAt],
        ["총 지급 건수", `${report.totalRewardCount}건`],
        [
          "총 지출 액수",
          `${report.totalAmountKrw.toLocaleString("ko-KR")}원`,
        ],
        [
          "유저 귀속",
          `${report.attributedCount}건 (미귀속/탈퇴 ${report.unattributedCount}건)`,
        ],
        [
          "액수 참고",
          report.missingFaceValueCount > 0
            ? `face_value 미입력 ${report.missingFaceValueCount}건 · 상품명 'N원' 패턴으로 추정(없으면 0원)`
            : "face_value 또는 상품명 금액 기준",
        ],
      ],
      ["유저 ID", "닉네임", "이메일", "받아간 개수", "액수(원)"],
      userRows,
      [38, 14, 28, 12, 12],
      { totalRowIndexes: [0] },
    );
  }

  return wb;
}

export interface TrustExportParams {
  days: number;
  sheets: Set<TrustExportSheet>;
  report: TrustSignalsReport;
}

export async function buildTrustSignalsWorkbook(
  params: TrustExportParams,
): Promise<Workbook> {
  const ExcelJS = await loadExcelJS();
  const { days, sheets, report } = params;
  const exportedAt = fmtDateTime(new Date());
  const wb = new ExcelJS.Workbook();
  wb.creator = "CampusLunch Admin";
  wb.created = new Date();

  const meta: Array<[string, string]> = [
    ["카테고리", "신뢰·어뷰징 수집 지표 (점수/판정 없음)"],
    ["집계 기간", `최근 ${days}일`],
    ["내보낸 시각", exportedAt],
  ];

  if (sheets.has("유저 요약")) {
    writeDataSheet(
      wb,
      "유저 요약",
      meta,
      [
        "유저 ID",
        "닉네임",
        "이메일",
        "제보수",
        "같매장간격쌍",
        "같매장평균분",
        "같매장중앙분",
        "같매장최소분",
        "같매장최대분",
        "전체간격평균분",
        "전체간격중앙분",
        "이동쌍",
        "이동평균m",
        "이동중앙m",
        "이동최소m",
        "이동최대m",
        "구역전환수",
        "피어일치",
        "피어겹침",
        "기기간수",
        "형제계정수",
        "공유기기최대계정",
        "시도성공",
        "시도실패",
        "체류ms합",
        "상세조회",
        "지도클릭",
        "검색클릭",
        "배너클릭",
        "앱세션",
        "비제보이벤트",
        "스탬프내제보",
        "스탬프외제보",
      ],
      report.users.map((u) => [
        u.userId,
        u.nickname,
        u.email,
        u.reportCount,
        u.sameStoreIntervalPairCount,
        u.sameStoreIntervalAvgMin,
        u.sameStoreIntervalMedianMin,
        u.sameStoreIntervalMinMin,
        u.sameStoreIntervalMaxMin,
        u.allReportIntervalAvgMin,
        u.allReportIntervalMedianMin,
        u.movePairCount,
        u.moveAvgM,
        u.moveMedianM,
        u.moveMinM,
        u.moveMaxM,
        u.areaTransitionCount,
        u.peerAgreeCount,
        u.peerOverlapCount,
        u.deviceIds.length,
        u.deviceSiblingUserCount,
        u.deviceMaxAccountsOnShared,
        u.attemptSuccess,
        u.attemptFail,
        u.dwellMsTotal,
        u.detailViewN,
        u.mapClickN,
        u.searchClickN,
        u.bannerClickN,
        u.appSessionN,
        u.nonReportEventN,
        u.reportsInStampHours,
        u.reportsOutStampHours,
      ]),
      [
        36, 12, 24, 8, 10, 10, 10, 10, 10, 10, 10, 8, 10, 10, 10, 10, 8, 8, 8,
        8, 8, 10, 8, 8, 10, 8, 8, 8, 8, 8, 10, 10, 10,
      ],
    );
  }

  if (sheets.has("같매장 간격(분)")) {
    const rows: CellValue[][] = [];
    for (const u of report.users) {
      u.sameStoreIntervalsMin.forEach((gap, i) => {
        rows.push([u.userId, u.nickname, u.email, i + 1, gap]);
      });
    }
    writeDataSheet(
      wb,
      "같매장 간격(분)",
      [...meta, ["설명", "같은 매장에서 연속 제보 사이 간격(분). 한 행=한 간격"]],
      ["유저 ID", "닉네임", "이메일", "순서", "간격_분"],
      rows,
      [36, 12, 24, 8, 10],
    );
  }

  if (sheets.has("이동거리(m)")) {
    const rows: CellValue[][] = [];
    for (const u of report.users) {
      u.moveMeters.forEach((m, i) => {
        rows.push([u.userId, u.nickname, u.email, i + 1, m]);
      });
    }
    writeDataSheet(
      wb,
      "이동거리(m)",
      [...meta, ["설명", "연속 제보 GPS 간 거리(m). 한 행=한 이동"]],
      ["유저 ID", "닉네임", "이메일", "순서", "거리_m"],
      rows,
      [36, 12, 24, 8, 10],
    );
  }

  if (sheets.has("구역 전환")) {
    const rows: CellValue[][] = [];
    for (const u of report.users) {
      for (const t of u.areaTransitions) {
        rows.push([
          u.userId,
          u.nickname,
          u.email,
          t.fromArea,
          t.toArea,
          t.gapMin,
        ]);
      }
    }
    writeDataSheet(
      wb,
      "구역 전환",
      [...meta, ["설명", "정문/중문/후문 구역이 바뀔 때 간격(분)"]],
      ["유저 ID", "닉네임", "이메일", "from", "to", "간격_분"],
      rows,
      [36, 12, 24, 10, 10, 10],
    );
  }

  return wb;
}

export async function downloadTrustSignalsExcel(
  filename: string,
  params: TrustExportParams,
): Promise<void> {
  const wb = await buildTrustSignalsWorkbook(params);
  const buffer = await wb.xlsx.writeBuffer();
  const blob = new Blob([buffer], {
    type: "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
  });
  const url = URL.createObjectURL(blob);
  const a = document.createElement("a");
  a.href = url;
  a.download = filename.endsWith(".xlsx") ? filename : `${filename}.xlsx`;
  a.style.display = "none";
  document.body.appendChild(a);
  a.click();
  a.remove();
  window.setTimeout(() => URL.revokeObjectURL(url), 1500);
}

export async function downloadMetricsExcel(
  filename: string,
  params: MetricsExportParams,
): Promise<void> {
  const wb = await buildMetricsWorkbook(params);
  const buffer = await wb.xlsx.writeBuffer();
  const blob = new Blob([buffer], {
    type: "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
  });
  const url = URL.createObjectURL(blob);
  const a = document.createElement("a");
  a.href = url;
  a.download = filename.endsWith(".xlsx") ? filename : `${filename}.xlsx`;
  // Safari/Chrome: body에 붙이지 않으면 대용량 다운로드가 조용히 무시되는 경우가 있음
  a.style.display = "none";
  document.body.appendChild(a);
  a.click();
  a.remove();
  window.setTimeout(() => URL.revokeObjectURL(url), 1500);
}

/** 선택한 첫 데이터 시트를 TSV로 (엑셀/시트 붙여넣기용) */
export async function buildMetricsTsvForClipboard(
  params: MetricsExportParams,
): Promise<string> {
  const wb = await buildMetricsWorkbook(params);
  const ws =
    wb.worksheets.find((s) => s.name !== "요약") ?? wb.worksheets[0];
  if (!ws) return "";

  const lines: string[] = [];
  ws.eachRow({ includeEmpty: false }, (row) => {
    const vals: string[] = [];
    row.eachCell({ includeEmpty: true }, (cell, colNumber) => {
      while (vals.length < colNumber - 1) vals.push("");
      const v = cell.value;
      if (v == null) vals.push("");
      else if (typeof v === "object" && v !== null && "text" in v)
        vals.push(String((v as { text: unknown }).text));
      else if (typeof v === "object" && v !== null && "result" in v)
        vals.push(String((v as { result?: unknown }).result ?? ""));
      else vals.push(String(v));
    });
    lines.push(vals.join("\t"));
  });
  return lines.join("\n");
}
