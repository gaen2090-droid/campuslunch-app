import { useState, type FormEvent } from "react";
import { isSupabaseConfigured } from "../lib/supabase";

interface Props {
  onSignIn: (email: string, password: string) => Promise<boolean>;
  error: string | null;
}

export function LoginPage({ onSignIn, error }: Props) {
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [loading, setLoading] = useState(false);

  const handleSubmit = async (e: FormEvent) => {
    e.preventDefault();
    setLoading(true);
    await onSignIn(email, password);
    setLoading(false);
  };

  return (
    <div className="login-page">
      <form className="login-card" onSubmit={handleSubmit}>
        <p className="eyebrow">Campus Lunch Admin</p>
        <h1>관리자 로그인</h1>
        <p className="muted">
          Supabase Auth 계정 중 <code>public.users.role = admin</code> 만
          접속할 수 있습니다.
        </p>

        {!isSupabaseConfigured() && (
          <div className="alert">상위 폴더 .env 에 SUPABASE_URL / ANON_KEY 가 필요합니다.</div>
        )}

        <label>
          이메일
          <input
            type="email"
            value={email}
            onChange={(e) => setEmail(e.target.value)}
            placeholder="admin@example.com"
            required
          />
        </label>
        <label>
          비밀번호
          <input
            type="password"
            value={password}
            onChange={(e) => setPassword(e.target.value)}
            required
          />
        </label>

        {error && <div className="alert">{error}</div>}

        <button type="submit" className="btn primary" disabled={loading}>
          {loading ? "로그인 중…" : "로그인"}
        </button>
      </form>
    </div>
  );
}
