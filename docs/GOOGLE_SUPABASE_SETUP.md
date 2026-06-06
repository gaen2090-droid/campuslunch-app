# Google 로그인 + Supabase 설정

앱은 `google_sign_in` → `signInWithIdToken(provider: google)` 방식을 사용합니다.

## 1. Google Cloud Console

[Google Cloud Console](https://console.cloud.google.com/) → APIs & Services → **Credentials**

### OAuth 2.0 Client ID 생성

| 유형 | 용도 | 패키지/번들 |
|------|------|-------------|
| **Android** | 네이티브 앱 | `com.campuslunch.app` + **SHA-1** (디버그/릴리스 각각) |
| **iOS** | 네이티브 앱 | `com.campuslunch.app` |
| **Web** | Supabase + Android `serverClientId` | — |

> **중요:** Supabase Google Provider의 **Client ID**와 `.env`의 `GOOGLE_OAUTH_WEB_CLIENT_ID`는 **웹 Client ID**여야 합니다.

### Android SHA-1 등록

```bash
cd android && ./gradlew signingReport
```

`Variant: debug` / `release` 의 SHA-1을 Android OAuth 클라이언트에 각각 등록합니다.

## 2. `.env` 설정

```env
GOOGLE_OAUTH_WEB_CLIENT_ID=123456789-xxxx.apps.googleusercontent.com
GOOGLE_OAUTH_IOS_CLIENT_ID=123456789-yyyy.apps.googleusercontent.com
```

동기화:

```bash
dart run tool/sync_env_to_native.dart
```

- iOS: `Secrets.xcconfig` → `GIDClientID`, reversed URL scheme
- Android: Dart `serverClientId`로 웹 Client ID 사용 (별도 manifest 설정 불필요)

## 3. Supabase Dashboard

**Authentication → Providers → Google**

| 항목 | 값 |
|------|-----|
| Enabled | ON |
| Client ID | **웹** Client ID (`.env`의 `GOOGLE_OAUTH_WEB_CLIENT_ID`와 동일) |
| Client Secret | Google Cloud에서 웹 클라이언트 Secret |
| **Skip nonce check** | 앱에서 nonce 오류가 나면 **ON** (iOS 네이티브 Google 로그인용) |

Redirect URI (참고):

```text
https://vkacsvoknnlmcyplprft.supabase.co/auth/v1/callback
```

`signInWithIdToken`만 사용하므로 앱에서 별도 딥링크 콜백은 필요 없습니다.

## 4. Supabase SQL (이메일 중복 차단)

이메일 가입 계정과 동일 Gmail으로 Google 로그인 시 차단:

```bash
# Dashboard → SQL Editor → Run
supabase/rpc_oauth_login_email_check.sql
```

## 5. 앱 동작

1. 로그인 화면 **Google로 계속하기** 탭
2. Google 계정 선택 → ID 토큰 발급
3. Supabase `signInWithIdToken` → 세션 저장 (자동 로그인)
4. `public.users` 프로필 upsert (`ProfileRepository.upsertFromAuthUser`)
5. 로그아웃: Supabase `signOut` + `GoogleSignIn.signOut`
6. 탈퇴: `GoogleSignIn.disconnect` + `delete_own_account` RPC

## 6. 자주 나는 오류

| 증상 | 확인 |
|------|------|
| `GOOGLE_OAUTH_WEB_CLIENT_ID가 .env에 없습니다` | `.env` 값 입력 후 `sync_env_to_native` |
| `Google ID 토큰이 없습니다` | 웹 Client ID가 Android `serverClientId`로 전달되는지 확인 |
| `passed nonce and nonce in id_token` | 앱이 raw nonce를 Google·Supabase에 함께 전달함. 계속되면 Supabase **Skip nonce check** ON |
| `Unacceptable audience in id_token` | Supabase Google Client ID ≠ 웹 Client ID |
| iOS 로그인 실패 | `GOOGLE_OAUTH_IOS_CLIENT_ID`, `Info.plist` URL scheme |
| Android `DEVELOPER_ERROR` (10) | 패키지명 `com.campuslunch.app` + SHA-1 등록 |

## 7. 팀 공유

`.env` 변경 후:

```bash
dart run tool/sync_env_to_native.dart
git add .env ios/Flutter/Secrets.xcconfig android/keys.properties
git commit && git push
```
