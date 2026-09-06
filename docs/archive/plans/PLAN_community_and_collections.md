# 커뮤니티 탭 + 맛집 컬렉션 기획서

> 작성: 구현 착수 전 세부 기획 단계. 승인 후 Phase 순서대로 구현.
> 확정된 결정: **글+댓글+좋아요** / **닉네임 표시** / **컬렉션은 앱 등록 매장만** / **게시판+컬렉션을 한 탭에**
> 추가 확정: **가이드라인 첫 진입 1회 안내** / **글 수정 가능** / **게시글 이미지 첨부 가능** / **게시글에 관련 매장 연결(등록 매장에서 선택)** / **작성 경과 시간(N분 전) 표시**
> 컬렉션 UI 확정: **캐치테이블 "추천" 탭 스타일 — 컬렉션은 세로 리스트, 각 컬렉션의 매장은 가로 스크롤(오른쪽 드래그) 카드**. 각 매장 카드 = 큰 사진 + 하단 매장명/지역·카테고리. **구독 기능은 넣지 않음.**

---

## 0. 큰 그림

지도 탭 옆에 **커뮤니티** 탭을 신설한다. 커뮤니티 탭 하나 안에 상단 세그먼트로 두 영역을 둔다.

```
하단 탭:  [사장님?] [홈] [지도] [커뮤니티] [MY]
                              └ 상단 세그먼트: [ 자유게시판 | 맛집 컬렉션 ]
```

- **자유게시판**: 유저가 자유롭게 글/댓글/좋아요. 닉네임 노출. 신고 + 관리자 삭제로 운영.
- **맛집 컬렉션**: 관리자가 웹 어드민에서 만든 큐레이션(예: "선배 추천 찐 맛집", "여기 모르면 간첩"). 앱에 이미 등록된 매장만 담고, 탭하면 기존 상세페이지로 이동. 유저는 읽기 전용.

세 개의 독립 산출물로 나눠 각각 승인/보류/단계화 가능:
- **A. 자유게시판** (앱 읽기/쓰기)
- **B. 운영/모더레이션** (방침 + 신고 + 웹 어드민)
- **C. 맛집 컬렉션** (어드민 작성, 앱 읽기 전용)

---

## A. 자유게시판

### A-1. DB 스키마 (Supabase)

세 테이블 모두 `users(id)`를 참조 → **탈퇴 처리(rpc_delete_own_account.sql)에 삭제 라인 필수** (아래 6장 참고).

```sql
-- 게시글
create table public.community_posts (
  id           uuid primary key default gen_random_uuid(),
  user_id      uuid not null references public.users(id) on delete cascade,
  content      text not null check (char_length(content) between 1 and 1000),
  image_urls   text[] not null default '{}',  -- 첨부 이미지(0~N장). Storage public URL
  restaurant_id <FK> references public.restaurants(id) on delete set null,  -- 관련 매장(선택)
  like_count   int  not null default 0,   -- 좋아요 비정규화 캐시
  comment_count int not null default 0,   -- 댓글 수 캐시
  is_hidden    boolean not null default false,  -- 관리자 숨김(soft delete)
  created_at   timestamptz not null default now(),
  updated_at   timestamptz               -- 수정 시각. null이면 미수정
);
create index on public.community_posts (created_at desc) where not is_hidden;
-- 관련 매장 삭제 시 게시글은 남기고 연결만 해제(set null). restaurant_id 타입은 restaurants.id에 맞춤.

-- 댓글
create table public.community_comments (
  id           uuid primary key default gen_random_uuid(),
  post_id      uuid not null references public.community_posts(id) on delete cascade,
  user_id      uuid not null references public.users(id) on delete cascade,
  content      text not null check (char_length(content) between 1 and 500),
  is_hidden    boolean not null default false,
  created_at   timestamptz not null default now()
);
create index on public.community_comments (post_id, created_at);

-- 좋아요 (유저당 게시글 1회)
create table public.community_likes (
  post_id   uuid not null references public.community_posts(id) on delete cascade,
  user_id   uuid not null references public.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (post_id, user_id)
);

-- 신고
create table public.community_reports (
  id          uuid primary key default gen_random_uuid(),
  reporter_id uuid not null references public.users(id) on delete cascade,
  post_id     uuid references public.community_posts(id) on delete cascade,
  comment_id  uuid references public.community_comments(id) on delete cascade,
  reason      text,
  created_at  timestamptz not null default now(),
  check (post_id is not null or comment_id is not null)
);
```

