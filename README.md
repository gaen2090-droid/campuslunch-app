# 캠퍼스런치 (campus_lunch)

중앙대 흑석캠퍼스 식당 혼잡도 Flutter 앱.

## 팀 clone 후 바로 실행

**private** repo 기준: 앱용 env·네이티브 키는 Git에 포함, **비밀 키 파일은 Git 제외** (GitHub Push Protection).

```bash
flutter pub get
flutter run
```

- **`.env`** — 앱 (Git 포함, `git pull`로 동일)
- **`.env.secrets`** — 스크립트용 Secret (**Git 제외**, 리드가 안전하게 전달) → `docs/TEAM_SETUP.md`
- **`android/keys.properties`** / **`ios/Flutter/Secrets.xcconfig`** — 네이티브 키 (Git 포함)
- **`android/local.properties`** — PC별 Flutter SDK (자동 생성)

`.env` 값을 바꾼 뒤 네이티브 키까지 맞추려면:

```bash
dart run tool/sync_env_to_native.dart
```

## Supabase SQL

`docs/PRODUCTION_SETUP.md`, `docs/EMAIL_OTP_SETUP.md`, `docs/SMTP_SETUP.md` 참고.

디버깅 중 가입 테스트 후 이메일이 막히면:

```bash
dart run tool/purge_auth_user.dart --email=you@example.com
```

(`public.users`만 지우지 말고 **auth.users**도 삭제해야 함)

## 주의

저장소를 **public** 으로 바꾸면 `.env` 등 키를 Git에서 제거하고 재발급하세요.
