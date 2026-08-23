export type NewsPushTarget = "all" | "owners_only";

export interface ScheduledNewsPush {
  id: string;
  title: string;
  body: string;
  scheduledAt: Date;
  status: "pending" | "sent" | "cancelled" | "failed";
  sentAt: Date | null;
  createdAt: Date;
  target: NewsPushTarget;
}

export function parseScheduledNewsPush(raw: Record<string, unknown>): ScheduledNewsPush {
  return {
    id: String(raw.id ?? ""),
    title: String(raw.title ?? ""),
    body: String(raw.body ?? ""),
    scheduledAt: new Date(String(raw.scheduled_at ?? "")),
    status: (String(raw.status ?? "pending") as ScheduledNewsPush["status"]),
    sentAt: raw.sent_at ? new Date(String(raw.sent_at)) : null,
    createdAt: new Date(String(raw.created_at ?? "")),
    target: raw.target === "owners_only" ? "owners_only" : "all",
  };
}

export interface PeakPushSchedule {
  id: string;
  label: string;
  enabled: boolean;
  hour: number;
  minute: number;
  /** 즐겨찾기 중 여유로운 매장이 있을 때 사용. {restaurant} 치환 가능 */
  titleTemplate: string;
  bodyTemplate: string;
  /** 즐겨찾기가 없거나, 있어도 여유로운 곳이 없을 때 사용하는 고정 홍보 문구 */
  fallbackTitleTemplate: string;
  fallbackBodyTemplate: string;
}

export interface PushNotificationConfig {
  schedules: PeakPushSchedule[];
  /** @deprecated 하위 호환 — schedules[0] 기준 */
  lunchHour: number;
  lunchMinute: number;
  dinnerHour: number;
  dinnerMinute: number;
  titleTemplate: string;
  bodyTemplate: string;
  weekdaysOnly: boolean;
  scheduleDaysAhead: number;
  peakFcmEnabled: boolean;
  communityFcmEnabled: boolean;
  peakLocalScheduleEnabled: boolean;
  communityCommentTitleTemplate: string;
  communityCommentBodyTemplate: string;
  communityReplyTitleTemplate: string;
  communityReplyBodyTemplate: string;
  newsFcmEnabled: boolean;
  peakExcludeOwners: boolean;
  newsExcludeOwners: boolean;
  updatedAt: Date | null;
}

export const DEFAULT_PEAK_SCHEDULES: PeakPushSchedule[] = [
  {
    id: "lunch",
    label: "점심",
    enabled: true,
    hour: 12,
    minute: 0,
    titleTemplate: "{restaurant}에서 대기없이 식사할 수 있어요",
    bodyTemplate: "다른 매장도 확인해보기 >",
    fallbackTitleTemplate: "대기 없이 식사할 수 있어요",
    fallbackBodyTemplate: "지금 바로 입장 가능한 매장을 확인해보세요\n확인하러 가기 >",
  },
  {
    id: "dinner",
    label: "저녁",
    enabled: true,
    hour: 18,
    minute: 0,
    titleTemplate: "{restaurant}에서 대기없이 식사할 수 있어요",
    bodyTemplate: "다른 매장도 확인해보기 >",
    fallbackTitleTemplate: "대기 없이 식사할 수 있어요",
    fallbackBodyTemplate: "지금 바로 입장 가능한 매장을 확인해보세요\n확인하러 가기 >",
  },
];

export const DEFAULT_PUSH_CONFIG: PushNotificationConfig = {
  schedules: DEFAULT_PEAK_SCHEDULES.map((s) => ({ ...s })),
  lunchHour: 12,
  lunchMinute: 0,
  dinnerHour: 18,
  dinnerMinute: 0,
  titleTemplate: DEFAULT_PEAK_SCHEDULES[0].titleTemplate,
  bodyTemplate: DEFAULT_PEAK_SCHEDULES[0].bodyTemplate,
  weekdaysOnly: true,
  scheduleDaysAhead: 14,
  peakFcmEnabled: false,
  communityFcmEnabled: true,
  peakLocalScheduleEnabled: true,
  communityCommentTitleTemplate: "{nickname}님이 댓글을 남겼어요",
  communityCommentBodyTemplate: "{content}",
  communityReplyTitleTemplate: "{nickname}님이 답글을 남겼어요",
  communityReplyBodyTemplate: "{content}",
  newsFcmEnabled: true,
  peakExcludeOwners: false,
  newsExcludeOwners: false,
  updatedAt: null,
};

