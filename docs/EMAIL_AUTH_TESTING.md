# 이메일 인증 테스트 (Android 에뮬레이터 포함)

## 에뮬레이터에서도 됩니다

Android 시뮬레이터/에뮬레이터는 **메일을 막지 않습니다.**  
가입할 때 입력한 주소는 **실제 메일함**(Gmail, 네이버 등)으로 발송됩니다. 에뮬레이터 안에 메일 앱이 없어도, PC/폰에서 같은 메일함을 열면 됩니다.

인증 링크를 누르면 **캠퍼스런치 앱**이 바로 열립니다 (웹사이트 배포 없음).  
가입 완료 안내는 앱 메인 화면 스낵바로 표시됩니다.

이미 가입된 이메일은 **「이미 가입된 이메일」** 로 막고 메일을 보내지 않습니다 (`rpc_email_signup_status.sql`).

---

## 메일이 안 올 때 체크리스트

### 1. Supabase에 가입 요청이 갔는지

Dashboard → **Authentication** → **Users**

- 방금 이메일로 **유저가 생겼는지** 확인
- 없으면: 앱에서 회원가입이 실패한 것 → 앱 빨간 에러 메시지 확인
- 있고 **Confirmed** 가 비어 있으면: 가입은 됐고 **메일만** 문제

### 2. 스팸 / 프로모션함

발신: `noreply@mail.app.supabase.io` (또는 커스텀 SMTP)

### 3. 발송 제한 (무료 플랜)

Supabase **기본 메일**은 시간당 **3~4통** 정도 제한이 있습니다.  
같은 이메일로 여러 번 가입/재발송하면 **안 올 수 있습니다.**

- 30분~1시간 뒤 다시 시도
- 또는 **다른 이메일**로 테스트

### 4. Redirect URL (메일은 오는데 링크만 이상할 때)

Dashboard → Authentication → **URL Configuration**

- Site URL: `campuslunch://login-callback`
- Redirect URLs: `campuslunch://login-callback`
- `http://localhost:3000` **삭제**

메일 자체가 없으면 4번보다 1~3번을 먼저 보세요.

### 5. 이미 가입된 이메일

같은 주소로 다시 가입하면 메일이 **안 갈 수** 있습니다.  
Users에서 해당 유저 삭제 후 다시 가입하거나, **인증 메일 다시 보내기** 사용.

---

## 에뮬레이터에서 인증 없이 빠르게 테스트 (개발용)

Dashboard → Authentication → **Users** → 해당 유저 → **Confirm user** (또는 이메일 확인 처리)

그다음 앱에서 **로그인**하면 됩니다. (`profiles.sql` 실행되어 있어야 DB 프로필도 생성됨)

---

## 개발 중에만: 이메일 확인 끄기 (선택)

Dashboard → Authentication → **Providers** → Email → **Confirm email** 끄기

→ 가입 즉시 로그인 (출시 전에는 반드시 다시 켜기)

---

## 에뮬레이터에서 딥링크만 수동 테스트

메일에 있는 링크 대신, Supabase 로그/메일에서 `code=` 또는 토큰이 포함된 URL을 복사한 뒤:

```bash
adb shell am start -a android.intent.action.VIEW \
  -d "campuslunch://login-callback#access_token=YOUR_TOKEN&..."
```

(실제로는 메일 링크를 에뮬레이터 브라우저에서 열어도 됩니다.)

---

## 출시 시 권장

Dashboard → **Project Settings** → **Authentication** → **SMTP Settings**  
Gmail/ SendGrid 등 **자체 SMTP** 연결 → 발송 한도·스팸 문제가 크게 줄어듭니다.
