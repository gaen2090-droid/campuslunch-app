# App Links / Universal Links 가이드

캠퍼스런치는 `https://campuslunch.shop` 도메인으로 **Android App Links** · **iOS Universal Links** 를 사용합니다.

앱이 설치된 기기에서는 링크 탭 시 **브라우저 없이 앱**이 열리고, 미설치 기기는 `share-web`(Vercel) 폴백 페이지로 스토어 안내를 볼 수 있습니다.

---

## 1. 지원 URL

| 화면 | URL 예시 | 앱 동작 |
|------|----------|---------|
| 메인(홈 탭) | `https://campuslunch.shop/home` | 홈 탭으로 이동 |
| 메인(루트) | `https://campuslunch.shop/` | 홈 탭으로 이동 |
| 쿠폰함 | `https://campuslunch.shop/coupons` | 쿠폰함 화면 push |
| 매장 상세 | `https://campuslunch.shop/r/3` | 3번 매장 상세 push |

- 매장 링크는 **UUID가 아니라 순번(`link_no`)** 을 씁니다.
- `/restaurant/3` 도 `/r/3` 과 동일하게 파싱됩니다 (하위 호환).
- 공유하기(카카오·링크 복사)도 `/r/{link_no}` 형식을 사용합니다.

---

## 2. 로그인·화면 전환 규칙

| 상태 | 링크 탭 시 |
|------|------------|
| **로그인 + 메인(`stage=app`)** | 위 표대로 해당 화면으로 이동 |
| **미로그인** | 링크 **무시** → 스플래시·온보딩·로그인 등 **기존 초기 플로우** |
| 로그인했지만 가입 직후 가이드·약관 등 | 링크 무시 (메인 진입 후부터 처리) |

자동 로그인(세션 복원)이 되어 메인에 들어온 뒤에만 딥링크가 동작합니다.

---

## 3. 매장 번호(`link_no`) 자동 배정

새 매장을 admin-web·앱(admin)에서 **INSERT** 하면 DB 트리거가 **1, 2, 3…** 순번을 자동 부여합니다.  
코드에서 번호를 직접 넣을 필요 없습니다.

### Supabase SQL (최초 1회)

Dashboard → **SQL Editor** → Run:

```text
supabase/restaurant_link_no.sql
```

| 항목 | 내용 |
|------|------|
| 컬럼 | `public.restaurants.link_no` (integer, unique) |
| 트리거 | `trg_restaurants_assign_link_no` — INSERT 시 시퀀스 배정 |
| 기존 매장 | `created_at` 순으로 1부터 백필 |
| 링크 | `https://campuslunch.shop/r/{link_no}` |

### 번호 확인

```sql
select id, name, link_no, created_at
from public.restaurants
order by link_no;
```

admin-web **매장 관리** 카드에도 `https://campuslunch.shop/r/{번호}` 가 표시됩니다.  
SQL 미실행 시 **「번호 미배정」** 으로 보입니다.

---

## 4. 아키텍처 (한눈에)

```text
[링크 탭]
    │
    ├─ 앱 설치 + OS 검증 통과
    │       → app_links 패키지 → AppLinkService
    │       → AppProvider.handleIncomingUri
    │       → MainScreen에서 화면 이동
    │
    └─ 앱 미설치 / 검증 실패
            → share-web (Vercel) 폴백 → 스토어 URL 또는 안내 문구
```

### 코드 위치

| 역할 | 파일 |
|------|------|
| URL 생성·파싱 | `lib/constants/app_links.dart` |
| OS 링크 수신 | `lib/services/app_link_service.dart` |
| 로그인·pending 처리 | `lib/providers/app_provider.dart` |
| 화면 이동 | `lib/screens/main_screen.dart` |
| 공유 URL | `lib/widgets/share_sheet.dart` |
| DB `link_no` | `supabase/restaurant_link_no.sql` |
| 호스트 env | `.env` → `APP_LINK_HOST=campuslunch.shop` |

### share-web (Vercel)

| 경로 | 용도 |
|------|------|
| `public/.well-known/assetlinks.json` | Android 도메인 검증 |
| `public/.well-known/apple-app-site-association` | iOS Universal Links |
| `api/link.js` | 앱 미설치 시 스토어 리다이렉트 |
| `vercel.json` | `/r/:no`, `/coupons`, `/home` 라우팅 |

도메인 `campuslunch.shop` 을 **share-web Vercel 프로젝트**에 연결해야 `.well-known` 이 HTTPS로 제공됩니다.

---

## 5. 배포 체크리스트

### ① Supabase

- [ ] `supabase/restaurant_link_no.sql` 실행
- [ ] `select link_no from restaurants limit 5;` 로 번호 확인

### ② 환경 변수

`.env` (앱·Android 빌드):

```env
APP_LINK_HOST=campuslunch.shop
```

Android는 `android/app/build.gradle.kts` 가 이 값을 manifest placeholder `APP_LINK_HOST` 로 넣습니다.