**닉네임 표시**: 게시글/댓글 조회 시 `users` 테이블과 조인해 닉네임을 가져온다. RLS로 `users` 전체 조회를 열지 않으려면, 조인된 닉네임만 반환하는 **security-definer 조회 뷰/RPC**로 노출한다. 관련 매장 이름도 함께 조인해 반환.
`community_feed(limit, before)` RPC 반환 필드:
`id, content, image_urls, nickname, restaurant_id, restaurant_name, like_count, comment_count, liked_by_me, created_at, updated_at`
→ **작성 경과 시간("N분 전")은 앱에서 `created_at` 기준으로 표시**(별도 컬럼 불필요). 수정글은 `updated_at`으로 "수정됨" 뱃지.

**이미지 첨부 스토리지**: Supabase Storage 버킷 `community`(public read). 업로드 정책은 `auth.uid()` 경로 기반. 게시글 삭제 시 이미지도 함께 정리(RPC 또는 앱에서 삭제 호출). MVP는 게시글당 최대 4장 제한.

### A-2. RLS 정책 (app_feedback 패턴 그대로)

```sql
alter table public.community_posts    enable row level security;
alter table public.community_comments enable row level security;
alter table public.community_likes    enable row level security;
alter table public.community_reports  enable row level security;

-- posts
create policy "posts insert own" on public.community_posts
  for insert to authenticated with check (user_id = auth.uid());
create policy "posts select visible" on public.community_posts
  for select to authenticated using (not is_hidden or public.is_admin());
create policy "posts delete own or admin" on public.community_posts
  for delete to authenticated using (user_id = auth.uid() or public.is_admin());
-- 수정: 본인 글만 수정. 관리자 숨김도 update지만 is_hidden만 바꾸므로 함께 허용.
create policy "posts update own or admin" on public.community_posts
  for update to authenticated
  using (user_id = auth.uid() or public.is_admin())
  with check (user_id = auth.uid() or public.is_admin());
-- (댓글도 동일 패턴. 좋아요는 insert/delete own. 신고는 insert own + select admin.)
```

- `like_count` / `comment_count`는 좋아요·댓글 insert/delete 시 **트리거로 갱신**.
  ⚠️ 과거 [[crowd-status-updated-at-trigger-bug]] 사례처럼 범용 트리거가 다른 테이블에 새는지 반드시 확인. 이 트리거는 대상 테이블에만 정확히 바인딩.

### A-3. 앱 측 구조

- 모델: `lib/models/community_post.dart`, `community_comment.dart`
- 리포지토리: `lib/repositories/community_repository.dart` (ProfileRepository 패턴)
  - `fetchFeed({before})`, `createPost(content, images, restaurantId)`, `updatePost(id, content, images, restaurantId)`, `deletePost(id)`, `toggleLike(id)`, `fetchComments(postId)`, `addComment(...)`, `report(...)`, `uploadImages(files)`
