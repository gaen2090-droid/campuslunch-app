# 커뮤니티 자유게시판 투표 기능 기획서

> 참고: 에브리타임 글쓰기/피드/상세 UI 스크린샷 기반. 기존 `docs/PLAN_community_and_collections.md`(자유게시판 A장)에 이어지는 확장 기능.

## 0. 확정된 규칙

- 항목(옵션) 개수: **2~5개**, 글쓴이가 자유롭게 추가/삭제
- 응답 방식: **글쓴이가 투표 만들기 화면에서 "복수 선택 허용" 토글로 매 투표마다 결정**(UI 참고 캡처 기준). 껐으면 라디오 버튼처럼 1개만, 켰으면 여러 개 선택 가능. 게시된 투표는 이 값도 §0의 "수정 불가" 규칙 대상이라 이후 바꿀 수 없음.
- 마감 시간: **없음** — 공지글처럼 게시글이 삭제되기 전까지 계속 유효
- 결과 공개 시점: **투표 즉시 공개** (투표 전에도 각 옵션 텍스트는 보이되, 득표수/비율은 투표해야 보임 — 에브리타임 참고 이미지와 동일)
- 투표 여부/재투표: 1인 1회. 이미 투표한 옵션은 체크 표시, 재투표(선택 변경)는 허용하지 않음(에브리타임 참고 이미지에서 "투표하기" 버튼이 결과 화면으로 바뀌는 것과 동일한 흐름)

---

## 1. DB 스키마

기존 `community_posts`에 컬럼을 추가하지 않고 **별도 테이블 2개**로 분리한다. 이유: 좋아요(`community_likes`)와 동일 패턴을 따르는 게 일관적이고, 게시글당 옵션이 가변(2~5개)이라 배열 컬럼보다 정규화된 테이블이 다루기 쉽다 (옵션별 득표 집계, 이후 옵션 추가 편집 등에 유리).

```sql
-- 투표 옵션 (게시글당 2~5개)
create table public.community_poll_options (
  id         uuid primary key default gen_random_uuid(),
  post_id    uuid not null references public.community_posts(id) on delete cascade,
  label      text not null check (char_length(label) between 1 and 40),
  sort_order int not null default 0,
  vote_count int not null default 0   -- 비정규화 캐시. community_poll_votes insert/delete 시 트리거로 갱신
);
create index on public.community_poll_options (post_id, sort_order);

-- 투표 응답 (유저당 옵션별 1행 — 중복선택 허용이므로 유저가 여러 옵션에 각각 투표 가능)
create table public.community_poll_votes (
  option_id  uuid not null references public.community_poll_options(id) on delete cascade,
  user_id    uuid not null references public.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (option_id, user_id)
);
create index on public.community_poll_votes (user_id);
```

- `community_posts`에는 새 컬럼을 추가하지 않는다. "이 글에 투표가 있는가"는 `community_poll_options`에 해당 `post_id` 행이 있는지로 판단 — 좋아요/댓글과 동일한 방식.
- **게시 후 옵션 수정/삭제 전면 금지 + 글당 투표 1개** 규칙(위 §0)을 서버단에서도 강제한다:
  - `community_poll_options`에는 update/delete를 위한 RLS 정책을 아예 만들지 않는다(§1-1의 "poll options write own post" 정책은 **insert 전용**으로만 열어둔다 — `for all`이 아니라 `for insert`). 이러면 클라이언트가 어떤 경로로 시도하든 DB 레벨에서 update/delete가 막힌다.
  - "글당 투표 1개"는 `community_poll_options(post_id)`에 **unique 제약이 아니라 앱/RPC 로직으로 보장**한다 — 옵션이 여러 개(2~5개) 있는 게 정상이므로 unique는 안 맞고, 대신 옵션 insert RPC(`create_poll_for_post`, 아래 §1-2)가 "해당 post_id에 이미 옵션이 하나라도 있으면 거부"를 체크한다.

### 1-1. RLS