### ③ share-web (Vercel)

- [ ] `campuslunch.shop` DNS → Vercel
- [ ] `share-web` 프로젝트 **Production** 배포
- [ ] 아래 URL이 JSON 그대로 열리는지 확인:
  - `https://campuslunch.shop/.well-known/assetlinks.json`
  - `https://campuslunch.shop/.well-known/apple-app-site-association`

#### Android `assetlinks.json`

`share-web/public/.well-known/assetlinks.json` 의 `sha256_cert_fingerprints` 에 **서명 키 SHA-256** 이 들어가야 합니다.

```bash
# 안내 출력
dart run tool/print_app_link_sha256.dart

# 릴리스 키 확인
cd android && ./gradlew :app:signingReport
```

- **릴리스(Play Store / APK)** 키와 **디버그(`flutter run`)** 키를 각각 등록하는 것을 권장합니다.
- SHA-256은 `AA:BB:CC:…` 형식(콜론 포함)으로 JSON에 넣습니다.

`package_name`: `com.campuslunch.app` (고정)

#### iOS `apple-app-site-association`

- `appID`: `{TeamID}.com.campuslunch.app` (현재 `WQRY89A2Z3.com.campuslunch.app`)
- **Release** 빌드: `ios/Runner/Runner.entitlements` (Associated Domains)
- **Debug / Profile** (`flutter run`): `RunnerDebug.entitlements` — Personal Team 실기 개발용(Universal Links 없음)
- Xcode → **Signing & Capabilities** → **Associated Domains** (Release·유료 계정)

### ④ 앱 빌드

- [ ] `flutter pub get` (`app_links` 의존성)
- [ ] iOS: entitlements 포함된 프로비저닝 프로파일로 빌드
- [ ] Android: release 빌드 후 App Links 검증 (아래 테스트 참고)

---

## 6. 테스트

### 로그인 상태 (실기 권장)

1. 앱 실행 → 로그인 → 메인 화면까지 진입
2. 메모·카카오톡 등에 링크 붙여넣기 후 탭
   - `https://campuslunch.shop/home`
   - `https://campuslunch.shop/coupons`
   - `https://campuslunch.shop/r/1` (실제 `link_no` 로 교체)
3. 브라우저를 거치지 않고 앱이 열리고 해당 화면으로 이동하는지 확인

### 미로그인

1. 로그아웃 후 같은 링크 탭
2. **초기 화면(온보딩/로그인)** 으로만 진입 — 딥링크 목적지로 가지 않음

### Android App Links 검증

```bash
adb shell pm get-app-links com.campuslunch.app
```

`campuslunch.shop` 이 **verified** 여야 합니다.  
실패 시 `assetlinks.json` SHA-256·도메인 HTTPS·`autoVerify` intent-filter 를 재확인하세요.

### iOS

- 실기에서 Safari 주소창에 `https://campuslunch.shop/r/1` 입력
- 앱 설치·Associated Domains 설정 후 상단 **「열기」** 또는 자동 전환 확인
- Apple CDN 캐시 때문에 AASA 변경 반영까지 **최대 수 시간** 걸릴 수 있음

---

## 7. 자주 묻는 문제

| 증상 | 확인 |
|------|------|
| 링크가 브라우저만 열림 | `assetlinks.json` / AASA 배포, SHA-256, 도메인 연결 |
| 매장 링크가 홈으로만 감 | `restaurant_link_no.sql` 실행 여부, `link_no > 0` 인지 |
| 공유 링크가 `/r/0` 또는 홈 URL | DB에 `link_no` 없음 → SQL 실행 후 매장 재조회 |
| 로그인했는데도 무시됨 | `stage` 가 `app` 인지 (가이드·약관 화면 중이면 대기) |
| admin-web에 「번호 미배정」 | Supabase SQL 미적용 |

---

## 8. OAuth·이메일 링크와 구분

| 종류 | 스킴/도메인 | 용도 |
|------|-------------|------|
| **App Link** | `https://campuslunch.shop/...` | 홈·쿠폰함·매장 공유 |
| **이메일 인증** | `campuslunch://login-callback` | Supabase OTP/매직링크 복귀 |
| **카카오 OAuth** | `kakao{앱키}://oauth` | 소셜 로그인 |

이메일 인증 설정은 `docs/DEPLOY_AUTH_WEB.md` 를 참고하세요.

---

## 9. 새 매장 추가 시 (운영)

1. admin-web **매장 관리** 또는 **지도 등록**에서 매장 INSERT
2. DB 트리거가 **다음 `link_no` 자동 배정** (예: 기존 최대 12 → 신규 13)
3. admin-web 카드·공유하기에 `https://campuslunch.shop/r/13` 즉시 사용 가능
4. **별도 링크 등록 작업 없음**

번호는 **삭제해도 재사용하지 않습니다** (시퀀스 증가). 공유된 옛 링크가 다른 매장을 가리키지 않도록 하기 위함입니다.