- 화면:
  - `lib/screens/community_screen.dart` — 상단 세그먼트(자유게시판 | 컬렉션) + 게시판 피드(무한 스크롤), 우하단 글쓰기 FAB
  - `lib/screens/community_post_detail_screen.dart` — 글(이미지·관련매장 칩 포함) + 댓글 목록 + 댓글 입력
  - 글쓰기/수정: 바텀시트(`feedback_sheet` 패턴). 구성:
    - 본문 입력
    - **이미지 첨부**(최대 4장, `image_picker`) — 썸네일 + 삭제
    - **관련 매장 선택**(선택 사항) — 등록 매장 검색 바텀시트에서 1개 선택, 선택 시 칩으로 표시·해제 가능
  - 피드/상세의 각 글 카드:
    - 상단: 닉네임 · **"N분 전"**(수정글은 "· 수정됨")
    - 본문 + 이미지 그리드
    - **관련 매장이 있으면 "관련 매장" 라벨 + 매장 칩** → 탭 시 기존 `DetailScreen`으로 이동
    - 하단: 좋아요 토글·수, 댓글 수
- 각 글/댓글에 `...` 메뉴 → 본인이면 **수정/삭제**, 아니면 신고.
- 시간 표시 유틸: `lib/utils/time_ago.dart` — "방금 전 / N분 전 / N시간 전 / N일 전 / 날짜".

### A-4. main_screen.dart 편집 지점 (인덱스 산술 — 리스트 추가가 아님)

지도는 커뮤니티와 **별도로 PlatformView 취급이 유지**돼야 한다. 커뮤니티는 일반 탭이라 `nonMapTabs`에 들어간다.

- `line 55`: clamp 상한 `hasOwner ? 3 : 2` → **`hasOwner ? 4 : 3`**
- `line 56`: `mapIndex = hasOwner ? 2 : 1` (그대로 — 지도 위치 불변)
- `nonMapTabs` (line 62–66): 순서가 인덱스와 맞아야 함. 새 순서
  `[사장님?, 홈, 지도(제외), 커뮤니티, MY]`.
  현재 `nonMapTabs`는 지도를 뺀 목록이며 `nonMapIndex` 산술로 매핑. 커뮤니티(지도 다음 인덱스)를 홈 뒤·MY 앞에 삽입:
  - non-owner 전체 인덱스: 홈0 / 지도1 / 커뮤니티2 / MY3
  - owner 전체 인덱스: 사장님0 / 홈1 / 지도2 / 커뮤니티3 / MY4
  - `nonMapTabs`(지도 제외): `[if(hasOwner) Owner, Home, CommunityScreen, MyScreen]`
  - 기존 `nonMapIndex` 공식(`index>mapIndex ? index-1 : index`)이 그대로 성립함(지도 하나만 빠지므로). ✅ 별도 수정 불필요 — 목록에 커뮤니티만 올바른 위치에 삽입하면 됨.
- `_BottomNav` items 두 배열(owner/non-owner)에 지도 다음에 `_NavItem(icon: Icons.forum_outlined, activeIcon: Icons.forum, label: '커뮤니티')` 삽입.

### A-5. 클라이언트 비속어 즉시 차단 (UX용, 1차 방어)

- `lib/utils/profanity_filter.dart` — 금칙어 리스트 기반. 글/댓글 등록 전 검사, 걸리면 "커뮤니티 이용 정책에 위배되는 표현이 포함되어 있어요" 스낵바로 차단.
- ⚠️ 정직하게: 이건 완벽 탐지가 아니라 즉시 피드백용. **실질 백본은 신고→관리자 삭제(B)**. 자동 탐지에 과의존하지 않음.

---

## B. 운영 / 모더레이션

### B-1. 커뮤니티 이용 방침(가이드라인)

- 문구 저장 위치: 기존 권한/약관 패턴 재사용. `assets/legal/community_guidelines.md` 또는 `PermissionDocumentScreen` 같은 뷰어.
- **최초 진입 시 1회 가이드라인 안내**: 커뮤니티 탭 첫 방문 시 "욕설/폭언/비속어·광고·개인정보 노출 금지, 위반 시 삭제·이용제한" 요지의 안내 시트 → "확인"으로 동의(로컬 플래그 저장). → **사용자 확인 필요 결정**: 1회 안내면 충분한지, 게시 버튼마다 재고지할지.

### B-2. 신고 흐름

