# 매장 2-Tier 분리 기획서 (제보용 vs 맛집컬렉션용)

> 배경: 출시 초기엔 제보 신뢰도 확보를 위해 매장을 30~40개 수준으로만 제보 대상 등록할 방침. 그런데 컬렉션(`docs/PLAN_community_and_collections.md`의 C. 맛집 컬렉션)은
> "앱에 등록된 매장만" 담을 수 있게 설계돼 있어서, 등록 매장이 적으면 컬렉션도 빈약해진다.
> → **"앱에 등록된 매장" 집합을 하나가 아니라 두 개(제보 대상 / 정보 전용)로 나눈다.** 테이블은 그대로 두고 플래그로 구분.
> **주의**: 이 문서 전체의 "30~40개"는 초기 운영 방침일 뿐 시스템 제약이 아니다. DB/코드 어디에도 제보 대상 매장 개수를 제한하는 로직은 넣지 않는다 — 어드민에서 몇 개를 `crowd_enabled=true`로 등록하든 자유이며, 언제든 원하는 만큼 늘릴 수 있다.

---

## 0. 결론 요약

- `restaurants` 테이블은 하나로 유지. **새 컬럼 `crowd_enabled boolean not null default true`** 추가.
  - `is_active`는 지금 의미(행이 살아있는지 / 앱 전체 노출 여부) 그대로 유지 — **재활용하지 않는다.**
    이유: `is_active=false`는 이미 "비활성화(폐업 등)" 의미로 쓰이고 있고, RLS SELECT 정책이 `is_active=true`만 허용하므로
    `is_active=false`로 컬렉션 전용 매장을 표현하면 **앱 클라이언트가 그 행을 아예 읽지 못해 컬렉션 카드/상세페이지가 깨진다.**
  - `crowd_enabled = true` → 지금의 30~40개, 제보 가능한 "정식 매장".
  - `crowd_enabled = false` → 컬렉션 전용 "정보성 매장". `is_active`는 true로 둬서 앱에서 정상 조회는 되지만, 혼잡도 제보 기능은 꺼져 있음.
- 어드민에서 매장별로 `crowd_enabled` 토글 가능. 수요 늘면 **"제보 대상으로 승격"** 버튼 하나로 전환(코드 수정 없음, 기존 계획 그대로 유지).

---

## 1. 왜 `is_active` 재사용이 안 되는가 (확인된 사실)

- `lib/data/supabase_restaurant_repository.dart:33` — 일반 유저 조회는 `.eq('is_active', true)`만 가져옴. `includeInactive`는 어드민 전용 플래그.
- `supabase/policies.sql:34` — RLS SELECT 정책 자체가 `using (is_active = true)`. 즉 `is_active=false`는 **DB 레벨에서 일반 유저에게 완전히 안 보임.**
- 결론: 컬렉션 전용 매장을 `is_active=false`로 넣으면 컬렉션 카드는 만들어져도 실제 앱에서 그 매장 행을 못 읽어서 이미지·이름·상세페이지가 전부 깨진다.
- 따라서 "앱에 보이되 제보만 안 되는" 상태를 표현할 새 축이 필요 → `crowd_enabled`.

---

## 2. 스키마 변경

```sql
alter table public.restaurants
  add column crowd_enabled boolean not null default true;

-- 기존 30~40개는 전부 true로 유지되므로 백필 불필요(default true).
-- 신규로 "컬렉션 전용"으로 추가하는 매장만 등록 시 crowd_enabled=false로 넣는다.
```

- `is_active`와 `crowd_enabled`는 독립 축:
  | is_active | crowd_enabled | 의미 |
  |---|---|---|
  | true | true | 정식 매장 (지금의 30~40개) — 지도/홈 노출 + 제보 가능 |
  | true | false | 컬렉션 전용 매장 — 앱에 보이고 상세페이지 있지만 혼잡도 제보 불가 |
  | false | (무관) | 비활성 매장 — 지금과 동일하게 앱에서 완전히 숨김 |

---

## 3. 앱(Flutter) 반영 지점

### 3-1. 목록/지도/검색 — 정식 매장만
- `fetchAll()`이 지도·홈·매장 리스트에 쓰이는 경로는 `crowd_enabled=true` 조건을 추가해야 한다. (`is_active=true` 조건에 `and crowd_enabled=true` 추가, 혹은 별도 파라미터)
- **이유**: 컬렉션 전용 매장까지 지도/리스트에 섞이면 거기서도 "제보필요" 뱃지가 붙어버려 지금 피하려는 신뢰도 문제가 그대로 재발한다.
- 반대로 **컬렉션 세로 리스트**(`community_repository.fetchCollectionItems`)는 `crowd_enabled` 무관하게 전체 풀에서 매장을 끌어와야 한다 — 컬렉션이 정보 전용 매장을 담는 목적 자체이므로.

### 3-2. `Restaurant` 모델
- `lib/models/restaurant.dart`에 `final bool crowdEnabled;` 필드 추가 (기존 `isActive`와 나란히).