옵션 생성은 클라이언트가 테이블에 직접 insert하지 않고 **`create_poll_for_post` RPC(§1-2)를 통해서만** 하도록 한다 — "글당 투표 1개" 체크를 RPC 안에서 트랜잭션으로 강제해야 동시 요청 경합(더블탭 등)에도 안전하기 때문. 따라서 `community_poll_options`엔 클라이언트용 insert 정책도 두지 않고, select만 연다. update/delete 정책은 아예 만들지 않는다 — 정책이 없으면 RLS가 그 작업 자체를 거부하므로, 게시 후 수정/삭제가 원천적으로 막힌다(security definer RPC는 RLS를 우회하지만, 이 기능엔 수정/삭제 RPC 자체를 만들지 않을 것이므로 실질적으로 아무도 못 건드림).

```sql
alter table public.community_poll_options enable row level security;
alter table public.community_poll_votes   enable row level security;

-- 옵션: 게시글이 보이면(숨김 아니면) 누구나 조회. insert/update/delete 정책 없음
-- → 클라이언트발 쓰기는 전부 거부, 생성은 create_poll_for_post RPC(security definer)를 통해서만.
create policy "poll options select visible" on public.community_poll_options
  for select to authenticated using (
    exists (
      select 1 from public.community_posts p
      where p.id = post_id and (not p.is_hidden or public.is_admin())
    )
  );

-- 투표: 본인 투표만 insert. delete 정책 없음(재투표/취소 불가 — §0 "1인 1회, 재투표 불허"와 일치).
-- select는 본인 투표 여부 확인용으로 본인 것만 열어도 충분
-- (득표수는 vote_count 캐시로 노출하므로 전체 투표자 명단을 별도로 열 필요 없음).
create policy "poll votes insert own" on public.community_poll_votes
  for insert to authenticated with check (user_id = auth.uid());
create policy "poll votes select own" on public.community_poll_votes
  for select to authenticated using (user_id = auth.uid());
```

- `vote_count` 갱신: `community_bump_like_count()`(좋아요 카운트 트리거, `community_phase1.sql:114`)와 동일한 패턴으로 `community_poll_votes` insert/delete 시 `community_poll_options.vote_count`를 갱신하는 트리거를 추가한다. ⚠️ [[crowd-status-updated-at-trigger-bug]] 사례처럼 범용 트리거가 다른 테이블에 새지 않도록, 이 트리거는 `community_poll_votes`에만 정확히 바인딩한다.

### 1-2. RPC

- `create_poll_for_post(p_post_id uuid, p_options text[])`: 글 게시(또는 최초 수정) 시 옵션들을 한 번에 생성. **해당 post_id에 옵션이 이미 하나라도 존재하면 예외를 던져 거부**(글당 투표 1개 강제) — 글쓴이 본인 소유 게시글인지도 함께 검증.
- `submit_poll_vote(p_option_ids uuid[])`: 트랜잭션으로 여러 옵션에 한 번에 투표(중복선택이므로 여러 개 동시 제출). 같은 게시글의 옵션인지 검증, 이미 투표한 옵션은 재투표 거부(1인 1회 규칙 서버단 방어).
- `community_feed` / `community_post_detail` RPC에 다음 필드 추가:
  - `has_poll boolean` — 피드 카드에서 투표 아이콘 노출 여부 판단용
  - `poll_voter_count int` — 피드 카드에 "N명 참여" 표시용 (= 해당 게시글 poll_options의 vote_count 합이 아니라, **중복 투표를 고려해 distinct user 수**로 별도 집계 — 중복선택 시 한 유저가 여러 옵션에 투표해도 참여자 수는 1명으로 세야 함)
  - 상세 화면에서는 별도로 `community_poll_options_for_post(p_post_id)` RPC를 만들어 옵션별 `label, vote_count, voted_by_me` 배열을 반환

---

## 2. 글쓰기 화면 (`community_post_editor_sheet.dart`)

참고 이미지의 하단 액션바(사진 아이콘 옆 투표 아이콘)와 동일한 위치에 배치한다.

