# 기프티콘 CSV 일괄 등록 가이드

어드민(앱·웹)에서 기프티콘을 한 번에 등록할 때 쓰는 CSV 형식과 작업 순서입니다.

---

## 한눈에 보는 흐름

```
① 기프티콘 이미지 준비
        ↓
② Supabase Storage (gifticons 버킷)에 업로드
        ↓
③ CSV 작성 (아래 템플릿)
        ↓
④ 어드민 → 기프티콘 탭 → 「CSV 업로드」
        ↓
⑤ DB에 unassigned(미배정) 상태로 저장
        ↓
⑥ 유저 20스탬프 달성 → 자동 기프티콘 지급 (초과분은 이월, 예: 19+2→1/20)
```

---

## 템플릿 파일

| 파일 | 용도 |
|------|------|
| [`docs/templates/gifticon_upload_template.csv`](templates/gifticon_upload_template.csv) | 예시 3건 포함 — 복사해서 수정 |
| [`docs/templates/gifticon_upload_blank.csv`](templates/gifticon_upload_blank.csv) | 헤더만 — 새로 채울 때 |

---

## 컬럼 설명

| 컬럼 (영문 그대로) | 필수 | 설명 | 예시 |
|-------------------|:----:|------|------|
| `brand` | ✅ | 브랜드·매장명 | `바나프레소` |
| `product_name` | ✅ | 상품명 (유저 쿠폰함에 표시) | `아메리카노 Tall` |
| `image_url` | ✅ | Storage **경로** (URL 아님) | `gifticons/20260601_001.jpg` |
| `expires_at` | ⬜ | 유효기간 `YYYY-MM-DD` | `2026-12-31` |
| `coupon_code` | ⬜ | 바코드·내부 관리용 코드 | `BNF-AMER-001` |

> **주의:** 1행 헤더는 **영문 소문자** 그대로 써야 합니다.  
> `brand`, `product_name`, `image_url` 세 개는 순서·철자가 틀리면 업로드가 실패합니다.

---

## Excel / Google Sheets에서 보기 좋게 편집하기

CSV는 텍스트 파일이라 열 너비가 저장되지 않습니다. 편집할 때만 아래 너비를 참고하세요.

| 열 | 권장 너비 (Excel) | 비고 |
|----|------------------|------|
| A `brand` | 14 | 브랜드명 |
| B `product_name` | 18 | 상품명 |
| C `image_url` | 40 | 경로가 길어서 넓게 |
| D `expires_at` | 12 | `2026-12-31` |
| E `coupon_code` | 16 | 선택 |

**Excel 팁**

1. `gifticon_upload_template.csv` 더블클릭으로 열기
2. 한글이 깨지면: **데이터 → 텍스트/CSV 가져오기 → UTF-8** 로 열기
3. 열 너비 조정 후 **다른 이름으로 저장 → CSV UTF-8**

**Google Sheets 팁**

1. 파일 → 가져오기 → 업로드
2. 구분 기호: **쉼표**
3. 열 너비 드래그로 조정 후 **파일 → 다운로드 → 쉼표로 구분(.csv)**

---

## image_url 작성 규칙

`image_url`에는 **웹 주소(https://…)가 아니라 Storage 경로**를 넣습니다.

```
gifticons/파일명.jpg
```

### 이미지 업로드 방법

**방법 A — 어드민 단건 등록으로 경로 확인**

1. 어드민 → 기프티콘 → 「+ 등록」으로 이미지 1장 업로드
2. Supabase Dashboard → Storage → `gifticons` 버킷에서 파일명 확인
3. CSV의 `image_url`에 `gifticons/확인한파일명` 형식으로 입력

**방법 B — Storage에 직접 업로드**

1. Supabase Dashboard → Storage → `gifticons` (private 버킷)
2. 기프티콘 이미지 업로드
3. 경로 예: `gifticons/20260601_batch_001.jpg`

### 파일명 규칙 (권장)

```
gifticons/YYYYMMDD_순번_상품약어.jpg
```

예: `gifticons/20260601_001_americano.jpg`

- 공백·한글 파일명은 피하는 것이 좋습니다.
- 확장자: `.jpg`, `.png`, `.webp`

---

## CSV 작성 예시

```csv
brand,product_name,image_url,expires_at,coupon_code
바나프레소,아메리카노 Tall,gifticons/20260601_001_americano.jpg,2026-12-31,BNF-001
바나프레소,카페라떼 Tall,gifticons/20260601_002_latte.jpg,2026-12-31,BNF-002
메가커피,아메리카노,gifticons/20260601_003_mega.jpg,,
```

- `expires_at`, `coupon_code`가 없으면 **빈 칸**으로 두면 됩니다.
- 마지막 행 뒤에 **빈 줄 여러 개**는 넣지 마세요 (무시되지만 혼란만 줍니다).

---

## 업로드 위치

| 클라이언트 | 경로 |
|-----------|------|
| **앱** | 어드민 → 기프티콘 탭 → 「CSV 업로드」 |
| **웹** | 어드민 → 기프티콘 → 「CSV 업로드」 |

성공 시 `CSV로 기프티콘 N건 등록했어요.` 메시지가 표시됩니다.

---

## 등록 후 상태

| DB status | 의미 |
|-----------|------|
| `unassigned` | 미배정 — 유저 교환 대기 |
| `assigned` | 유저에게 지급됨 |
| `used` | 유저가 「사용 완료」 처리 |

---

## 자주 나는 오류

| 메시지 | 원인 | 해결 |
|--------|------|------|
| `CSV 헤더: brand, product_name, image_url 필수` | 헤더 철자·순서 오류 | 1행을 템플릿과 동일하게 |
| `유효한 CSV 행이 없어요` | 필수 칸 비어 있음 | brand·product_name·image_url 모두 입력 |
| `CSV에 데이터 행이 없어요` | 예시 행 없음 | 헤더 아래 최소 1행 추가 |
| 업로드는 됐는데 쿠폰 이미지 안 보임 | `image_url` 경로 불일치 | Storage 실제 경로와 CSV 일치 확인 |
| `관리자만…` | admin 권한 없음 | Supabase `role=admin` 계정으로 로그인 |

---


## 체크리스트 (업로드 전)

- [ ] Storage `gifticons` 버킷에 이미지 업로드 완료
- [ ] CSV `image_url` = `gifticons/…` 경로와 실제 파일 일치
- [ ] 1행 헤더: `brand,product_name,image_url,expires_at,coupon_code`
- [ ] `expires_at` 형식: `YYYY-MM-DD` (하이픈)
- [ ] UTF-8로 저장 (Excel: CSV UTF-8)
- [ ] Supabase admin 계정으로 로그인