유저 신고(`community_reports` insert) → 웹 어드민 신고함에서 관리자가 검토 → 숨김(is_hidden=true) 또는 삭제.

### B-3. 웹 어드민 (admin-web) — 커뮤니티 운영 탭

패턴: `AdminTab` 타입 + `ADMIN_TABS` 배열 항목 + `useXxx` 훅 + `adminApi.ts` 함수 + Page 컴포넌트.

- `admin-web/src/components/Tabs.tsx`: `ADMIN_TABS`에 `{ id: 'community', label: '커뮤니티' }` 추가, `AdminTab` 유니온에 `'community'`.
- `admin-web/src/pages/CommunityPage.tsx`: 신고함 / 최근 글 목록, 각 항목 숨김·삭제 버튼.
- `admin-web/src/hooks/useCommunity.ts`: 신고 목록, 글/댓글 목록, 숨김/삭제 액션.
- `admin-web/src/lib/adminApi.ts`: `fetchReports()`, `fetchRecentPosts()`, `hidePost(id)`, `deletePost(id)`, `hideComment`, `deleteComment`.
- 권한: 어드민 조회/수정은 `is_admin()` RLS로 보장(별도 서버 불필요).

---

## C. 맛집 컬렉션

### C-1. DB 스키마

```sql
create table public.collections (
  id          uuid primary key default gen_random_uuid(),
  title       text not null,              -- "선배들이 추천하는 찐 맛집"
  subtitle    text,                       -- 짧은 설명/부제(스샷의 "동북아의 허브..." 자리)
  sort_order  int not null default 0,     -- 노출 순서(위→아래)
  is_published boolean not null default false,
  created_at  timestamptz not null default now()
);
-- 커버 컬럼 없음. 컬렉션 카드는 담긴 매장들을 가로 스크롤로 직접 보여줌(캐치테이블 방식).
--   각 매장의 사진은 restaurants.imageUrl 사용.

-- 컬렉션에 담긴 매장 (앱 등록 매장만)
create table public.collection_items (
  id            uuid primary key default gen_random_uuid(),
  collection_id uuid not null references public.collections(id) on delete cascade,
  restaurant_id <FK> not null references public.restaurants(id) on delete cascade,
  note          text,                     -- "이 집 제육이 진리" 같은 한줄평(선택)
  sort_order    int not null default 0,
  unique (collection_id, restaurant_id)
);
```
> `restaurant_id` 타입은 `restaurants.id` 실제 타입에 맞춤(구현 시 확인). 매장만 참조하므로 유저 FK 없음 → 탈퇴 로직 영향 없음.

### C-2. RLS

```sql
-- 게시된 컬렉션은 모두 읽기, 관리자만 쓰기
create policy "collections read published" on public.collections
  for select to authenticated using (is_published or public.is_admin());
create policy "collections admin write" on public.collections
  for all to authenticated using (public.is_admin()) with check (public.is_admin());
-- collection_items: 부모 게시 여부 따라 읽기, 관리자만 쓰기 (동일 패턴)
```

### C-3. 앱 측

- 모델 `lib/models/collection.dart` (+ item).
- `community_repository`에 `fetchCollections()`, `fetchCollectionItems(id)` 추가(또는 별도 리포지토리).
- 커뮤니티 화면의 "맛집 컬렉션" 세그먼트 — **캐치테이블 "추천" 스타일**:
  - 세로 스크롤로 컬렉션들이 쌓임. 각 컬렉션 블록:
    - 헤더: **제목**(굵게) + `N개 매장`, 아래 `subtitle`(선택)
    - 그 아래 **가로 스크롤 매장 카드 리스트**(`ListView(scrollDirection: horizontal)`, 오른쪽으로 드래그) — 카드 = 큰 사진 위에 하단 그라데이션, 매장명 + `지역 · 카테고리`
  - 매장 카드 탭 → **기존 `DetailScreen`으로 이동**(restaurant_id로 조회).
  - 위젯: `lib/widgets/collection_section.dart`(컬렉션 1개 = 헤더+가로리스트), `collection_restaurant_card.dart`(가로 카드).
  - ※ 작성자 프로필/구독 버튼은 없음(어드민 큐레이션이므로).