- 현재 하단 액션 Row(`_pickImages` 버튼, `_pickRestaurant` 버튼이 있는 행, 253~299행)에 **투표 아이콘 버튼 추가**.
- **별도 화면 방식**(에브리타임과 동일). 인라인으로 본문 화면에 끼워 넣지 않는 이유: 옵션 입력 UI 자체가 부피가 있어(입력창 여러 개 + 추가/삭제 버튼) 본문 작성 중인 화면에 섞으면 스크롤이 길어지고 포커스 전환이 번거로움 — 옵션 작성에만 집중하는 화면을 분리하는 편이 흐름이 명확함.
  - 투표 아이콘 탭 → `lib/screens/community_poll_editor_screen.dart`(신규, `MaterialPageRoute`로 push)로 이동
  - 이 화면: 옵션 입력 필드 2개로 시작(에브리타임 예시 "멋있다" / "안멋있다"처럼), **"+옵션 추가" 버튼**으로 최대 5개까지 늘림, 옵션이 2개일 땐 삭제 버튼 비활성(최소 2개 보장). 각 옵션 텍스트 최대 40자 제한.
  - 우측 상단 "완료" → 입력한 옵션 리스트를 들고 본문 작성 화면(`CommunityPostEditorSheet`)으로 `Navigator.pop`하며 복귀.
  - 본문 화면으로 돌아오면, 하단 액션 Row의 투표 버튼이 활성 상태(체크 표시)로 바뀌고, 본문 위/아래 어딘가에 **작성 중인 투표를 요약하는 카드**가 표시됨(옵션 개수 + 첫 옵션 미리보기, 예: "🗳 투표 · 2개 옵션"). **아직 게시 전(로컬 상태)이므로** 이 요약 카드를 탭하면 다시 편집 화면으로 돌아가 옵션을 자유롭게 고칠 수 있고, 카드 우측 X로 투표 자체를 취소할 수도 있음 — 아래 "게시 후 수정/삭제 전면 금지" 규칙은 **글이 실제로 게시된 이후**에만 적용됨.
  - 본문 작성 화면 자체에는 옵션 입력창을 두지 않는다 — 그 화면의 상태는 "투표 있음/없음 + 옵션 리스트(로컬 상태, 아직 서버 미전송)"만 들고 있으면 됨.
- 게시("게시하기" 탭) 시점에 `createPost` 호출과 함께 옵션 배열을 `create_poll_for_post` RPC로 한 번에 전송 — 이 시점부터 §1의 "게시 후 전면 수정/삭제 금지" 규칙이 발동한다.
- **수정 화면(`editing != null`)에서는 투표 관련 UI를 아예 노출하지 않는다** (에브리타임과 동일 — 게시된 글의 투표는 수정도 삭제도 전혀 불가능하므로, 편집 진입점 자체를 주지 않아 시도할 여지를 없앤다):
  - 이미 투표가 달린 글: 하단 액션 Row에서 투표 버튼을 숨기거나 비활성 처리, 투표 카드는 읽기 전용으로만 표시(상세 화면과 동일한 결과 뷰).
  - 아직 투표가 없는 글: 수정 화면에서도 투표 버튼이 정상 노출되어, **최초 1회에 한해** 투표를 새로 추가할 수 있음(§2 상단 흐름과 동일). 이 경우도 일단 게시(=수정 저장)되고 나면 그 즉시 수정 불가 상태로 잠김.
  - 한 번 게시되고 나면 그 글의 투표 상태(있음/없음, 옵션 내용)는 영구 고정 — 있던 투표를 지우고 새로 만드는 것도 불가능(§0).

---

## 3. 피드 목록 카드 (`community_post_card.dart`)

사용자가 지정한 대로 **"투표가 있다는 것만 알 수 있는 정도"**로만 표시한다 — 참고 이미지("멋있다 vs 안멋있다" 검색 결과 카드)처럼 옵션 내용이나 결과는 목록에서 노출하지 않는다.

