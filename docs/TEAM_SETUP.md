# 팀 온보딩 (환경 변수)

## Git에 포함되는 것

| 파일 | 내용 |
|------|------|
| `.env` | 앱: Supabase URL·anon, Maps, Kakao, Google OAuth |
| `android/keys.properties` | Android 네이티브 키 |
| `ios/Flutter/Secrets.xcconfig` | iOS 네이티브 키 |
| `.env.secrets.example` | 비밀 파일 **양식만** |

## Git에 넣으면 안 되는 것 (Push Protection)

`.env.secrets` — Supabase **Secret Key**, **Access Token**, Resend API 키 등  
→ GitHub가 push 자체를 거절합니다 (private repo도 동일).

### 파트너에게 `.env.secrets` 전달 방법

리드가 **안전한 채널**로 파일 내용을 보냅니다 (카톡·Slack DM·1Password 등).

1. 리드: `.env.secrets.example` 을 복사해 `.env.secrets` 로 저장 후 값 채움  
2. 파트너: 프로젝트 루트에 `.env.secrets` 붙여넣기 (Git에 add 하지 않음)

```bash
cp .env.secrets.example .env.secrets
# 리드가 준 값으로 편집
```

## 파트너 첫 실행

```bash
git clone <repo>
cd campuslunch-app
git checkout develop
git pull
# .env.secrets 받아서 루트에 저장
flutter pub get
flutter run
```

> **실행 대상:** `iPhone 시뮬레이터` 또는 `Android 에뮬레이터`  
> Android Studio / Cursor에서 **Chrome(web)** 으로 실행하지 마세요.  
> · 카카오·Google 로그인: 네이티브(iOS/Android) 전용  
> · Chrome 실행 시 `Unable to terminate com.campuslunch.app on …simctl` 메시지는  
>   이전에 켜 둔 iOS 시뮬레이터를 Flutter가 종료하려다 나는 **도구 경고**로, 앱 버그가 아닙니다.  
> · 이메일 가입 오류는 웹 때문이 아니라 Resend/SMTP 이슈인 경우가 많음 (아래 SMTP 문서)

### 이메일 가입 `Error sending confirmation email`

1. 가입에 쓴 주소가 **Resend 가입 이메일**인지 확인 (`onboarding@resend.dev` 테스트 한도)  
2. [Resend Logs](https://resend.com/logs) 에서 실패 사유 확인  
3. `docs/SMTP_SETUP.md` §4 참고  

### 카카오 로그인 KOE101 이 뜨면

1. `.env` / `android/keys.properties` 에 `KAKAO_NATIVE_APP_KEY` 있는지 확인  
2. `dart run tool/print_kakao_android_key_hash.dart` → 나온 해시를 **리드에게 전달**  
3. 리드가 [카카오 콘솔](https://developers.kakao.com) Android 키 해시에 추가  
4. `flutter clean && flutter run`  

자세히: `docs/KAKAO_SUPABASE_SETUP.md` §6

### Google 로그인이 안 되면

1. `.env`에 `GOOGLE_OAUTH_WEB_CLIENT_ID`, `GOOGLE_OAUTH_IOS_CLIENT_ID` 확인  
2. `dart run tool/sync_env_to_native.dart`  
3. Supabase Google Provider Client ID = **웹** Client ID인지 확인  

자세히: `docs/GOOGLE_SUPABASE_SETUP.md`

## 리드: `.env` 변경 시

```bash
dart run tool/sync_env_to_native.dart
git add .env android/keys.properties ios/Flutter/Secrets.xcconfig
git commit && git push
```

## push가 막혔을 때 (이미 커밋에 secret 넣은 경우)

```bash
git reset --soft HEAD~1
git restore --staged .env.secrets   # 또는: git rm --cached .env.secrets
# .env.secrets 는 .gitignore 에 있음
git add .env android/keys.properties ios/Flutter/Secrets.xcconfig .gitignore
git commit -m "Add team-shared env (secrets file excluded from Git)"
git push
```

**절대** GitHub “allow secret” 링크로 시크릿을 remote에 올리지 마세요. 이미 노출된 키는 Supabase/Resend에서 **재발급** 권장.
