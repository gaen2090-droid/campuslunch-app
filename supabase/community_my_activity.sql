-- 커뮤니티 "내 활동" 조회 RPC (Dashboard → SQL Editor → Run)
-- community_feed와 동일한 컬럼 형태로 반환해 앱에서 같은 모델/카드로 렌더링.

create or replace function public.community_my_posts()
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
  is_owner boolean
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
    true as is_owner
  from public.community_posts p
  join public.users u on u.id = p.user_id
  left join public.restaurants r on r.id = p.restaurant_id
  where p.user_id = auth.uid()
    and not p.is_hidden
  order by p.created_at desc;
$$;

create or replace function public.community_my_commented_posts()
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
  order by mcp.my_last_comment_at desc;
$$;

revoke all on function public.community_my_posts() from public;
revoke all on function public.community_my_commented_posts() from public;
grant execute on function public.community_my_posts() to authenticated;
grant execute on function public.community_my_commented_posts() to authenticated;