export interface PushOpsSnapshot {
  tokenCount: number;
  uniqueUsersWithToken: number;
  /** @deprecated 알림 ON만 (토큰 유무 무시) — UI는 reachable* 사용 */
  peakLunchOn: number;
  peakDinnerOn: number;
  communityOn: number;
  lunchUsers: number;
  lunchDevices: number;
  dinnerUsers: number;
  dinnerDevices: number;
  communityUsers: number;
  communityDevices: number;
  rewardUsers: number;
  rewardDevices: number;
  newsUsers: number;
  newsDevices: number;
  /** 설정 전파 시 FCM 시도 건수(= 전체 토큰) */
  configRefreshDevices: number;
  lastPeakSent: Array<{ sentDate: string; slot: string; createdAt: string }>;
}

export const EMPTY_PUSH_OPS: PushOpsSnapshot = {
  tokenCount: 0,
  uniqueUsersWithToken: 0,
  peakLunchOn: 0,
  peakDinnerOn: 0,
  communityOn: 0,
  lunchUsers: 0,
  lunchDevices: 0,
  dinnerUsers: 0,
  dinnerDevices: 0,
  communityUsers: 0,
  communityDevices: 0,
  rewardUsers: 0,
  rewardDevices: 0,
  newsUsers: 0,
  newsDevices: 0,
  configRefreshDevices: 0,
  lastPeakSent: [],
};

function stripGatePlaceholder(text: string): string {
  return text.replaceAll("{gate}", "").replaceAll(/\s{2,}/g, " ").trim();
}

function parseSchedule(
  raw: Record<string, unknown>,
  fallback: PeakPushSchedule,
): PeakPushSchedule {
  const readInt = (key: string, fb: number) => {
    const v = raw[key];
    if (typeof v === "number") return v;
    const n = Number.parseInt(String(v ?? ""), 10);
    return Number.isFinite(n) ? n : fb;
  };
  const title = String(raw.title_template ?? raw.titleTemplate ?? "").trim();
  const body = String(raw.body_template ?? raw.bodyTemplate ?? "").trim();
  const fallbackTitle = String(
    raw.fallback_title_template ?? raw.fallbackTitleTemplate ?? "",
  ).trim();
  const fallbackBody = String(
    raw.fallback_body_template ?? raw.fallbackBodyTemplate ?? "",
  ).trim();
  return {
    id: String(raw.id ?? fallback.id).trim() || fallback.id,
    label: String(raw.label ?? fallback.label).trim() || fallback.label,
    enabled: raw.enabled === undefined ? fallback.enabled : Boolean(raw.enabled),
    hour: Math.min(23, Math.max(0, readInt("hour", fallback.hour))),
    minute: Math.min(59, Math.max(0, readInt("minute", fallback.minute))),
    titleTemplate: title
      ? stripGatePlaceholder(title) || fallback.titleTemplate
      : fallback.titleTemplate,
    bodyTemplate: body
      ? stripGatePlaceholder(body) || fallback.bodyTemplate
      : fallback.bodyTemplate,
    fallbackTitleTemplate: fallbackTitle
      ? stripGatePlaceholder(fallbackTitle) || fallback.fallbackTitleTemplate
      : fallback.fallbackTitleTemplate,
    fallbackBodyTemplate: fallbackBody
      ? stripGatePlaceholder(fallbackBody) || fallback.fallbackBodyTemplate
      : fallback.fallbackBodyTemplate,
  };
}