### 3-3. DetailScreen — 정보 전용 변형 (확정, `lib/screens/detail_screen.dart` 기준)

`crowdEnabled == false`인 매장은 기존 `DetailScreen`에 아래 분기만 추가하면 된다(새 화면 불필요):

- **사진 캐러셀 + 헤더(뒤로가기/북마크/공유)**: 그대로.
- **이름 + 지역·카테고리 + 우측 상태 컬럼** (259~336행 `Row`): `Row` 레이아웃·좌측 정렬은 그대로 두고, **우측 상태 컬럼(`ConstrainedBox`, 292~332행)만 `if (r.crowdEnabled) ...`로 아예 안 그림.** 매장명 위치/정렬은 지금과 동일하게 유지 (폭을 넓게 채우지 않음 — 그냥 비어있는 것).
- **영업시간 섹션 (`BusinessHoursSection`)**: 그대로 유지.
- **바로 아래에 신규 안내 배너 추가**: "제보 기능을 준비 중이에요. 곧 만나요!" — 회색 톤(기존 "AI 혼잡도 예측 예정" 배너와 동일한 스타일의 `Container`, `Color(0xFFF3F4F6)` 배경 + `Color(0xFF9CA3AF)` 텍스트 재사용).
- **사장님 공지 배너(`_OwnerNoticeBanner`) / 사장님 좌석 메시지 카드(`OwnerSeatMessageCard`)**: 표시하지 않음. 사장님 영입 자체가 제보 대상 매장에만 이뤄지므로 실제로 데이터가 없겠지만, 방어적으로 `r.crowdEnabled` 조건을 걸어둔다.
- **최근 제보 섹션(`_RecentReportsSection`)**: 표시 안 함. `initState`의 `_loadRecentReports()` 호출도 스킵.
- **"AI 혼잡도 예측 예정" 배너 (354~382행)**: 표시 안 함 — 위에서 추가한 "제보 기능 준비 중" 배너로 대체되는 자리이므로 중복 방지.
- **메뉴 섹션**: 그대로 유지.
- **`initState`의 진입 시 제보 유도 시트(`ReportSheet.show`)**: 호출 안 함.
- **하단 플로팅 버튼**: `_ActionButtonBar`에 이미 `showReportButton: bool` 파라미터가 있고, `false`일 때 길찾기 버튼만 단독 표시되는 레이아웃이 구현돼 있음(사장님 미리보기 때 쓰는 패턴 재사용). `showReportButton: !provider.hasOwnerTab && r.crowdEnabled` 정도로 조건만 추가하면 됨.

정리하면 이번 변경은 **기존 `DetailScreen`에 `r.crowdEnabled` 분기 몇 개를 추가하는 것**으로 끝난다 — 별도 화면/위젯 트리를 새로 만들 필요 없음.

### 3-4. 제보 서버 방어
- `supabase/submit_crowd_report.sql` RPC에 `crowd_enabled=false`인 매장에 대한 제보는 **서버에서 거부**하도록 체크 추가. (버튼 숨김은 클라이언트 우회 가능하므로 서버가 최종 방어선)

### 3-5. crowd_status / 배치 스윕
- `crowd_status` 관련 잡(제보필요 판정 스윕, [[crowd-status-updated-at-trigger-bug]] 참고)과 피크푸시(`peak_push_personalized.sql`)는 `crowd_enabled=true`인 매장만 대상으로 순회하도록 WHERE 조건 추가.
- 컬렉션 전용 매장은 애초에 `crowd_status` 행을 만들지 않는 편이 트리거 버그류 재발을 막기에 안전(과거 [[crowd-status-updated-at-trigger-bug]] 교훈 — "필터링 잊는 숨은 코드"가 항상 문제였음).

### 3-6. 북마크
- 북마크 리스트(`lib/screens/bookmark_list_screen.dart`)에서도 컬렉션 전용 매장이 북마크되면 3-3과 동일한 정보 전용 변형으로 렌더링해야 함.

### 3-7. 사장님 클레임
- `crowd_enabled=false`인 매장을 사장님이 claim(`rpc_claim_owner.sql`)하면 어떻게 할지 결정 필요:
  - **권장**: claim 성공 시 자동으로 `crowd_enabled=true`로 승격. 사장님이 매장을 관리하겠다고 나선 시점이 곧 "제보 신뢰도를 뒷받침할 실사용자가 생겼다"는 신호이므로 수동 승격을 기다릴 이유가 없음.

---

## 4. 어드민(admin-web) 반영 지점

