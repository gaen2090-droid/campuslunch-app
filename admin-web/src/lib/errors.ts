/**
 * Supabase의 PostgrestError는 Error 인스턴스가 아닌 plain object
 * ({message, details, hint, code})라서 `err instanceof Error` 체크로는
 * 걸러지지 않고 `String(err)`가 "[object Object]"로 떨어진다.
 */
export function errorMessage(err: unknown): string {
  if (err instanceof Error) return err.message;
  if (
    err &&
    typeof err === "object" &&
    "message" in err &&
    typeof (err as { message: unknown }).message === "string"
  ) {
    return (err as { message: string }).message;
  }
  if (typeof err === "string") return err;
  try {
    return JSON.stringify(err);
  } catch {
    return String(err);
  }
}