### C-4. 웹 어드민 — 컬렉션 관리 탭

- `ADMIN_TABS`에 `{ id: 'collections', label: '맛집 컬렉션' }` 추가.
- `admin-web/src/pages/CollectionsPage.tsx`: 컬렉션 CRUD, 게시/비게시 토글, 컬렉션 노출 순서. 컬렉션 편집에서 **등록 매장 검색·선택**으로 아이템 추가(자유 입력 없음), 한줄평/**매장 노출 순서(가로 스크롤 순서)** 편집. 커버 지정 없음(가로 리스트가 곧 커버).
- `useCollections.ts` + `adminApi.ts`: 컬렉션/아이템 CRUD, 매장 검색(기존 restaurants 조회 재사용).

---

## 6. 회원 탈퇴 연쇄 (⚠️ 방금 고친 버그의 재발 방지)

`app_feedback` FK 위반으로 탈퇴 실패했던 것과 동일 구조가 새 테이블마다 재발한다.
`supabase/rpc_delete_own_account.sql`에서 `users` 삭제 **이전에** 다음 추가:

```sql
delete from public.community_reports  where reporter_id = uid;
delete from public.community_likes    where user_id = uid;
delete from public.community_comments where user_id = uid;
delete from public.community_posts    where user_id = uid;
```
> `on delete cascade`를 걸어두면 이론상 자동 삭제되지만, RPC가 명시적으로 지우는 기존 방식과 일관되게 라인 추가 권장(캐시 카운트 트리거와의 순서 문제도 예방). 컬렉션 테이블은 유저 FK가 없어 불필요.

---

## 7. 제안 구현 순서 (Phase)

1. **Phase 1 — 자유게시판 코어(A)**: 스키마+RLS → 리포지토리/모델 → 커뮤니티 탭 신설(게시판만) → 글/댓글/좋아요. 탈퇴 RPC 갱신.
2. **Phase 2 — 모더레이션(B)**: 신고 버튼 + 클라이언트 비속어 필터 + 가이드라인 안내 + 웹 어드민 커뮤니티 탭.
3. **Phase 3 — 맛집 컬렉션(C)**: 컬렉션 스키마 → 웹 어드민 컬렉션 관리 → 앱 컬렉션 세그먼트 + 상세 → DetailScreen 연결.

각 Phase 끝에 SQL은 사용자가 Supabase 대시보드에서 직접 실행.

---

## 8. 확정된 항목 (2차 결정 반영)

1. **가이드라인 고지**: 커뮤니티 첫 진입 시 **1회 안내**(확인 시 로컬 플래그 저장). 이후 미표시.
2. **글 수정**: **가능**. 본인 글만, `updated_at` 갱신 + "수정됨" 뱃지.
3. **이미지 첨부**: **가능**. 게시글당 최대 4장, Supabase Storage `community` 버킷.
4. **관련 매장**: 게시글에 등록 매장 1개 선택 가능. 피드/상세에 "관련 매장" 칩 표시 → `DetailScreen` 이동.
5. **작성 경과 시간**: "N분 전" 형식 표시(`created_at` 기준, 앱 계산).
6. **컬렉션 UI**: **캐치테이블 "추천" 스타일** — 컬렉션 세로 리스트, 각 컬렉션의 매장은 **가로 스크롤 카드**. 별도 커버 없음. **구독 기능 없음.**

### 남은 소소한 확인 (구현하며 기본안으로 진행, 이견 시 알려주세요)
- 관련 매장은 게시글당 **1개**로 제한(기본안). 여러 개 허용 원하면 알려주세요.
- 이미지 첨부 최대 **4장**(기본안).
