# Hungries 조직 웹사이트

Apple Developer Program **조직(Organization) 전환/등록**용 공개 회사 소개 사이트입니다.  
제품명: Campus Lunch(캠퍼스런치) 등 · 상호: 헝그리즈(Hungries)
Hungries는 여러 모바일 앱을 기획·개발·운영하는 팀이며, Campus Lunch는 현재 출시·운영 중인 제품입니다.

## Apple이 요구하는 조건 (요약)

공식 문구 기준 ([Enrollment](https://developer.apple.com/help/account/membership/program-enrollment)):

1. **공개적으로 확인 가능**하고 **실제로 동작**하는 웹사이트일 것  
2. **도메인 이름이 조직과 연관**될 것 (예: `hungries.kr`, `hungries.co.kr`)  
3. **소셜 미디어 페이지만** 있는 링크는 거부  
4. **콘텐츠가 거의 없거나**, 도메인 등록기관 안내(parking)만 있는 사이트는 거부  
5. 추가로 조직 등록 시 보통 함께 필요:
   - **법적 실체**(법인/사업자 — DBA·상호만 있는 형태는 불가할 수 있음)
   - **D‑U‑N‑S Number**
   - **조직 도메인 이메일** (업무용 `@조직도메인`)
   - 계약을 맺을 **법적 권한**이 있는 Account Holder

이 사이트는 4번을 피하도록 **회사소개 / 제품 / 사업자정보 / 문의**를 한 페이지에 충분히 담았습니다.

## 로컬 미리보기

```bash
cd hungries-web
npx --yes serve .
# 또는
python3 -m http.server 5174
```

## Vercel 배포

1. [vercel.com](https://vercel.com)에서 새 프로젝트 생성  
2. 이 저장소를 연결하고 **Root Directory**를 `hungries-web`으로 설정  
3. Framework Preset: **Other** (빌드 없음, 정적 파일)  
4. Deploy

또는 CLI:

```bash
cd hungries-web
npx vercel
```

## 커스텀 도메인: hungries.site

1. Vercel에 `hungries-web` 배포  
2. Project → **Settings → Domains** → `hungries.site` / `www.hungries.site` 추가  
3. 도메인 등록처(DNS)에 Vercel이 안내하는 **A / CNAME** 기록  
4. `https://hungries.site` 가 회사 소개 페이지로 열리는지 확인  
5. **`contact@hungries.site`** 메일 개설 (Google Workspace / 가비아 메일 / ImprovMX 등)  
   → Apple 조직 등록 시 업무 이메일로 사용

## 체크리스트 (제출 전)

- [ ] `https://hungries.site` 가 브라우저에서 열림 (주차 페이지 아님)
- [ ] Hungries / 헝그리즈 / Campus Lunch / 사업자정보가 보임
- [ ] `contact@hungries.site` 수신 가능
- [ ] D‑U‑N‑S, 사업자 정보, Account Holder 권한이 Apple 폼과 일치
- [ ] 사이트에 “Coming soon”만 두지 않음