- 매장 등록/수정 폼에 **"제보 대상 여부"** 토글 추가 (`crowd_enabled`). 기본값 ON.
- 매장 목록: 기본 필터는 "제보 대상만"(지금 운영 감각과 동일), 토글로 "컬렉션 전용 포함 전체 보기" 전환.
- **승격 버튼**: 컬렉션 전용 매장 행에 "제보 대상으로 전환" 원클릭 액션 → `crowd_enabled=true` 업데이트. (수요 늘 때 이 버튼 하나로 끝나야 애초 기획 의도인 "코드 수정 없이 순차 추가"가 유지됨)
- 컬렉션 관리 탭(`CollectionsPage.tsx`)의 매장 검색은 `crowd_enabled` 무관하게 **전체 매장 풀**에서 검색되도록 (지금 계획대로 두면 됨 — 원래도 `restaurants` 전체를 대상으로 검색하게 설계돼 있었음, 필터 걸지 않도록 주의).

---

## 5. 커뮤니티 자유게시판 — 관련 매장 선택

- 게시글의 "관련 매장 선택"(`PLAN_community_and_collections.md` A-3)은 `crowd_enabled` 무관하게 전체 풀에서 선택 가능해야 한다.
  - 컬렉션 전용 매장도 유저 입소문의 대상이 될 수 있으므로 좁힐 이유가 없음.

---

## 6. 검색/지도/홈 노출 방식 (확정)

**결론**: 평소 지도·홈 리스트는 `crowd_enabled=true`만 보여주고(지금과 동일), **검색으로 찾아 들어간 경우에만** 컬렉션 전용 매장을 노출한다.

- 검색은 "정보를 찾으러 왔다"는 목적이 뚜렷하므로 전체 풀에서 검색되어야 함. 반대로 지도/홈은 "지금 붐빔 여부를 확인"하는 화면이라 컬렉션 전용 매장이 평소에 섞이면 헷갈림.
- **검색 결과 카드에는 혼잡도 배지를 아예 넣지 않는다** (배지 있음=제보 대상, 배지 없음=컬렉션 전용이라는 규칙을 디자인만으로 학습되게 함). "혼잡도 정보 없음" 같은 별도 라벨은 상태값을 하나 더 늘려 배지 체계를 복잡하게 만들고 직관적이지 않아 채택하지 않음.
- **지도**: 평소엔 `crowd_enabled=true` 매장만 마커+매장명 표시. 검색으로 컬렉션 전용 매장을 선택한 경우에만:
  - 그 위치로 카메라 이동
  - 그 매장 마커 1개만 임시로 표시(색은 `영업안함`과 같은 무채색 계열 재사용 — 다만 완전 동일 색이면 "폐업했나?" 오인 소지 있어 아이콘/명도 차등은 구현 시 조정 여지 있음)
  - 탭 시 DetailScreen(정보 전용 변형, 3-3 참고)으로 이동
  - 검색 이탈/다른 검색 시 이 임시 마커는 사라짐 → 지도 상태 관리에 "검색으로 선택된 매장 1개"를 위한 별도 상태 분기 필요
- **홈 리스트**도 동일 패턴: 평소 리스트는 `crowd_enabled=true`만, 검색 시엔 전체 풀에서 찾아지고 탭하면 DetailScreen(정보 전용)으로 이동.

---

## 7. 운영 관점 — 컬렉션 전용 매장은 어떻게 채우나

정식 매장(제보 대상)과 달리 컬렉션 전용 매장은 실시간 혼잡도가 없으므로, 등록 시 최소 정보(이름/카테고리/주소/사진/메뉴 정도)만 있으면 된다.
어드민에서 매장 등록 시 처음부터 `crowd_enabled=false`로 대량 등록해두고, 관리자가 그 중 일부를 골라 컬렉션에 큐레이션하는 흐름이 자연스럽다.
→ 매장 소스: 기존에 후보로 검토했으나 30~40개에서 탈락한 곳들, 자유게시판에서 유저가 언급/추천한 매장 등을 컬렉션 전용 풀로 우선 채우면 좋음.

---

## 8. 구현 순서 제안

1. `restaurants.crowd_enabled` 컬럼 추가 (default true, 백필 불필요).
2. 리스트/지도/검색/제보/crowd_status/푸시 배치 — `crowd_enabled=true` 필터 추가 (3-1, 3-5).
3. `submit_crowd_report` RPC 서버 방어 (3-4).
4. `Restaurant` 모델 필드 + DetailScreen 정보 전용 변형 (3-2, 3-3, 3-6).
5. 어드민 토글 + 승격 버튼 + 필터 (4).
6. `rpc_claim_owner` 자동 승격 (3-7).
7. 맛집 컬렉션(C, `PLAN_community_and_collections.md`) 구현 시 컬렉션 전용 매장 풀을 자연스럽게 활용.

이 변경은 `PLAN_community_and_collections.md`의 컬렉션 스키마(C-1)를 그대로 두고, `restaurants` 쪽에만 컬럼을 추가하는 것이므로 컬렉션 문서 자체는 수정할 필요 없음 — 컬렉션은 원래도 "restaurants 테이블의 매장"만 참조하도록 설계돼 있었고, 그 참조 대상 풀이 이제 정식+컬렉션전용 전체가 되는 것뿐.
