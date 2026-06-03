# 카카오 로그인 + Supabase 설정

## 1. 카카오 개발자 (developers.kakao.com)

앱 선택 → **앱 키**

- **네이티브 앱 키** → `.env` 의 `KAKAO_NATIVE_APP_KEY` + **Supabase Kakao 설정란 (필수)**
- **REST API 키** → 카카오 개발자 콘솔에서 확인 (웹 OAuth·Redirect URI용). **Flutter 앱 Supabase 설정에는 넣지 않음**

**플랫폼**

| OS | 값 |
|----|-----|
| Android 패키지 | `com.campuslunch.app` |
| iOS Bundle ID | `com.campuslunch.app` |

**카카오 로그인 → OpenID Connect** 활성화 (ID 토큰 필요)

**Redirect URI** (Supabase 프로젝트 ref에 맞게):

```text
https://vkacsvoknnlmcyplprft.supabase.co/auth/v1/callback
```

**동의항목**: 닉네임, 프로필 사진(선택)

## 2. Supabase Dashboard

**Authentication → Sign In / Providers** (또는 **Providers**) → **Kakao** 펼치기

대시보드 버전에 따라 라벨이 다릅니다. **「Client ID」가 없으면** 아래 중 하나를 찾으세요.

| Supabase 화면 라벨 | 넣을 값 |
|-------------------|---------|
| **Native App Key** (최신 UI) | 카카오 **네이티브 앱 키** |
| **REST API Key** (구 UI) | 여기에도 **네이티브 앱 키**를 넣어야 함 (이름만 REST API) |

- Kakao **Enabled** 켜기
- 위 키 입력: `4365f2a2d44f911f29d65544f88b8cc6` (`.env`와 동일한 **네이티브 앱 키**)
- **Client Secret** 항목이 없으면 비워 두면 됨 (네이티브 `signInWithIdToken`만 쓸 때)
- **Save**

> Flutter 앱은 카카오 SDK 로그인 → ID 토큰 `aud` = **네이티브 앱 키**. REST API 키만 넣으면 `Unacceptable audience in id_token` 발생.

**Authentication → URL Configuration**

- Redirect URLs에 위 callback URL 포함 (기존 `campuslunch://` 유지)

## 3. SQL (순서)

1. **`supabase/users_auth.sql`** — public.users + Auth 트리거 (`profiles` 아님)
2. `supabase/policies.sql`
3. `supabase/rpc_email_signup_status.sql`
4. `supabase/rpc_claim_owner.sql`
5. `supabase/rpc_delete_own_account.sql`

## 4. 앱 `.env`

```bash
KAKAO_NATIVE_APP_KEY=4365f2a2d44f911f29d65544f88b8cc6
```

Android `local.properties` (선택, 네이티브 메타데이터용):

```properties
KAKAO_NATIVE_APP_KEY=4365f2a2d44f911f29d65544f88b8cc6
```

iOS `ios/Flutter/Secrets.xcconfig`:

```
KAKAO_NATIVE_APP_KEY=4365f2a2d44f911f29d65544f88b8cc6
```

## 5. 앱 동작

| 기능 | 설명 |
|------|------|
| 카카오 로그인 | SDK → `signInWithIdToken` → **`public.users`** 자동 생성 |
| 로그인 유지 | Supabase 세션 (자동 갱신) |
| 로그아웃 | 카카오 SDK logout + Supabase signOut |
| 탈퇴 | 카카오 unlink + `delete_own_account` RPC |

## 6. 자주 나는 에러

| 메시지 | 원인 | 해결 |
|--------|------|------|
| `Unacceptable audience in id_token:[4365f2a2d44f911f29d65544f88b8cc6]` | Supabase에 REST API 키만 넣음 | Kakao → **Native App Key**(또는 REST API Key 칸)에 **네이티브 앱 키** 입력 |
| `카카오 OpenID 토큰이 없습니다` | 카카오 콘솔 OpenID Connect 미활성 | 카카오 개발자 → 카카오 로그인 → OpenID Connect ON |
