# 이메일 인증 테스트

## 방식

- 가입 시 **6자리 인증번호** 메일 발송 (Supabase 최소 6자리)
- 앱 인증 화면에서 번호 입력 (딥링크/링크 클릭 **사용 안 함**)
- Supabase 설정: `docs/EMAIL_OTP_SETUP.md` 참고

## 메일이 안 올 때

1. Dashboard → **Authentication → Users** 에 유저 생성됐는지
2. 스팸함 확인
3. Supabase 기본 메일 **시간당 3~4통** 제한 → 30분 후 재시도 또는 다른 이메일
4. 이미 가입된 이메일이면 `email_signup_status` RPC 로 차단됨

## 개발용: 가입 막힘 / 「이미 가입된 이메일」

**public.users** 만 Table Editor에서 지우면 **auth.users** 에 이메일이 남아 가입이 막힙니다. (앱 재시작과 무관)

완전 삭제 (택 1):

1. Dashboard → **Authentication → Users** → 해당 유저 삭제  
2. SQL: `supabase/dev_purge_user_by_email.sql` (이메일 수정 후 Run)  
3. 터미널: `dart run tool/purge_auth_user.dart --email=you@example.com`

## 개발용 빠른 테스트

Dashboard → Users → 해당 유저 → **Confirm user**  
→ 앱에서 로그인 (OTP 생략)

## 출시 전

- SMTP 연결 권장 (발송 한도·스팸 개선)
- OTP length = 6 (기본값), 템플릿 `{{ .Token }}` 확인
