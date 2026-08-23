-- 커뮤니티 사용자 차단 (App Store 심사 가이드라인 1.2 - UGC 안전장치)
-- Dashboard → SQL Editor → Run
--
-- ⚠️ community_feed / community_comments_for_post / community_post_by_id /
--    community_pinned_posts / collection_comments_for_collection 5개는
--    community_admin_badge.sql(is_author_admin 추가판)이 최종 정본이다.
--    이 파일을 재실행해도 무방하지만(차단 필터는 여기 그대로 있음), 그 뒤에
--    반드시 community_admin_badge.sql을 다시 실행해 관리자 뱃지 컬럼을 복원할 것.
--
-- 이 파일이 아래 RPC의 정본이다. community_owner_active_restaurant.sql /
--    community_owner_display_name.sql / community_notifications.sql /
--    community_post_pin_order.sql / collection_comment_likes_replies.sql /
--    community_my_activity.sql 의 같은 이름 함수는 이 파일로 대체됐다.
--    (옛 파일을 다시 실행하면 차단 필터가 사라진다 — 재실행 금지)
--
--    정본 대상: community_feed, community_comments_for_post,
--              community_post_by_id, community_pinned_posts,
--              community_my_commented_posts, collection_comments_for_collection
--
-- 실행 순서: community_owner_active_restaurant.sql, collection_comment_likes_replies.sql,
--            community_post_pin_order.sql 이후

-- ── 1. 차단 테이블 ──

create table if not exists public.community_blocks (
  blocker_id uuid not null references public.users(id) on delete cascade,
  blocked_id uuid not null references public.users(id) on delete cascade,
  reason     text,
  created_at timestamptz not null default now(),
  primary key (blocker_id, blocked_id),
  constraint community_blocks_no_self check (blocker_id <> blocked_id)
);

create index if not exists community_blocks_blocker_idx
  on public.community_blocks (blocker_id);
create index if not exists community_blocks_blocked_idx
  on public.community_blocks (blocked_id);

alter table public.community_blocks enable row level security;

drop policy if exists "blocks select own" on public.community_blocks;
create policy "blocks select own" on public.community_blocks
  for select to authenticated using (blocker_id = auth.uid() or public.is_admin());

drop policy if exists "blocks insert own" on public.community_blocks;
create policy "blocks insert own" on public.community_blocks
  for insert to authenticated with check (blocker_id = auth.uid());

drop policy if exists "blocks delete own" on public.community_blocks;
create policy "blocks delete own" on public.community_blocks
  for delete to authenticated using (blocker_id = auth.uid());

-- ── 2. 차단 판정 헬퍼 ──
-- 양방향: 내가 차단했거나 상대가 나를 차단했으면 서로 노출되지 않는다.

create or replace function public.is_blocked_with(p_user_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.community_blocks b
    where (b.blocker_id = auth.uid() and b.blocked_id = p_user_id)
       or (b.blocker_id = p_user_id and b.blocked_id = auth.uid())
  );
$$;

revoke all on function public.is_blocked_with(uuid) from public;
grant execute on function public.is_blocked_with(uuid) to authenticated;

-- ── 3. 차단 / 차단 해제 / 목록 ──
-- 차단 시 신고(community_reports)를 함께 남겨 운영자에게 통지한다.
-- community_reports는 post_id 또는 comment_id 중 하나가 필수(check 제약)이므로
-- 차단을 실행한 화면의 글·댓글 id를 함께 넘긴다.