function schedulesFromLegacy(raw: Record<string, unknown>): PeakPushSchedule[] {
  const readInt = (key: string, fallback: number) => {
    const v = raw[key];
    if (typeof v === "number") return v;
    const n = Number.parseInt(String(v ?? ""), 10);
    return Number.isFinite(n) ? n : fallback;
  };
  const titleRaw = String(raw.title_template ?? "").trim();
  const bodyRaw = String(raw.body_template ?? "").trim();
  const fallbackTitle =
    stripGatePlaceholder(titleRaw) || DEFAULT_PEAK_SCHEDULES[0].fallbackTitleTemplate;
  const fallbackBody =
    stripGatePlaceholder(bodyRaw) || DEFAULT_PEAK_SCHEDULES[0].fallbackBodyTemplate;
  return [
    {
      id: "lunch",
      label: "점심",
      enabled: true,
      hour: readInt("lunch_hour", 12),
      minute: readInt("lunch_minute", 0),
      titleTemplate: DEFAULT_PEAK_SCHEDULES[0].titleTemplate,
      bodyTemplate: DEFAULT_PEAK_SCHEDULES[0].bodyTemplate,
      fallbackTitleTemplate: fallbackTitle,
      fallbackBodyTemplate: fallbackBody,
    },
    {
      id: "dinner",
      label: "저녁",
      enabled: true,
      hour: readInt("dinner_hour", 18),
      minute: readInt("dinner_minute", 0),
      titleTemplate: DEFAULT_PEAK_SCHEDULES[1].titleTemplate,
      bodyTemplate: DEFAULT_PEAK_SCHEDULES[1].bodyTemplate,
      fallbackTitleTemplate: fallbackTitle,
      fallbackBodyTemplate: fallbackBody,
    },
  ];
}

export function parsePushConfig(raw: Record<string, unknown>): PushNotificationConfig {
  const readInt = (key: string, fallback: number) => {
    const v = raw[key];
    if (typeof v === "number") return v;
    const n = Number.parseInt(String(v ?? ""), 10);
    return Number.isFinite(n) ? n : fallback;
  };
  const readBool = (key: string, fallback: boolean) => {
    if (raw[key] === undefined) return fallback;
    return Boolean(raw[key]);
  };
  const readText = (key: string, fallback: string) => {
    const s = String(raw[key] ?? "").trim();
    return s || fallback;
  };

  let schedules: PeakPushSchedule[];
  if (Array.isArray(raw.peak_schedules) && raw.peak_schedules.length > 0) {
    schedules = raw.peak_schedules.map((row, i) =>
      parseSchedule(
        (row ?? {}) as Record<string, unknown>,
        DEFAULT_PEAK_SCHEDULES[Math.min(i, DEFAULT_PEAK_SCHEDULES.length - 1)],
      ),
    );
  } else {
    schedules = schedulesFromLegacy(raw);
  }

  const first = schedules[0] ?? DEFAULT_PEAK_SCHEDULES[0];
  const lunch = schedules.find((s) => s.id === "lunch") ?? first;
  const dinner =
    schedules.find((s) => s.id === "dinner") ??
    schedules[1] ??
    DEFAULT_PEAK_SCHEDULES[1];

  return {
    schedules,
    lunchHour: lunch.hour,
    lunchMinute: lunch.minute,
    dinnerHour: dinner.hour,
    dinnerMinute: dinner.minute,
    titleTemplate: first.titleTemplate,
    bodyTemplate: first.bodyTemplate,
    weekdaysOnly:
      raw.weekdays_only === undefined
        ? DEFAULT_PUSH_CONFIG.weekdaysOnly
        : Boolean(raw.weekdays_only),
    scheduleDaysAhead: readInt(
      "schedule_days_ahead",
      DEFAULT_PUSH_CONFIG.scheduleDaysAhead,
    ),
    peakFcmEnabled: readBool(
      "peak_fcm_enabled",
      DEFAULT_PUSH_CONFIG.peakFcmEnabled,
    ),
    communityFcmEnabled: readBool(
      "community_fcm_enabled",
      DEFAULT_PUSH_CONFIG.communityFcmEnabled,
    ),
    peakLocalScheduleEnabled: readBool(
      "peak_local_schedule_enabled",
      DEFAULT_PUSH_CONFIG.peakLocalScheduleEnabled,
    ),
    communityCommentTitleTemplate: readText(
      "community_comment_title_template",
      DEFAULT_PUSH_CONFIG.communityCommentTitleTemplate,
    ),
    communityCommentBodyTemplate: readText(
      "community_comment_body_template",
      DEFAULT_PUSH_CONFIG.communityCommentBodyTemplate,
    ),
    communityReplyTitleTemplate: readText(
      "community_reply_title_template",
      DEFAULT_PUSH_CONFIG.communityReplyTitleTemplate,
    ),
    communityReplyBodyTemplate: readText(
      "community_reply_body_template",
      DEFAULT_PUSH_CONFIG.communityReplyBodyTemplate,
    ),
    newsFcmEnabled: readBool("news_fcm_enabled", DEFAULT_PUSH_CONFIG.newsFcmEnabled),
    peakExcludeOwners: readBool(
      "peak_exclude_owners",
      DEFAULT_PUSH_CONFIG.peakExcludeOwners,
    ),
    newsExcludeOwners: readBool(
      "news_exclude_owners",
      DEFAULT_PUSH_CONFIG.newsExcludeOwners,
    ),
    updatedAt: raw.updated_at ? new Date(String(raw.updated_at)) : null,
  };
}

