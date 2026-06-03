# 이메일 인증 — 6자리 인증번호 (OTP)

앱은 메일 **링크 클릭 없이** 가입 화면에서 **6자리 숫자**를 입력합니다.

> 메일에 **「Confirm email address」 링크만** 오면 → Supabase **Magic Link** 템플릿이 아직 기본값입니다.  
> 앱 코드만으로는 메일 내용이 바뀌지 **않습니다.**

## 앱이 쓰는 메일 템플릿

| 동작 | Supabase API | Dashboard 템플릿 |
|------|----------------|------------------|
| 회원가입 / 인증번호 재발송 | `signInWithOtp` | **Magic Link** |
| (예전 가입자 호환) | `verifyOTP(signup)` | Confirm signup |

**지금 가입 메일은 Magic Link 템플릿**을 사용합니다. Confirm signup만 바꿔도 새 가입 메일은 바뀌지 않을 수 있습니다.

## 1. 자동 적용 (권장)

1. [Access Tokens](https://supabase.com/dashboard/account/tokens)에서 토큰 발급
2. `.env.secrets`에 추가:

   ```
   SUPABASE_ACCESS_TOKEN=sbp_...
   ```

3. 실행:

   ```bash
   dart run tool/apply_supabase_email_templates.dart
   ```

Magic Link · Confirm signup 둘 다 `{{ .Token }}` 만 보이도록 설정되고, OTP 길이 6으로 맞춰집니다.

## 2. Supabase Dashboard (수동)

### A. Magic Link (필수 — 가입 메일)

**Authentication → Email Templates → Magic Link**

1. **Subject**: `supabase/email_templates/magic_link_subject.txt`  
   `[캠퍼스런치] 가입 인증번호`

2. **Body (HTML)**: `supabase/email_templates/magic_link.html` 전체 붙여넣기

3. **삭제**: `{{ .ConfirmationURL }}`, `<a href=...>`, 「Confirm / 링크」 버튼

4. **Save**

### B. Confirm signup (선택 — 예전 signUp 가입자)

**Authentication → Email Templates → Confirm signup**

- Body: `supabase/email_templates/confirm_signup.html`
- Subject: `supabase/email_templates/confirm_signup_subject.txt`
- 링크 변수·버튼 제거 후 **Save**

### C. OTP 길이

**Authentication** 설정에서 **Mailer OTP length** = `6`

### D. Confirm email

**Authentication → Providers → Email** → **Confirm email** = ON

## 3. 적용 확인

1. 템플릿 **Save** 또는 스크립트 실행 후
2. **새 이메일**로 회원가입 (기존 주소는 메일이 안 갈 수 있음)
3. 메일 제목이 `[캠퍼스런치] 가입 인증번호`이고 본문에 **6자리 숫자**만 있는지 확인
4. 앱 인증 화면에 번호 입력 → **인증하기**

## 4. 앱 동작

- `signInWithOtp(shouldCreateUser: true)` — 6자리 OTP 메일 (Magic Link 템플릿)
- `verifyOTP(type: email)` — 인증 후 `updateUser`로 비밀번호·닉네임 설정
- 예전 `signUp`으로 받은 번호는 `verifyOTP(type: signup)`으로도 시도

## 5. 메일 발송 한도 (Rate limits)

개발 중 「메일 발송 한도」가 뜨면:

```bash
/Users/dongha/develop/flutter/bin/dart run tool/configure_supabase_rate_limits.dart
```

- **OTP·인증 시도**: 시간당 **3600**으로 올림 (이미 `apply_supabase_email_templates`에도 포함)
- **재발송 간격**: `smtp_max_frequency=1` (초)

**시간당 2통 한도** → **Resend SMTP 연동** (필수): `docs/SMTP_SETUP.md`

```bash
/Users/dongha/develop/flutter/bin/dart run tool/setup_supabase_smtp.dart
```

한도만 올리기( SMTP 없음): `tool/configure_supabase_rate_limits.dart`

Dashboard: **Authentication → Rate Limits**에서도 확인 가능합니다.

## 6. 문제 해결

| 증상 | 해결 |
|------|------|
| 여전히 Confirm email address 링크 | **Magic Link** 템플릿 수정 또는 `apply_supabase_email_templates.dart` 실행 |
| 숫자가 안 보임 | Body에 `{{ .Token }}`, OTP length = 6 |
| 인증 실패 | 가장 최근 메일 번호 사용, 만료 후 「다시 받기」 |
| 예전 메일만 링크 | 템플릿 수정 **이후** 새로 가입·재발송 |