create or replace function public.block_user(
  p_user_id    uuid,
  p_reason     text default null,
  p_post_id    uuid default null,
  p_comment_id uuid default null
)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.uid() is null then
    raise exception '로그인이 필요해요.';
  end if;

  if p_user_id is null or p_user_id = auth.uid() then
    raise exception '자기 자신은 차단할 수 없어요.';
  end if;

  if not exists (select 1 from public.users u where u.id = p_user_id) then
    raise exception '대상을 찾을 수 없어요.';
  end if;

  insert into public.community_blocks (blocker_id, blocked_id, reason)
  values (auth.uid(), p_user_id, p_reason)
  on conflict (blocker_id, blocked_id) do nothing;

  if p_post_id is not null or p_comment_id is not null then
    insert into public.community_reports (reporter_id, post_id, comment_id, reason)
    values (
      auth.uid(),
      p_post_id,
      p_comment_id,
      coalesce(nullif(trim(p_reason), ''), '사용자 차단')
    );
  end if;
end;
$$;

revoke all on function public.block_user(uuid, text, uuid, uuid) from public;
grant execute on function public.block_user(uuid, text, uuid, uuid) to authenticated;

create or replace function public.unblock_user(p_user_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.uid() is null then
    raise exception '로그인이 필요해요.';
  end if;

  delete from public.community_blocks
  where blocker_id = auth.uid() and blocked_id = p_user_id;
end;
$$;

revoke all on function public.unblock_user(uuid) from public;
grant execute on function public.unblock_user(uuid) to authenticated;

create or replace function public.my_blocked_users()
returns table (
  user_id    uuid,
  nickname   text,
  created_at timestamptz
)
language sql
stable
security definer
set search_path = public
as $$
  select
    b.blocked_id as user_id,
    coalesce(u.nickname, '탈퇴한 사용자') as nickname,
    b.created_at
  from public.community_blocks b
  left join public.users u on u.id = b.blocked_id
  where b.blocker_id = auth.uid()
  order by b.created_at desc;
$$;

revoke all on function public.my_blocked_users() from public;
grant execute on function public.my_blocked_users() to authenticated;

-- ── 4. 피드 RPC 재정의: author_id 반환 + 차단 사용자 제외 ──
-- 기반: community_owner_active_restaurant.sql (author_owner_restaurant_id 스냅샷 방식)

drop function if exists public.community_feed(int, timestamptz, text);

create or replace function public.community_feed(
  p_limit int default 20,
  p_before timestamptz default null,
  p_query text default null
)
returns table (
  id uuid,
  author_id uuid,
  content text,
  image_urls text[],
  nickname text,
  restaurant_id uuid,
  restaurant_name text,
  like_count int,
  comment_count int,
  liked_by_me boolean,
  created_at timestamptz,
  updated_at timestamptz,
  is_owner boolean,
  is_author_owner boolean
)
language sql
stable
security definer
set search_path = public
as $$
  select
    p.id,
    p.user_id as author_id,
    p.content,
    p.image_urls,
    coalesce(ro.name || ' 사장님', u.nickname) as nickname,
    p.restaurant_id,
    r.name as restaurant_name,
    p.like_count,
    p.comment_count,
    exists (
      select 1 from public.community_likes l
      where l.post_id = p.id and l.user_id = auth.uid()
    ) as liked_by_me,
    p.created_at,
    p.updated_at,
    (p.user_id = auth.uid()) as is_owner,
    (ro.id is not null) as is_author_owner
  from public.community_posts p
  join public.users u on u.id = p.user_id
  left join public.restaurants r on r.id = p.restaurant_id
  left join public.restaurants ro
    on ro.id = p.author_owner_restaurant_id and ro.is_active
  where not p.is_hidden
    and not public.is_blocked_with(p.user_id)
    and (p_before is null or p.created_at < p_before)
    and (
      p_query is null
      or trim(p_query) = ''
      or p.content ilike '%' || replace(replace(trim(p_query), '%', '\%'), '_', '\_') || '%'
      or r.name ilike '%' || replace(replace(trim(p_query), '%', '\%'), '_', '\_') || '%'
      or exists (
        select 1 from public.community_comments c
        where c.post_id = p.id
          and not c.is_hidden
          and c.content ilike '%' || replace(replace(trim(p_query), '%', '\%'), '_', '\_') || '%'
      )
    )
  order by p.created_at desc
  limit p_limit;
$$;

revoke all on function public.community_feed(int, timestamptz, text) from public;
grant execute on function public.community_feed(int, timestamptz, text) to authenticated;

drop function if exists public.community_comments_for_post(uuid);

create or replace function public.community_comments_for_post(p_post_id uuid)
returns table (
  id uuid,
  author_id uuid,
  content text,
  nickname text,
  created_at timestamptz,
  is_owner boolean,
  is_author_owner boolean,
  like_count int,
  liked_by_me boolean,
  parent_comment_id uuid
)
language sql
stable
security definer
set search_path = public
as $$
  select
    c.id,
    c.user_id as author_id,
    c.content,
    coalesce(ro.name || ' 사장님', u.nickname) as nickname,
    c.created_at,
    (c.user_id = auth.uid()) as is_owner,
    (ro.id is not null) as is_author_owner,
    c.like_count,
    exists (
      select 1 from public.community_comment_likes l
      where l.comment_id = c.id and l.user_id = auth.uid()
    ) as liked_by_me,
    c.parent_comment_id
  from public.community_comments c
  join public.users u on u.id = c.user_id
  left join public.restaurants ro
    on ro.id = c.author_owner_restaurant_id and ro.is_active
  where c.post_id = p_post_id
    and not c.is_hidden
    and not public.is_blocked_with(c.user_id)
  order by c.created_at asc;
$$;

revoke all on function public.community_comments_for_post(uuid) from public;
grant execute on function public.community_comments_for_post(uuid) to authenticated;

-- ── 5. 단건 조회 / 핀 / 내 활동 / 컬렉션 댓글에도 동일 적용 ──

drop function if exists public.community_post_by_id(uuid);

create or replace function public.community_post_by_id(p_post_id uuid)
returns table (
  id uuid,
  author_id uuid,
  content text,
  image_urls text[],
  nickname text,
  restaurant_id uuid,
  restaurant_name text,
  like_count int,
  comment_count int,
  liked_by_me boolean,
  created_at timestamptz,
  updated_at timestamptz,
  is_owner boolean,
  is_author_owner boolean
)
language sql
stable
security definer
set search_path = public
as $$
  select
    p.id,
    p.user_id as author_id,
    p.content,
    p.image_urls,
    coalesce(ro.name || ' 사장님', u.nickname) as nickname,
    p.restaurant_id,
    r.name as restaurant_name,
    p.like_count,
    p.comment_count,
    exists (
      select 1 from public.community_likes l
      where l.post_id = p.id and l.user_id = auth.uid()
    ) as liked_by_me,
    p.created_at,
    p.updated_at,
    (p.user_id = auth.uid()) as is_owner,
    (ro.id is not null) as is_author_owner
  from public.community_posts p
  join public.users u on u.id = p.user_id
  left join public.restaurants r on r.id = p.restaurant_id
  left join public.restaurants ro
    on ro.id = p.author_owner_restaurant_id and ro.is_active
  where p.id = p_post_id
    and not p.is_hidden
    and not public.is_blocked_with(p.user_id);
$$;

revoke all on function public.community_post_by_id(uuid) from public;
grant execute on function public.community_post_by_id(uuid) to authenticated;

drop function if exists public.community_pinned_posts();

create or replace function public.community_pinned_posts()
returns table (
  id uuid,
  author_id uuid,
  content text,
  image_urls text[],
  nickname text,
  restaurant_id uuid,
  restaurant_name text,
  like_count int,
  comment_count int,
  liked_by_me boolean,
  created_at timestamptz,
  updated_at timestamptz,
  is_owner boolean,
  is_author_owner boolean
)
language sql
stable
security definer
set search_path = public
as $$
  select
    p.id,
    p.user_id as author_id,
    p.content,
    p.image_urls,
    coalesce(ro.name || ' 사장님', u.nickname) as nickname,
    p.restaurant_id,
    r.name as restaurant_name,
    p.like_count,
    p.comment_count,
    exists (
      select 1 from public.community_likes l
      where l.post_id = p.id and l.user_id = auth.uid()
    ) as liked_by_me,
    p.created_at,
    p.updated_at,
    (p.user_id = auth.uid()) as is_owner,
    (ro.id is not null) as is_author_owner
  from public.community_posts p
  join public.users u on u.id = p.user_id
  left join public.restaurants r on r.id = p.restaurant_id
  left join public.restaurants ro
    on ro.id = p.author_owner_restaurant_id and ro.is_active
  where not p.is_hidden
    and p.is_pinned
    and not public.is_blocked_with(p.user_id)
  order by p.pin_order asc
  limit 5;
$$;

revoke all on function public.community_pinned_posts() from public;
grant execute on function public.community_pinned_posts() to authenticated;

drop function if exists public.community_my_commented_posts();

create or replace function public.community_my_commented_posts()
returns table (
  id uuid,
  author_id uuid,
  content text,
  image_urls text[],
  nickname text,
  restaurant_id uuid,
  restaurant_name text,
  like_count int,
  comment_count int,
  liked_by_me boolean,
  created_at timestamptz,
  updated_at timestamptz,
  is_owner boolean
)
language sql
stable
security definer
set search_path = public
as $$
  with my_comment_posts as (
    select distinct on (c.post_id)
      c.post_id,
      c.created_at as my_last_comment_at
    from public.community_comments c
    where c.user_id = auth.uid()
      and not c.is_hidden
    order by c.post_id, c.created_at desc
  )
  select
    p.id,
    p.user_id as author_id,
    p.content,
    p.image_urls,
    u.nickname,
    p.restaurant_id,
    r.name as restaurant_name,
    p.like_count,
    p.comment_count,
    exists (
      select 1 from public.community_likes l
      where l.post_id = p.id and l.user_id = auth.uid()
    ) as liked_by_me,
    p.created_at,
    p.updated_at,
    (p.user_id = auth.uid()) as is_owner
  from my_comment_posts mcp
  join public.community_posts p on p.id = mcp.post_id
  join public.users u on u.id = p.user_id
  left join public.restaurants r on r.id = p.restaurant_id
  where not p.is_hidden
    and not public.is_blocked_with(p.user_id)
  order by mcp.my_last_comment_at desc;
$$;

revoke all on function public.community_my_commented_posts() from public;
grant execute on function public.community_my_commented_posts() to authenticated;

drop function if exists public.collection_comments_for_collection(uuid);

create or replace function public.collection_comments_for_collection(p_collection_id uuid)
returns table (
  id uuid,
  author_id uuid,
  content text,
  nickname text,
  created_at timestamptz,
  is_owner boolean,
  is_author_owner boolean,
  like_count int,
  liked_by_me boolean,
  parent_comment_id uuid
)
language sql
stable
security definer
set search_path = public
as $$
  select
    c.id,
    c.user_id as author_id,
    c.content,
    u.nickname,
    c.created_at,
    (c.user_id = auth.uid()) as is_owner,
    (u.role = 'owner'::public.user_role) as is_author_owner,
    c.like_count,
    exists (
      select 1 from public.collection_comment_likes l
      where l.comment_id = c.id and l.user_id = auth.uid()
    ) as liked_by_me,
    c.parent_comment_id
  from public.collection_comments c
  join public.users u on u.id = c.user_id
  where c.collection_id = p_collection_id
    and not c.is_hidden
    and not public.is_blocked_with(c.user_id)
  order by c.created_at asc;
$$;

revoke all on function public.collection_comments_for_collection(uuid) from public;
grant execute on function public.collection_comments_for_collection(uuid) to authenticated;

select 'community_block.sql ok' as status;
