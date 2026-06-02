# 캠퍼스런치 출시 설정 가이드

## 1. 환경 변수 (Git 커밋 금지)

`.env.example`을 복사해 `.env` 작성:

```bash
SUPABASE_URL=https://xxxx.supabase.co
SUPABASE_ANON_KEY=sb_publishable_...
GOOGLE_MAPS_API_KEY=...
```

시드/관리 스크립트용 Secret은 `.env.secrets` (앱 번들에 넣지 않음):

```bash
SUPABASE_SECRET_KEY=sb_secret_...
```

네이티브(iOS/Android)에 Maps 키 동기화:

```bash
dart run tool/sync_env_to_native.dart
```

## 2. Supabase SQL (Dashboard → SQL Editor)

순서대로 실행:

1. `supabase/profiles.sql` — 회원 프로필 테이블 + 가입 트리거
2. `supabase/policies.sql` — RLS (활성 매장만 조회, 제보는 로그인 사용자, 매장 CUD는 관리자만)
3. `supabase/rpc_claim_owner.sql` — 사장님 6자리 코드 인증 RPC

## 3. 이메일 회원가입 인증 (웹 배포 없음)

[`docs/DEPLOY_AUTH_WEB.md`](DEPLOY_AUTH_WEB.md) 참고.

1. `supabase/rpc_email_signup_status.sql` 실행
2. Supabase → **URL Configuration**: Site URL · Redirect = `campuslunch://login-callback` (`localhost` 삭제)
3. `.env`: `AUTH_REDIRECT_URL=campuslunch://login-callback`

메일 링크 → **앱 직접 실행** → 가입 완료 스낵바.

## 4. 관리자 계정

Supabase Dashboard → Authentication → Users 에서 관리자 생성 후  
**App Metadata** (또는 User Metadata)에 추가:

```json
{ "role": "admin" }
```

앱에서는 **이 계정으로 Supabase 로그인**해야 지도 등록·매장 수정이 동작합니다.  
`admin` / `admin123` 은 **디버그 빌드에서만** 로컬 UI 테스트용이며 DB 쓰기 권한이 없습니다.

## 5. API 키 보안

- Google Maps / Supabase Publishable 키는 **저장소에 커밋하지 않음**
- iOS: `ios/Flutter/Secrets.xcconfig` (gitignore)
- Android: `android/local.properties` 의 `GOOGLE_MAPS_API_KEY`
- Google Cloud Console에서 키 제한: iOS Bundle ID, Android SHA-1 + 패키지명
- 채팅/이슈에 노출된 키는 **로테이션** 권장

## 6. 혼잡도 제보

- DB 제보는 **로그인(authenticated)** 사용자만 가능 (`user` / `owner` 소스)
- 영업시간 외 **영업안함** 표시는 앱에서 계산 (DB에 `system` 제보를 넣지 않음)
