# 캠퍼스런치 출시 설정 가이드

## 1. 환경 변수 (private repo — Git 포함)

`git pull` 시 아래 파일이 함께 옵니다:

- `.env` — 앱 설정
- `.env.secrets` — 시드 스크립트용 Secret
- `android/keys.properties` — Android 네이티브 API 키
- `ios/Flutter/Secrets.xcconfig` — iOS 네이티브 API 키

`.env` 수정 후 네이티브 키 동기화:

```bash
dart run tool/sync_env_to_native.dart
```

## 2. Supabase SQL (Dashboard → SQL Editor)

순서대로 실행:

1. `supabase/users_auth.sql` — 회원 `public.users` + Auth 트리거
2. `supabase/policies.sql` — RLS
3. `supabase/rpc_email_signup_status.sql`
4. `supabase/rpc_claim_owner.sql`
5. `supabase/rpc_delete_own_account.sql`

## 3. 이메일 회원가입 인증 (6자리 OTP)

1. `supabase/rpc_email_signup_status.sql` 실행
2. `docs/EMAIL_OTP_SETUP.md` — Magic Link OTP 템플릿 (`dart run tool/apply_supabase_email_templates.dart`)
3. `docs/SMTP_SETUP.md` — Resend SMTP (`dart run tool/setup_supabase_smtp.dart`) — 메일 한도 해제

## 4. 관리자 계정

Supabase Dashboard → Authentication → Users 에서 관리자 생성 후  
**App Metadata** (또는 User Metadata)에 추가:

```json
{ "role": "admin" }
```

앱에서는 **이 계정으로 Supabase 로그인**해야 지도 등록·매장 수정이 동작합니다.  
디버그 로컬 계정(`owner`/`user`)은 **디버그 빌드에서만** 동작하며 DB 쓰기 권한이 없습니다.

## 5. API 키 보안

- **private repo 전제**로 키 파일을 Git에 포함함 (public 전환 시 제거·재발급)
- Google Cloud Console 키 제한: iOS Bundle ID, Android SHA-1 + 패키지명
- 저장소 공개·퇴사 시 키 **로테이션** 권장

## 6. 혼잡도 제보

- DB 제보는 **로그인(authenticated)** 사용자만 가능 (`user` / `owner` 소스)
- 영업시간 외 **영업안함** 표시는 앱에서 계산 (DB에 `system` 제보를 넣지 않음)
