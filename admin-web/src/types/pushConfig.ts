export interface PushNotificationConfig {
  lunchHour: number;
  lunchMinute: number;
  dinnerHour: number;
  dinnerMinute: number;
  titleTemplate: string;
  bodyTemplate: string;
  weekdaysOnly: boolean;
  scheduleDaysAhead: number;
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
  updatedAt: null,
};

export function parsePushConfig(raw: Record<string, unknown>): PushNotificationConfig {
  const readInt = (key: string, fallback: number) => {
    const v = raw[key];
    if (typeof v === "number") return v;
    const n = Number.parseInt(String(v ?? ""), 10);
    return Number.isFinite(n) ? n : fallback;
  };

  return {
    lunchHour: readInt("lunch_hour", DEFAULT_PUSH_CONFIG.lunchHour),
    lunchMinute: readInt("lunch_minute", DEFAULT_PUSH_CONFIG.lunchMinute),
    dinnerHour: readInt("dinner_hour", DEFAULT_PUSH_CONFIG.dinnerHour),
    dinnerMinute: readInt("dinner_minute", DEFAULT_PUSH_CONFIG.dinnerMinute),
    titleTemplate:
      String(raw.title_template ?? DEFAULT_PUSH_CONFIG.titleTemplate).trim() ||
      DEFAULT_PUSH_CONFIG.titleTemplate,
    bodyTemplate:
      String(raw.body_template ?? DEFAULT_PUSH_CONFIG.bodyTemplate).trim() ||
      DEFAULT_PUSH_CONFIG.bodyTemplate,
    weekdaysOnly:
      raw.weekdays_only === undefined
        ? DEFAULT_PUSH_CONFIG.weekdaysOnly
        : Boolean(raw.weekdays_only),
    scheduleDaysAhead: readInt(
      "schedule_days_ahead",
      DEFAULT_PUSH_CONFIG.scheduleDaysAhead,
    ),
    updatedAt: raw.updated_at ? new Date(String(raw.updated_at)) : null,
  };
}

export function formatTime(hour: number, minute: number): string {
  return `${String(hour).padStart(2, "0")}:${String(minute).padStart(2, "0")}`;
}

export function previewTitle(template: string, gate = "정문"): string {
  return template.replaceAll("{gate}", gate);
}
