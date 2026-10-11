/** admin_app_version_stats() RPC 응답 1행 */
export type AppPlatform = "ios" | "android" | "unknown";

export interface AppVersionStat {
  platform: AppPlatform;
  /** 버전을 보고하지 않은 사용자는 null (이 기능이 들어간 빌드를 아직 안 쓴 사용자) */
  appVersion: string | null;
  userCount: number;
}

export const PLATFORM_LABEL: Record<AppPlatform, string> = {
  ios: "iOS",
  android: "Android",
  unknown: "미확인",
};

export function parseAppVersionStat(raw: Record<string, unknown>): AppVersionStat {
  const platform = raw.platform === "ios" || raw.platform === "android" ? raw.platform : "unknown";
  return {
    platform,
    appVersion: raw.app_version == null ? null : String(raw.app_version),
    userCount: Number(raw.user_count ?? 0),
  };
}

/** "1.0.10" > "1.0.9" 같은 숫자 비교용 (내림차순 정렬에 사용) */
export function compareVersionDesc(a: string | null, b: string | null): number {
  if (a === b) return 0;
  if (a === null) return 1; // 미확인은 맨 뒤
  if (b === null) return -1;
  const pa = a.split(".").map((n) => Number(n) || 0);
  const pb = b.split(".").map((n) => Number(n) || 0);
  for (let i = 0; i < Math.max(pa.length, pb.length); i++) {
    const d = (pb[i] ?? 0) - (pa[i] ?? 0);
    if (d !== 0) return d;
  }
  return 0;
}
