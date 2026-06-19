import path from "node:path";
import { defineConfig, loadEnv } from "vite";
import react from "@vitejs/plugin-react";

/**
 * 환경 변수 우선순위:
 * 1) admin-web/.env.* 의 VITE_*
 * 2) CI(Vercel/Netlify)에 설정한 VITE_*
 * 3) 로컬 편의: 상위 campuslunch-app/.env
 */
export default defineConfig(({ mode }) => {
  const localEnv = loadEnv(mode, __dirname, "VITE_");
  const rootEnv = loadEnv(mode, path.resolve(__dirname, ".."), "");

  const supabaseUrl =
    localEnv.VITE_SUPABASE_URL || rootEnv.SUPABASE_URL || "";
  const supabaseAnonKey =
    localEnv.VITE_SUPABASE_ANON_KEY || rootEnv.SUPABASE_ANON_KEY || "";
  const kakaoRestApiKey =
    localEnv.VITE_KAKAO_REST_API_KEY || rootEnv.KAKAO_REST_API_KEY || "";
  const kakaoJavascriptKey =
    localEnv.VITE_KAKAO_JAVASCRIPT_KEY || rootEnv.KAKAO_JAVASCRIPT_KEY || "";
  const googleMapsApiKey =
    localEnv.VITE_GOOGLE_MAPS_API_KEY || rootEnv.GOOGLE_MAPS_API_KEY || "";

  return {
    plugins: [react()],
    define: {
      "import.meta.env.VITE_SUPABASE_URL": JSON.stringify(supabaseUrl),
      "import.meta.env.VITE_SUPABASE_ANON_KEY": JSON.stringify(supabaseAnonKey),
      "import.meta.env.VITE_KAKAO_REST_API_KEY": JSON.stringify(kakaoRestApiKey),
      "import.meta.env.VITE_KAKAO_JAVASCRIPT_KEY": JSON.stringify(kakaoJavascriptKey),
      "import.meta.env.VITE_GOOGLE_MAPS_API_KEY": JSON.stringify(googleMapsApiKey),
    },
    server: {
      port: 5174,
    },
  };
});
