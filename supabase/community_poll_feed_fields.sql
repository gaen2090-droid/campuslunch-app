-- 커뮤니티 피드/상세 RPC에 투표 인디케이터 필드 추가 (Dashboard → SQL Editor → Run)
-- docs/PLAN_community_poll.md 반영
--
-- ⚠️ 실행 순서: community_poll.sql, community_admin_badge.sql 이후 실행할 것.
-- 이 파일은 community_admin_badge.sql(정본)의 community_feed / community_post_by_id /
-- community_pinned_posts 본문을 그대로 베이스로 하고, has_poll / poll_voter_count 필드만
-- 추가한다. community_admin_badge.sql이 나중에 다시 바뀌면 이 파일도 함께 갱신할 것.
-- poll_voter_count는 옵션별 vote_count 합이 아니라 distinct user 수로 집계한다
-- (중복선택 허용이라 한 유저가 여러 옵션에 투표해도 참여자는 1명으로 세야 함).

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
  is_author_owner boolean,
  is_author_admin boolean,
  has_poll boolean,
  poll_voter_count int
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
    (ro.id is not null) as is_author_owner,
    (u.role = 'admin'::public.user_role) as is_author_admin,
    exists (
      select 1 from public.community_poll_options po where po.post_id = p.id
    ) as has_poll,
    (
      select count(distinct v.user_id)::int
      from public.community_poll_votes v
      join public.community_poll_options po on po.id = v.option_id
      where po.post_id = p.id
    ) as poll_voter_count
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
  is_author_owner boolean,
  is_author_admin boolean,
  has_poll boolean,
  poll_voter_count int
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
    (ro.id is not null) as is_author_owner,
    (u.role = 'admin'::public.user_role) as is_author_admin,
    exists (
      select 1 from public.community_poll_options po where po.post_id = p.id
    ) as has_poll,
    (
      select count(distinct v.user_id)::int
      from public.community_poll_votes v
      join public.community_poll_options po on po.id = v.option_id
      where po.post_id = p.id
    ) as poll_voter_count
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
  is_author_owner boolean,
  is_author_admin boolean,
  has_poll boolean,
  poll_voter_count int
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
    (ro.id is not null) as is_author_owner,
    (u.role = 'admin'::public.user_role) as is_author_admin,
    exists (
      select 1 from public.community_poll_options po where po.post_id = p.id
    ) as has_poll,
    (
      select count(distinct v.user_id)::int
      from public.community_poll_votes v
      join public.community_poll_options po on po.id = v.option_id
      where po.post_id = p.id
    ) as poll_voter_count
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

select 'community_poll_feed_fields.sql ok' as status;
