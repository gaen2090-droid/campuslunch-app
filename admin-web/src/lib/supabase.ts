import { createClient } from "@supabase/supabase-js";

const url = import.meta.env.VITE_SUPABASE_URL;
const anonKey = import.meta.env.VITE_SUPABASE_ANON_KEY;

if (!url || !anonKey) {
  console.warn(
    "[Admin] SUPABASE_URL / SUPABASE_ANON_KEY 없음. 상위 .env 확인.",
  );
}

export const supabase = createClient(url ?? "", anonKey ?? "");

export function isSupabaseConfigured(): boolean {
  return Boolean(url && anonKey);
}

export async function isAdminUser(userId: string): Promise<boolean> {
  const { data, error } = await supabase
    .from("users")
    .select("role")
    .eq("id", userId)
    .maybeSingle();

  if (error) {
    console.error("[Admin] role check failed:", error.message);
    return false;
  }
  return data?.role === "admin";
}
