export interface PushNotificationConfig {
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
  updatedAt: Date | null;
}

export const DEFAULT_PUSH_CONFIG: PushNotificationConfig = {
  lunchHour: 12,
  lunchMinute: 0,
  dinnerHour: 18,
  dinnerMinute: 0,
  titleTemplate: "{gate}에서 대기 없이 식사할 수 있어요",
  bodyTemplate: "지금 바로 입장 가능한 매장을 확인해보세요\n확인하러 가기 >",
  weekdaysOnly: true,
  scheduleDaysAhead: 14,
  // 피크는 로컬 예약이 기본, 서버 FCM은 옵션
  peakFcmEnabled: false,
  communityFcmEnabled: true,
  peakLocalScheduleEnabled: true,
  communityCommentTitleTemplate: "{nickname}님이 댓글을 남겼어요",
  communityCommentBodyTemplate: "{content}",
  updatedAt: null,
};

export interface PushOpsSnapshot {
  tokenCount: number;
  uniqueUsersWithToken: number;
  peakLunchOn: number;
  peakDinnerOn: number;
  communityOn: number;
  lastPeakSent: Array<{ sentDate: string; slot: string; createdAt: string }>;
}

export const EMPTY_PUSH_OPS: PushOpsSnapshot = {
  tokenCount: 0,
  uniqueUsersWithToken: 0,
  peakLunchOn: 0,
  peakDinnerOn: 0,
  communityOn: 0,
  lastPeakSent: [],
};

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

  return {
    lunchHour: readInt("lunch_hour", DEFAULT_PUSH_CONFIG.lunchHour),
    lunchMinute: readInt("lunch_minute", DEFAULT_PUSH_CONFIG.lunchMinute),
    dinnerHour: readInt("dinner_hour", DEFAULT_PUSH_CONFIG.dinnerHour),
    dinnerMinute: readInt("dinner_minute", DEFAULT_PUSH_CONFIG.dinnerMinute),
    titleTemplate: readText("title_template", DEFAULT_PUSH_CONFIG.titleTemplate),
    bodyTemplate: readText("body_template", DEFAULT_PUSH_CONFIG.bodyTemplate),
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
    updatedAt: raw.updated_at ? new Date(String(raw.updated_at)) : null,
  };
}

export function parsePushOpsSnapshot(raw: Record<string, unknown>): PushOpsSnapshot {
  const last = Array.isArray(raw.last_peak_sent) ? raw.last_peak_sent : [];
  return {
    tokenCount: Number(raw.token_count ?? 0),
    uniqueUsersWithToken: Number(raw.unique_users_with_token ?? 0),
    peakLunchOn: Number(raw.peak_lunch_on ?? 0),
    peakDinnerOn: Number(raw.peak_dinner_on ?? 0),
    communityOn: Number(raw.community_on ?? 0),
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

export function previewTitle(template: string, gate = "정문"): string {
  return template.replaceAll("{gate}", gate);
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
