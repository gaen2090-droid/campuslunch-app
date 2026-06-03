# 팀 온보딩 (환경 변수)

## Git에 포함되는 것

| 파일 | 내용 |
|------|------|
| `.env` | 앱: Supabase URL·anon, Maps, Kakao |
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
# .env.secrets 받아서 루트에 저장
flutter pub get
flutter run
```

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
