export type UserRole = "user" | "owner" | "admin";

export interface AdminUser {
  id: string;
  email: string | null;
  nickname: string;
  role: UserRole;
  provider: string | null;
  createdAt: Date;
  lastLoginAt: Date | null;
  crowdReportCount: number;
  totalStamps: number;
  isOwner: boolean;
}

export function roleLabel(role: UserRole): string {
  switch (role) {
    case "admin":
      return "관리자";
    case "owner":
      return "사장님";
    default:
      return "일반";
  }
}

export function parseAdminUser(raw: Record<string, unknown>): AdminUser {
  return {
    id: String(raw.id),
    email: raw.email != null ? String(raw.email) : null,
    nickname: String(raw.nickname ?? "사용자"),
    role: (String(raw.role ?? "user") as UserRole) || "user",
    provider: raw.provider != null ? String(raw.provider) : null,
    createdAt: new Date(String(raw.created_at)),
    lastLoginAt: raw.last_login_at
      ? new Date(String(raw.last_login_at))
      : null,
    crowdReportCount: Number(raw.crowd_report_count ?? 0) || 0,
    totalStamps: Number(raw.total_stamps ?? 0) || 0,
    isOwner: Boolean(raw.is_owner),
  };
}
