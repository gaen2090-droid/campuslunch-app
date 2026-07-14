-- 커뮤니티 피드에 작성자의 '사장님(오너)' 여부 추가 (Dashboard → SQL Editor → Run)
-- community_feed RPC에 is_author_owner 컬럼 추가 — users.role = 'owner' 여부.
-- 기존 (int, timestamptz, text) 시그니처를 대체하므로 먼저 drop 후 재생성한다.

drop function if exists public.community_feed(int, timestamptz, text);

create or replace function public.community_feed(
  p_limit int default 20,
  p_before timestamptz default null,
  p_query text default null
)
returns table (
  id uuid,
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
    (p.user_id = auth.uid()) as is_owner,
    (u.role = 'owner'::public.user_role) as is_author_owner
  from public.community_posts p
  join public.users u on u.id = p.user_id
  left join public.restaurants r on r.id = p.restaurant_id
  where not p.is_hidden
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

-- ── 댓글 조회 RPC에도 작성자 '사장님' 여부 추가 ──

drop function if exists public.community_comments_for_post(uuid);

create or replace function public.community_comments_for_post(p_post_id uuid)
returns table (
  id uuid,
  content text,
  nickname text,
  created_at timestamptz,
  is_owner boolean,
  is_author_owner boolean
)
language sql
stable
security definer
set search_path = public
as $$
  select
    c.id,
    c.content,
    u.nickname,
    c.created_at,
    (c.user_id = auth.uid()) as is_owner,
    (u.role = 'owner'::public.user_role) as is_author_owner
  from public.community_comments c
  join public.users u on u.id = c.user_id
  where c.post_id = p_post_id
    and not c.is_hidden
  order by c.created_at asc;
$$;

revoke all on function public.community_comments_for_post(uuid) from public;
grant execute on function public.community_comments_for_post(uuid) to authenticated;

-- 확인 (Success 나오면 OK)
select public.community_feed(5, null, null);
