# Campus Lunch Admin Web

Flutter 앱 어드민 화면과 동일한 기능을 제공하는 React 관리자 웹입니다.

## 기능

| 탭 | 기능 |
|---|---|
| **핵심 지표** | DAU/MAU, 제보·클릭률·푸시 KPI, 차트, 오너 등록 현황, 혼잡도 계산(사장님 영향력), CSV 내보내기 |
| **매장 관리** | 검색, 추가/수정/삭제, 최근 제보, 사장님 코드 발급 |
| **인기 관리** | 알고리즘/수동 순위 토글, 수동 순위 조정 |
| **지도 등록** | Google Places 검색 → DB 등록 + 6자리 인증번호 |
| **기프티콘** | 목록 조회, 이미지 업로드 후 등록 |

## 로컬 실행

```bash
cd admin-web
npm install
npm run dev
```

브라우저: http://localhost:5174

## 환경 변수

`admin-web/.env` 또는 상위 `campuslunch-app/.env`:

| 변수 | 설명 |
|---|---|
| `VITE_SUPABASE_URL` / `SUPABASE_URL` | Supabase 프로젝트 URL |
| `VITE_SUPABASE_ANON_KEY` / `SUPABASE_ANON_KEY` | anon key |
| `VITE_GOOGLE_MAPS_API_KEY` / `GOOGLE_MAPS_API_KEY` | 지도 등록 탭 (Places + Embed) |

Vercel/Netlify 배포 시 `VITE_*` 변수를 프로젝트 설정에 추가하세요.

## 로그인

Supabase `profiles.role = 'admin'` 계정으로 이메일 로그인합니다.

## 배포

- **Vercel**: Root Directory = `admin-web`, Build = `npm run build`, Output = `dist`
- **Netlify**: `admin-web/netlify.toml` 참고

## 보안

프로덕션 공개 전 `supabase/admin_dashboard_secure.sql` 적용을 권장합니다 (`is_admin()` RPC 보호).
