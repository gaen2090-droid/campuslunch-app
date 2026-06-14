import { useCallback, useEffect, useState } from "react";
import type { Session, User } from "@supabase/supabase-js";
import { isAdminUser, isSupabaseConfigured, supabase } from "../lib/supabase";

export function useAuth() {
  const [session, setSession] = useState<Session | null>(null);
  const [user, setUser] = useState<User | null>(null);
  const [isAdmin, setIsAdmin] = useState(false);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  const refreshAdmin = useCallback(async (u: User | null) => {
    if (!u) {
      setIsAdmin(false);
      return;
    }
    setIsAdmin(await isAdminUser(u.id));
  }, []);

  useEffect(() => {
    if (!isSupabaseConfigured()) {
      setError("Supabase 설정이 없습니다. 상위 .env 를 확인하세요.");
      setLoading(false);
      return;
    }

    supabase.auth.getSession().then(({ data }) => {
      setSession(data.session);
      setUser(data.session?.user ?? null);
      refreshAdmin(data.session?.user ?? null).finally(() => setLoading(false));
    });

    const {
      data: { subscription },
    } = supabase.auth.onAuthStateChange((_event, nextSession) => {
      setSession(nextSession);
      setUser(nextSession?.user ?? null);
      refreshAdmin(nextSession?.user ?? null);
    });

    return () => subscription.unsubscribe();
  }, [refreshAdmin]);

  const signIn = async (email: string, password: string) => {
    setError(null);
    const { data, error: signInError } = await supabase.auth.signInWithPassword({
      email: email.trim(),
      password,
    });
    if (signInError) {
      setError(signInError.message);
      return false;
    }
    const admin = data.user ? await isAdminUser(data.user.id) : false;
    if (!admin) {
      await supabase.auth.signOut();
      setError("관리자(role=admin) 계정만 접속할 수 있습니다.");
      return false;
    }
    return true;
  };

  const signOut = async () => {
    await supabase.auth.signOut();
  };

  return { session, user, isAdmin, loading, error, signIn, signOut, setError };
}
