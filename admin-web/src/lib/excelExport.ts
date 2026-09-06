import type { Workbook, Worksheet, Row, Fill, Font } from "exceljs";
import type { AdminRestaurant } from "../types/restaurant";
import type { AdminUser } from "../types/user";
import type { RealtimeMetrics } from "../types/realtimeMetrics";
import type { KpiMetricsV2 } from "../types/kpiMetrics";
import type { OpsMetrics } from "../types/opsMetrics";
import type { DailyExportRow, HourlyExportRow, RestaurantExportRow } from "../types/exportRangeMetrics";
import type { RewardSpendReport } from "./adminApi";
import { totalReports } from "./adminApi";
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

const APP_SESSION_CUTOFF = "2026-09-05";

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
  realtimeMetrics: RealtimeMetrics | null;
  kpiMetrics: KpiMetricsV2 | null;
  opsMetrics: OpsMetrics | null;
  dailyRows: DailyExportRow[];
  hourlyRows: HourlyExportRow[];
  restaurantRows: RestaurantExportRow[];
  restaurants: AdminRestaurant[];
  users: AdminUser[];
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
  const {
    startDate,
    endDate,
    sections,
    realtimeMetrics,
    kpiMetrics,
    opsMetrics,
    dailyRows,
    hourlyRows,
    restaurantRows,
    restaurants,
    users,
    rewardSpend,
  } = params;
  const periodStart = fmtDate(startDate);
  const periodEnd = fmtDate(endDate);
  const exportedAt = fmtDateTime(new Date());
  // 제휴 매장 집계는 제보 대상(crowd_enabled) 매장 기준으로 한다.
  // 맛집컬렉션 전용 매장은 애초에 제보/오너 인증 대상이 아니라서 분모에 넣으면 비율이 왜곡된다.
  const crowdEnabledRestaurants = restaurants.filter((r) => r.crowdEnabled);
  const restaurantsSorted = sortedRestaurants(restaurants);
  const partneredCount = crowdEnabledRestaurants.filter((r) => r.ownerId).length;
  const rangeCoversPreCutoff = periodStart < APP_SESSION_CUTOFF;

  const meta: Array<[string, string]> = [
    ["기간", `${periodStart} ~ ${periodEnd}`],
    ["내보낸 시각", exportedAt],
  ];
  const rangeMetaExtra: Array<[string, string]> = rangeCoversPreCutoff
    ? [
        [
          "참고",
          `앱 세션 기록 방식이 ${APP_SESSION_CUTOFF}부터 개선되어(1일 1건 → 30분 단위 재기록), 그 이전 날짜의 활성사용자·점심시간사용자 수치는 실제보다 적게 집계될 수 있음`,
        ],
      ]
    : [];

  const wb = new ExcelJS.Workbook();
  wb.creator = "CampusLunch Admin";
  wb.created = new Date();

  const rangeTotal = dailyRows.reduce(
    (acc, d) => ({
      activeUsers: acc.activeUsers + d.activeUsers,
      reports: acc.reports + d.reports,
      newSignups: acc.newSignups + d.newSignups,
    }),
    { activeUsers: 0, reports: 0, newSignups: 0 },
  );

  writeDataSheet(
    wb,
    "요약",
    meta,
    ["지표", "값", "단위", "설명"],
    [
      ["기간 내 신규 가입자", rangeTotal.newSignups, "명", `${periodStart} ~ ${periodEnd} 합계`],
      ["기간 내 누적 제보", rangeTotal.reports, "건", `${periodStart} ~ ${periodEnd} 합계`],
      ["오늘 활성 사용자", realtimeMetrics?.activeToday ?? 0, "명", "실시간 지표 기준"],
      ["총 가입자", users.length, "명", "전체 유저 수 (내보내기 시점 스냅샷)"],
      ["총 제휴 매장", partneredCount, "개", "사장님 연결된 매장 (제보 대상 기준, 스냅샷)"],
      ["누적 제보", kpiMetrics?.totalReports ?? 0, "건", "전체 기간 누적"],
      ["누적 게시글", kpiMetrics?.totalPosts ?? 0, "개", "전체 기간 누적"],
      ["추천 배너 CTR (최근 7일)", opsMetrics?.bannerCtr7d ?? 0, "%", "노출 대비 클릭 비율"],
      ["푸시 오픈율 (오늘)", opsMetrics?.pushOpenRateToday ?? 0, "%", "점심시간 알림 기준"],
      ["오늘 쿠폰 지급", opsMetrics?.couponsToday ?? 0, "건", "리워드 현황"],
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
    [28, 14, 8, 44],
  );

  if (sections.has("사용자 지표")) {
    writeDataSheet(
      wb,
      "사용자 지표",
      [...meta, ...rangeMetaExtra],
      ["지표", "값", "단위", "비고"],
      [
        ["기간 내 활성 사용자 합", rangeTotal.activeUsers, "명", "일별 합계 (중복 제거 없음, 참고용)"],
        ["기간 내 신규 가입자", rangeTotal.newSignups, "명", `${periodStart} ~ ${periodEnd}`],
        ["기간 내 누적 제보", rangeTotal.reports, "건", `${periodStart} ~ ${periodEnd}`],
        ["오늘 활성 사용자", realtimeMetrics?.activeToday ?? 0, "명", "실시간 지표 · 스냅샷"],
        ["WAU (최근 7일)", kpiMetrics?.wauCurrent ?? 0, "명", "KPI · 스냅샷"],
        ["총 가입자", users.length, "명", "내보내기 시점 스냅샷"],
        ["오너 등록 매장 수", partneredCount, "개", "내보내기 시점 스냅샷 (제보 대상 기준)"],
        ["전체 매장 수", restaurants.length, "개", "내보내기 시점 스냅샷"],
      ],
      [26, 12, 8, 40],
    );
  }

  if (sections.has("리텐션")) {
    writeDataSheet(
      wb,
      "리텐션",
      [...meta, ...rangeMetaExtra],
      ["날짜", "활성 사용자", "점심시간 사용자", "신규 가입자"],
      dailyRows.map((d) => [d.day, d.activeUsers, d.lunchUsers, d.newSignups]),
      [14, 14, 16, 14],
    );
  }

  if (sections.has("시간대 분석")) {
    writeDataSheet(
      wb,
      "시간대 분석",
      [...meta, ...rangeMetaExtra, ["참고", "날짜 × 시간대(0~23시, KST) 단위 세부 집계"]],
      ["날짜", "시", "활성 사용자", "제보 수", "상세 조회 수"],
      hourlyRows.map((h) => [h.day, h.hour, h.activeUsers, h.reports, h.detailViews]),
      [14, 6, 14, 12, 14],
    );
  }

  if (sections.has("전환 지표")) {
    writeDataSheet(
      wb,
      "전환 지표",
      meta,
      ["날짜", "배너 노출", "배너 클릭", "배너 CTR(%)", "푸시 발송", "푸시 오픈", "푸시 오픈율(%)"],
      dailyRows.map((d) => {
        const ctr = d.bannerImpressions > 0 ? Math.round((d.bannerClicks / d.bannerImpressions) * 1000) / 10 : 0;
        const pushRate = d.pushDelivered > 0 ? Math.round((d.pushClicks / d.pushDelivered) * 1000) / 10 : 0;
        return [d.day, d.bannerImpressions, d.bannerClicks, ctr, d.pushDelivered, d.pushClicks, pushRate];
      }),
      [14, 12, 12, 12, 12, 12, 14],
    );
  }

  if (sections.has("오너 참여 현황")) {
    writeDataSheet(
      wb,
      "오너 참여 현황",
      [...meta, ["등록 요약", `${partneredCount} / ${crowdEnabledRestaurants.length} 매장 (내보내기 시점 스냅샷, 기간 필터 미적용)`]],
      ["매장명", "구역", "카테고리", "오너등록"],
      restaurantsSorted
        .filter((r) => r.crowdEnabled)
        .map((r) => [r.name, r.area, r.category, r.ownerId ? "등록" : "미등록"]),
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
        "기간 내 합계",
        "제보 참여자수",
        "누적제보(전체기간)",
      ],
      restaurantRows.map((r) => [
        r.name,
        r.area,
        r.reportsRelaxed,
        r.reportsModerate,
        r.reportsFull,
        r.reportsTotal,
        r.reportParticipants,
        totalReports(
          restaurants.find((rr) => rr.id === r.restaurantId) ?? ({ reports: {} } as AdminRestaurant),
        ),
      ]),
      [22, 8, 10, 10, 10, 12, 12, 14],
    );
  }

  if (sections.has("매장 현황")) {
    writeDataSheet(
      wb,
      "매장 현황",
      [...meta, ["기준", "내보내기 시점 스냅샷 (기간 필터 미적용)"]],
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
        ["기준", "내보내기 시점 스냅샷 (기간 필터 미적용, 전체 기간 누적)"],
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