- 좋아요/댓글 수가 나열되는 하단 메타 정보 Row에 **투표 아이콘 + 참여자 수**를 세 번째 항목으로 추가 (좋아요 · 댓글 · 🗳 56명). 에브리타임처럼 좋아요 아이콘을 투표 아이콘으로 대체하지 않는다 — 우리 카드 레이아웃은 자리가 충분하므로 셋을 나란히 노출.
- 본문 미리보기 텍스트나 이미지 썸네일 영역은 건드리지 않음. 투표 유무는 순수 인디케이터 역할.
- `has_poll`이 false인 일반 글은 지금과 완전히 동일하게 렌더링.

---

## 4. 게시글 상세 화면 (`community_post_detail_screen.dart`)

참고 이미지("투표 전" / "투표 후" 두 상태)를 그대로 따른다.

- 본문 아래(이미지가 있다면 이미지 다음), 관련 매장 칩보다 위에 **투표 카드** 배치:
  - 헤더: 투표 아이콘 + "투표" 라벨
  - **투표 전**: 옵션들이 버튼 형태로 나열, 하단에 "투표하기" 버튼(비활성 회색 → 1개 이상 선택 시 활성화). 중복선택 허용이므로 옵션 각각 체크박스처럼 다중 선택 가능.
  - **투표 후**: 옵션이 결과 바(득표율 %, 득표수)로 전환. 내가 선택한 옵션에 체크 표시 + 배경색 강조(참고 이미지의 연한 빨강 배경과 동일 톤 재사용 가능 — 기존 앱의 강조색 팔레트에서 하나 선택).
  - 하단에 "N명 참여 · N개 선택 가능" 문구 (참고 이미지 "55명 참여 · 1개 선택 가능" 형태 — 우리는 중복선택이므로 "최대 5개 선택 가능" 등으로 표기)
- 위젯 분리: `lib/widgets/community_poll_card.dart` 신설 (투표 전/후 두 상태를 한 위젯 안에서 `voted` 여부로 분기).
- 투표 액션: 옵션 탭 → 로컬에서 다중 선택 토글 → "투표하기" 버튼 탭 시 `submit_poll_vote` RPC 호출 → 성공하면 결과 상태로 즉시 전환(옵티미스틱 업데이트 후 서버 응답으로 vote_count 재조회).

---

## 5. 어드민 반영

- 신고/숨김 처리(`CommunityPage.tsx`)는 게시글 단위이므로 투표 유무와 무관하게 기존 로직 그대로 사용 — 게시글이 숨김 처리되면 RLS의 `poll options select visible` 정책에 의해 투표 카드도 함께 안 보이게 됨(추가 작업 불필요).
- 별도 투표 관리 UI는 만들지 않음 (투표는 게시글의 부속 요소이므로 게시글 관리로 충분).

---

## 6. 탈퇴 연쇄 (기존 문서 6장과 동일 원칙)

`rpc_delete_own_account.sql`에 추가:

```sql
delete from public.community_poll_votes where user_id = uid;
```

`community_poll_options`는 유저 FK가 없으므로(게시글을 통해서만 간접 연결) 불필요 — 게시글이 `community_posts` 삭제 라인에서 이미 cascade로 처리됨.

---

## 7. 구현 순서 제안

1. `community_poll_options` / `community_poll_votes` 테이블 + RLS + vote_count 트리거
2. `submit_poll_vote`, `community_poll_options_for_post` RPC + `community_feed`/`community_post_detail`에 `has_poll`, `poll_voter_count` 필드 추가
3. `CommunityRepository`에 `createPost(pollOptions:)`, `fetchPollOptions(postId)`, `submitPollVote(optionIds)` 추가
4. 글쓰기 화면: 투표 작성 인라인 UI
5. `community_poll_card.dart` 위젯 (투표 전/후) + 상세 화면 삽입
6. 피드 카드: 투표 인디케이터(아이콘 + 참여자 수)
7. `rpc_delete_own_account.sql` 갱신