export function schedulesToJson(schedules: PeakPushSchedule[]) {
  return schedules.map((s) => ({
    id: s.id,
    label: s.label,
    enabled: s.enabled,
    hour: s.hour,
    minute: s.minute,
    title_template: s.titleTemplate,
    body_template: s.bodyTemplate,
    fallback_title_template: s.fallbackTitleTemplate,
    fallback_body_template: s.fallbackBodyTemplate,
  }));
}

export function newPeakSchedule(index: number): PeakPushSchedule {
  return {
    id: `slot_${Date.now()}_${index}`,
    label: `알림 ${index + 1}`,
    enabled: true,
    hour: 12,
    minute: 0,
    titleTemplate: DEFAULT_PEAK_SCHEDULES[0].titleTemplate,
    bodyTemplate: DEFAULT_PEAK_SCHEDULES[0].bodyTemplate,
    fallbackTitleTemplate: DEFAULT_PEAK_SCHEDULES[0].fallbackTitleTemplate,
    fallbackBodyTemplate: DEFAULT_PEAK_SCHEDULES[0].fallbackBodyTemplate,
  };
}

export function parsePushOpsSnapshot(raw: Record<string, unknown>): PushOpsSnapshot {
  const last = Array.isArray(raw.last_peak_sent) ? raw.last_peak_sent : [];
  const tokenCount = Number(raw.token_count ?? 0);
  return {
    tokenCount,
    uniqueUsersWithToken: Number(raw.unique_users_with_token ?? 0),
    peakLunchOn: Number(raw.peak_lunch_on ?? 0),
    peakDinnerOn: Number(raw.peak_dinner_on ?? 0),
    communityOn: Number(raw.community_on ?? 0),
    lunchUsers: Number(raw.lunch_users ?? 0),
    lunchDevices: Number(raw.lunch_devices ?? 0),
    dinnerUsers: Number(raw.dinner_users ?? 0),
    dinnerDevices: Number(raw.dinner_devices ?? 0),
    communityUsers: Number(raw.community_users ?? 0),
    communityDevices: Number(raw.community_devices ?? 0),
    rewardUsers: Number(raw.reward_users ?? 0),
    rewardDevices: Number(raw.reward_devices ?? 0),
    newsUsers: Number(raw.news_users ?? 0),
    newsDevices: Number(raw.news_devices ?? 0),
    configRefreshDevices: Number(
      raw.config_refresh_devices ?? raw.token_count ?? 0,
    ),
    lastPeakSent: last.map((row) => {
      const r = row as Record<string, unknown>;
      return {
        sentDate: String(r.sent_date ?? ""),
        slot: String(r.slot ?? ""),
        createdAt: String(r.created_at ?? ""),
      };
    }),
  };
}

export function formatTime(hour: number, minute: number): string {
  return `${String(hour).padStart(2, "0")}:${String(minute).padStart(2, "0")}`;
}

const PREVIEW_NICK = "김캠퍼스";
const PREVIEW_CONTENT = "오늘 여기 괜찮았어요!";
const PREVIEW_POST = "점심 뭐 먹지 고민될 때…";

export function previewCommunityTemplate(template: string): string {
  return template
    .replaceAll("{nickname}", PREVIEW_NICK)
    .replaceAll("{content}", PREVIEW_CONTENT)
    .replaceAll("{post_preview}", PREVIEW_POST);
}
