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

### `Error sending confirmation email` (unexpected_failure)

**Chrome·웹 실행 때문이 아닙니다.** Supabase가 Resend로 메일을 못 보낼 때 나는 서버 오류입니다.

| 원인 | 해결 |
|------|------|
| `onboarding@resend.dev` 테스트 발신 | **Resend에 가입한 이메일**로만 가입 테스트 |
| 다른 Gmail 등으로 테스트 | Resend에서 **도메인 인증** → `SMTP_ADMIN_EMAIL=noreply@yourdomain.com` 후 `setup_supabase_smtp.dart` 재실행 |
| API 키 권한 | Resend **Full access** 키 사용 |
| 거절 로그 | [Resend Logs](https://resend.com/logs) 확인 |

팀 테스트: **iOS 시뮬레이터 / Android 에뮬레이터** 권장 (웹은 카카오·지도 등 미지원/제한).

## 5. 무료(에 가깝게) 도메인 인증 — 요약

| 항목 | 비용 |
|------|------|
| Resend 가입·도메인 추가·인증 | **0원** |
| Resend 발송 (무료 플랜) | 월 3,000통 등 무료 한도 |
| **도메인 이름 자체** | 보통 **연 1만 원 전후** (완전 무료 .com 은 거의 없음) |

**완전 0원에 가까운 경우**

1. **이미 가진 도메인** (학교·개인·예전에 산 것) → Resend 인증만 하면 됨 (추가 요금 없음)  
2. **Cloudflare에 도메인 연결** + Resend **「Sign in to Cloudflare」** → DNS 자동 입력 (무료)  
3. **서브도메인만 인증** (예: `mail.내도메인.com`) → 루트 도메인 없어도 됨, 기존 메일과 충돌 적음  

**비추:** Freenom 등 「공짜 .com」 — 만료·DNS 불안정, Resend 인증 실패 많음.

### A. 이미 도메인이 있을 때 (0원 추가)

1. [resend.com/domains](https://resend.com/domains) → **Add Domain**  
2. 도메인 입력 (루트 `example.com` 또는 서브 `auth.example.com`)  
3. DNS 관리 화면(가비아·Cloudflare 등)에 Resend가 준 **TXT/CNAME** 추가  
4. Cloudflare 쓰면: Resend에서 **Sign in to Cloudflare** → 자동 등록 (가장 쉬움)  
5. **Verify DNS Records** → **Verified**  
6. `.env.secrets` → `SMTP_ADMIN_EMAIL=noreply@auth.example.com`  
7. `dart run tool/setup_supabase_smtp.dart`

Cloudflare DNS일 때: Resend 관련 레코드는 **프록시 끔(회색 구름, DNS only)**.

### B. 도메인이 없을 때 (최소 비용)

1. [Cloudflare Registrar](https://www.cloudflare.com/products/registrar/) 또는 가비아에서 **저렴한 도메인** 구매 (예: `.link`, `.app` — 프로모션에 따라 다름)  
2. 도메인을 **Cloudflare DNS**로 옮기거나 구매 시 Cloudflare 연결  
3. 위 **A** 와 동일 (Sign in to Cloudflare 권장)

학생이면 GitHub Student Pack 등으로 Namecheap 크레딧 있는 경우도 있음 (해당 시 0원 가능).

### C. 인증 후 앱에 반영

```env
# .env.secrets
SMTP_ADMIN_EMAIL=noreply@auth.내도메인.com
```

```bash
/Users/dongha/develop/flutter/bin/dart run tool/setup_supabase_smtp.dart
```

---

## 6. 아무 이메일로 받기 — Resend 도메인 인증 (상세)

`onboarding@resend.dev` 는 **테스트용**이라 Gmail·학교 메일 등 **임의 주소로는** 안 갈 수 있습니다.  
팀/사용자 전부에게내려면 **본인 도메인**을 Resend에 등록해야 합니다.

### 준비물

- **도메인 1개** (예: `campuslunch.app`, `gaen2090.com` — 가비아/Cloudflare/Namecheap 등에서 구매·보유)
- Resend 계정 + API 키 (`re_...`, **Full access** 권장)
- 도메인 DNS 설정 권한 (레코드 추가 가능)

### 1단계: Resend에 도메인 추가

1. [resend.com/domains](https://resend.com/domains) 로그인
2. **Add Domain** → 도메인 입력 (예: `campuslunch.app`)
3. Resend가 **DNS 레코드 목록**을 보여줌 (보통 3~4개)
   - `TXT` (SPF / verification)
   - `CNAME` 또는 `TXT` (DKIM, `resend._domainkey` 등)

### 2단계: DNS에 레코드 붙여넣기

도메인을 산 곳(가비아, Cloudflare, GoDaddy 등) 관리 콘솔 → **DNS 설정** → Resend가 준 값 **그대로** 추가.

| Resend 화면 | DNS에 넣을 것 |
|-------------|----------------|
| Type | 레코드 종류 (TXT / CNAME) |
| Name / Host | `@` 또는 `resend._domainkey` 등 (업체마다 `@` = 루트) |
| Value / Content | Resend가 준 긴 문자열 |

저장 후 **전파 5분~48시간** (보통 10~30분).

### 3단계: Resend에서 Verified 확인

Resend **Domains** 목록에서 상태가 **Verified** (초록) 될 때까지 대기.  
Pending이면 DNS가 아직 안 맞은 것 → 레코드 오타·호스트명 재확인.

### 4단계: `.env.secrets` 수정

프로젝트 루트 `.env.secrets` (Git에 올리지 않음):

```env
RESEND_API_KEY=re_기존키_또는_새_Full_access_키
SMTP_ADMIN_EMAIL=noreply@campuslunch.app
SMTP_SENDER_NAME=캠퍼스런치
```

- `noreply@...` 앞부분은 자유 (`auth@`, `no-reply@` 등) — **반드시 인증한 도메인**이어야 함
- `onboarding@resend.dev` 줄은 **삭제하거나 위 주소로 교체**

### 5단계: Supabase에 다시 적용

```bash
cd /Users/dongha/StudioProjects/campuslunch-app
/Users/dongha/develop/flutter/bin/dart run tool/setup_supabase_smtp.dart
```

성공 예:

```text
SMTP 연동 완료
  from: noreply@campuslunch.app (캠퍼스런치)
```

Supabase Dashboard → **Authentication** → **Emails** → SMTP 에서  
**Sender email** 이 `noreply@...@도메인` 으로 바뀌었는지 확인.

### 6단계: 테스트

1. [resend.com/logs](https://resend.com/logs) 탭 열어 두기
2. 앱에서 **파트너 Gmail 등 아무 이메일**로 회원가입
3. 메일함(스팸함 포함)에 **6자리 인증번호** 확인
4. Logs에 **Delivered** 면 성공, **Failed** 면 메시지 클릭해 원인 확인

### 자주 막히는 것

| 증상 | 해결 |
|------|------|
| 도메인 Pending 오래감 | DNS TTL·호스트명(`@` vs 도메인명) 재확인 |
| 여전히 confirmation email 오류 | Resend Logs 실패 사유, API 키 Full access |
| 메일만 안 옴 | 스팸함, 발신 도메인과 수신 주소가 같은지(테스트) |
| 도메인 없음 | 저렴한 도메인 구매 후 위 과정 반복 |

### 파트너에게

도메인/SMTP는 **Supabase 프로젝트 1개**에만 붙으므로, 리드가 5단계까지 하면 **파트너는 `git pull` + 시뮬레이터 실행만** 하면 됩니다.  
`.env.secrets`의 `SMTP_ADMIN_EMAIL` 은 Supabase 서버 설정이라 파트너 PC에 없어도 메일 발송은 동일하게 동작합니다.

---

## 7. 다른 SMTP 사용 시

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
