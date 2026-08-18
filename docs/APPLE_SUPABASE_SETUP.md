# Sign in with Apple + Supabase 설정

앱은 `sign_in_with_apple` → `signInWithIdToken(provider: apple)` 방식을 사용합니다.
**iOS만** 로그인 버튼을 표시합니다 (App Store 가이드라인 4.8).

## 카카오·구글과의 차이

| | 카카오 / 구글 | Apple |
|--|---------------|-------|
| 앱 `.env` Client ID | 필요 | **불필요** (iOS 시스템 API) |
| Apple Developer | — | **필수** (Sign in with Apple capability + Key) |
| Supabase Provider 설정 | Client ID / Secret | **필수** (Team ID, Key ID, .p8, Bundle ID) |
| Xcode Entitlement | — | **필수** (`com.apple.developer.applesignin`) |

즉, **앱에 API 키를 넣는 작업은 없지만**, Apple Developer + Supabase 대시보드 설정은 꼭 해야 합니다.

## 1. Apple Developer

1. [Certificates, Identifiers & Profiles](https://developer.apple.com/account/resources/identifiers/list)
2. **Identifiers** → App ID `com.campuslunch.app` → **Sign In with Apple** 체크 → Save
3. **Keys** → `+` → Key Name 예: `CampusLunch Apple Sign In`
   - **Sign in with Apple** 체크 → Configure → Primary App ID = `com.campuslunch.app`
   - Register → **Download `.p8`** (한 번만 다운로드 가능 — 안전하게 보관)
   - **Key ID** 메모
4. 우측 상단 Membership에서 **Team ID** 확인

## 2. Supabase Dashboard

**Authentication → Providers → Apple** → Enable

| 항목 | 값 |
|------|-----|
| Enabled | ON |
| Client IDs | `com.campuslunch.app` (Bundle ID) |
| Secret Key (for OAuth) | **비워 두세요** (아래 설명) |

### Secret Key (for OAuth)에 뭘 넣나요?

**우리 앱은 넣을 필요 없습니다.** 비워 두고 저장하세요.

이 칸은 **웹 OAuth**(`signInWithOAuth`)용입니다. Apple이 요구하는
**client_secret JWT**(최대 6개월 유효)를 넣는 자리입니다.

| 상황 | Secret Key |
|------|------------|
| iOS 네이티브만 (`signInWithIdToken`) ← **우리** | **비움** |
| 웹/Android에서 Apple 로그인(브라우저 OAuth) | JWT 생성해서 입력 (6개월마다 갱신) |

**절대 `.p8` 파일 내용을 그대로 넣지 마세요.** `.p8`은 JWT를 만들 때
쓰는 서명 키이고, Secret Key 칸에 넣는 값은 그걸로 만든 **긴 JWT 문자열**입니다.

웹 OAuth까지 쓸 때만:

1. Apple Developer에서 **Services ID** 생성 + Supabase callback URL 등록
2. **Keys**에서 `.p8` 다운로드 (Key ID·Team ID 메모)
3. Supabase Apple 설정 페이지의 **Generate secret** 툴(Chrome/Firefox)에
   Team ID / Key ID / Services ID / `.p8` 붙여넣기 → 나온 JWT를 Secret Key에 입력
4. Client IDs: `ServicesID,com.campuslunch.app` (Services ID를 **맨 앞**)

`signInWithIdToken`만 쓰므로 앱 딥링크 콜백은 필요 없습니다.

## 3. Xcode / 앱 (이미 코드에 반영됨)

- `ios/Runner/Runner.entitlements`, `RunnerDebug.entitlements`에
  `com.apple.developer.applesignin = Default` 추가됨
- Xcode → Runner target → **Signing & Capabilities**에 **Sign In with Apple**이
  보이는지 확인 (안 보이면 `+ Capability`로 추가)
- 실기기 또는 iOS 13+ 시뮬레이터에서만 버튼·로그인이 동작합니다

## 4. 앱 동작

1. 로그인 화면 (iOS) → **Apple로 계속하기**
2. Apple 시트에서 이메일 공유 또는 **Hide My Email** 선택 가능
3. identityToken + nonce → Supabase `signInWithIdToken(apple)`
4. `public.users`는 기존 `handle_new_user` 트리거로 생성 (`provider=apple`)

## 5. App Review 답변 포인트 (4.8)

Sign in with Apple은 Apple이 명시한 동급 로그인입니다.

- 수집: 이름(선택)·이메일(또는 Hide My Email 릴레이)로 제한
- 이메일 비공개: Hide My Email로 앱·개발자에게 실제 주소를 숨길 수 있음
- 광고 추적: Apple 로그인은 동의 없이 앱 이용 행위를 광고 목적으로 수집하지 않음

## 6. 체크리스트

- [ ] App ID에 Sign in with Apple ON
- [ ] Apple Key(.p8) 생성·보관, Key ID / Team ID 확보
- [ ] Supabase Apple Provider ON + Client ID = `com.campuslunch.app`
- [ ] Xcode Capability에 Sign In with Apple
- [ ] 실기기에서 Apple 로그인 → 신규 가입 / 재로그인 확인
- [ ] Hide My Email 선택 시에도 로그인·닉네임 설정 정상인지 확인
