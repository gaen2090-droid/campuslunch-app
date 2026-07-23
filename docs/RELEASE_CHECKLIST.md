# 릴리즈 / 스토어 심사 체크리스트

출시 직전 확인용. 코드에서 이미 고친 항목과, **직접 해야 하는 운영 작업**을 구분했습니다.

---

## A. 코드에서 이미 정리한 것 (이번 작업)

| 항목 | 내용 |
|------|------|
| 스탬프 UI | `(테스트)` / `999` → **하루 최대 3** (`RewardLimits`) |
| 약관 허브 | 마이페이지 「약관 및 정책」 → 실제 문서 목록 |
| 로컬 로그인 폴백 | **릴리즈에서 비활성** (디버그만 SharedPreferences 계정) |
| Profile entitlements | TestFlight용 Profile → **production** `Runner.entitlements` |
| Info.plist | 디버그용 Local Network / Bonjour 제거, `campuslunch://` 스킴 등록 |
| Android | `kakaolink` + `campuslunch://login-callback` intent-filter |
| 시드 이미지 | Google Maps API 키 박힌 URL 제거 |
| SQL | `supabase/rewards_daily_cap_to_3.sql` 추가 (**실행은 아래 B**) |
| PDF 가이드 | 스탬프 한도 999 → 3 반영 |

디버그 전용으로 **남겨 둔 것** (릴리즈 AOT에서는 동작 안 함):

- `owner`/`owner123`, `user`/`user123` 로그인
- 제보 5분 쿨다운 우회 + GPS를 매장 좌표로 스푸핑

---

## B. 당신이 해야 하는 것 (필수)

### 1. Supabase SQL (Dashboard → SQL Editor)

- [ ] `supabase/rewards_daily_cap_to_3.sql` 실행  
  → 서버 일일 한도 999 → **3**. 안 하면 앱은 3이라고 쓰는데 서버는 999개까지 줌.

### 2. App Links / 도메인

- [ ] Gabia DNS: `campuslunch.shop` A/CNAME → Vercel **share-web**
- [ ] Vercel share-web에 `campuslunch.shop` 도메인 연결 + Production 배포
- [ ] Safari에서 JSON 확인:
  - `https://campuslunch.shop/.well-known/apple-app-site-association`
  - `https://campuslunch.shop/.well-known/assetlinks.json`
- [ ] (선택) Vercel env `STORE_URL_IOS` / `STORE_URL_ANDROID` — 앱 미설치 시 스토어 (없어도 심사는 가능)

### 3. 카카오 / 구글 / Apple

- [ ] 카카오 개발자: iOS Bundle ID `com.campuslunch.app`, Android 패키지 + **릴리스 키 해시**
- [ ] Google Cloud: Maps / OAuth 키에 **릴리스 SHA-1**, Bundle ID 제한
- [ ] Apple Developer: Push (APNs Key), Associated Domains, 유료 팀
- [ ] Supabase Auth Redirect: `campuslunch://login-callback` (+ `/**`)

### 4. 빌드·서명

**iOS**

- [ ] Xcode Signing: Team `WQRY89A2Z3`, Release entitlements (production push)
- [ ] `flutter build ipa` 또는 Archive → TestFlight
- [ ] TestFlight에서 푸시·카톡 공유 「앱에서 열기」 확인

**Android**

- [ ] `android/key.properties` + release keystore 준비
- [ ] `flutter build appbundle`
- [ ] Play Console 내부 테스트 → 카카오/구글 로그인

### 5. 스토어 메타 (심사)

- [ ] 개인정보 처리방침 URL (웹에 공개 — 앱 내 `assets/legal`만으로는 부족할 수 있음)
- [ ] 스크린샷, 설명, 연령 등급, 데이터 수집 설문 (Apple Privacy / Play Data safety)
- [ ] 로그인 필요 시 **데모 계정**을 심사 메모에 제공
- [ ] 위치·알림·사진 권한 사용 이유와 Info.plist/Manifest 문구 일치

### 6. 출시 전 실기 스모크

- [ ] 이메일 가입 OTP
- [ ] 카카오 / 구글 로그인
- [ ] 혼잡도 제보 (실 GPS, 쿨다운)
- [ ] 스탬프 하루 3개 한도
- [ ] 친구 초대 → 카톡 「앱에서 열기」
- [ ] 푸시 (점심/커뮤니티)
- [ ] 회원 탈퇴

---

## C. 알아둘 것

1. **카톡 텍스트 링크 ≠ 앱 실행**  
   친구 초대는 카카오 공유 SDK 버튼(`kakaolink`)이 정답. Universal Link는 메모/Safari용.

2. **share-web은 웹앱이 아님**  
   `.well-known` 호스트 + 앱 미설치 폴백. admin-web과 도메인 분리.

3. **클라이언트 키는 IPA/APK에 들어감**  
   anon / Maps / Kakao native는 제한(패키지·SHA·번들)으로 방어. `service_role`은 앱에 넣지 말 것.

4. **심사 빌드는 release/profile**  
   `flutter run` 디버그 우회(스탬프 GPS 등)는 심사 빌드에 없음.

5. **약관 웹 URL**  
   App Store Connect / Play에 Privacy Policy URL이 필요하면 Notion·정적 페이지에 `docs/legal` 내용을 올려 링크를 준비하세요.

---

## D. 빠른 명령

```bash
# 네이티브 키 동기화
dart run tool/sync_env_to_native.dart

# iOS
flutter build ipa

# Android
flutter build appbundle

# share-web 배포
cd share-web && vercel deploy --prod
```
