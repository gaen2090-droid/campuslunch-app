/**
 * Supabase의 PostgrestError는 Error 인스턴스가 아닌 plain object
 * ({message, details, hint, code})라서 `err instanceof Error` 체크로는
 * 걸러지지 않고 `String(err)`가 "[object Object]"로 떨어진다.
 *
 * 서버(RPC)가 이미 한국어 문장으로 던지는 에러(예: "본인 매장만 수정할 수
 * 있어요.")는 그대로 통과시키되, Postgres 제약 위반처럼 원문 그대로 노출되면
 * 안 되는 로우레벨 메시지는 사람이 읽을 수 있는 문장으로 치환한다.
 */
export function errorMessage(err: unknown): string {
  const raw = extractRawMessage(err);
  return sanitize(raw);
}

function extractRawMessage(err: unknown): string {
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

function sanitize(message: string): string {
  const lower = message.toLowerCase();
  if (
    lower.includes("duplicate key value") ||
    lower.includes("violates unique constraint")
  ) {
    return "이미 등록된 값이에요.";
  }
  if (
    lower.includes("violates foreign key constraint") ||
    lower.includes("violates not-null constraint") ||
    lower.includes("violates check constraint")
  ) {
    return "요청을 처리하지 못했어요. 잠시 후 다시 시도해주세요.";
  }
  return message;
}
