# 이메일 인증 (웹 배포 없이 — 기본 방식)

**웹사이트 배포는 필요 없습니다.**

메일 링크 → `campuslunch://login-callback` → **앱이 바로 열림** → 가입 완료 안내는 **앱 스낵바**로 표시됩니다.

## Supabase 설정

**Authentication** → **URL Configuration**

| 항목 | 값 |
|------|-----|
| **Site URL** | `campuslunch://login-callback` |
| **Redirect URLs** | `campuslunch://login-callback` |
| | `campuslunch://login-callback/**` |

`http://localhost:*` 는 **삭제**.

**Providers** → Email → **Confirm email** 켜기.

## 앱 `.env`

```bash
AUTH_REDIRECT_URL=campuslunch://login-callback
```

(비워 두어도 앱 기본값이 동일합니다.)

## SQL

`supabase/rpc_email_signup_status.sql` — 이미 가입된 이메일은 메일 미발송.

## 테스트

1. 에뮬레이터/폰에 앱 설치
2. 회원가입 → 실제 Gmail 등으로 수신
3. 메일 링크 탭 → **캠퍼스런치** 실행 → 「회원가입이 완료되었어요」 스낵바

PC 메일에서 링크를 열면 앱이 없을 수 있으니, **폰 메일 앱**에서 여는 것을 권장합니다.

---

## (선택) 웹 완료 페이지

`web/auth/confirm/index.html` 은 PC 브라우저용 안내가 필요할 때만 GitHub Pages 등에 배포하면 됩니다. **필수 아님.**
