# Supabase 메일 SMTP 연동 (Resend)

기본 Supabase 메일은 **시간당 약 2통**이라 가입 테스트 시 금방 한도에 걸립니다.  
**Resend SMTP**를 쓰면 시간당 **3600통**까지 올릴 수 있습니다.

## 1. Resend API 키 발급 (약 2분)

1. [resend.com](https://resend.com) 가입
2. **API Keys** → **Create API Key** → `re_...` 복사

## 2. 프로젝트에 키 넣기

`.env.secrets`에 추가 (또는 실행 시 터미널에 붙여넣기):

```env
RESEND_API_KEY=re_xxxxxxxx
SMTP_ADMIN_EMAIL=onboarding@resend.dev
SMTP_SENDER_NAME=캠퍼스런치
```

- **도메인 없이 테스트**: `onboarding@resend.dev` (Resend 가입 이메일로만 수신될 수 있음)
- **실서비스**: Resend에서 도메인 인증 후 `SMTP_ADMIN_EMAIL=noreply@yourdomain.com`

## 3. Supabase에 적용 (한 번)

```bash
cd /Users/dongha/StudioProjects/campuslunch-app
/Users/dongha/develop/flutter/bin/dart run tool/setup_supabase_smtp.dart
```

키가 `.env.secrets`에 없으면 터미널에서 `RESEND_API_KEY:` 입력을 요청합니다.

성공 시:

```text
SMTP 연동 완료
  rate_limit_email_sent: 3600 /시간
```

## 4. 확인

1. Supabase Dashboard → **Authentication** → **Emails** → SMTP 켜짐 확인
2. 앱에서 **새 이메일**로 회원가입 → 6자리 인증 메일 수신

## 다른 SMTP 사용 시

`.env.secrets`에 직접 지정:

```env
SMTP_HOST=smtp.example.com
SMTP_PORT=587
SMTP_USER=apikey
SMTP_PASS=secret
SMTP_ADMIN_EMAIL=noreply@yourdomain.com
SMTP_SENDER_NAME=캠퍼스런치
```

`RESEND_API_KEY` 없이 위 값이 모두 있으면 Resend 기본값 대신 사용됩니다.
