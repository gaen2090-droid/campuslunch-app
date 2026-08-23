-- 커뮤니티 관리자 뱃지: 글/댓글 작성자가 role='admin'이면 is_author_admin=true 반환
-- (Dashboard → SQL Editor → Run)
--
-- ⚠️ 이 파일이 아래 RPC의 정본이다. community_block.sql의 같은 이름 함수는
--    이 파일로 대체됐다. (옛 파일을 다시 실행하면 이 파일의 변경사항 +
--    community_block.sql의 차단 필터가 함께 사라질 수 있으니 재실행 순서에 주의:
--    이 파일을 community_block.sql보다 항상 나중에 실행할 것)
--
--    정본 대상: community_feed, community_comments_for_post,
--              community_post_by_id, community_pinned_posts,
--              collection_comments_for_collection
--
-- 실행 순서: community_block.sql 이후

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
  is_author_admin boolean
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
    (u.role = 'admin'::public.user_role) as is_author_admin
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
  is_author_admin boolean,
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
    (u.role = 'admin'::public.user_role) as is_author_admin,
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
  is_author_admin boolean
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
    (u.role = 'admin'::public.user_role) as is_author_admin
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
  is_author_admin boolean
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
    (u.role = 'admin'::public.user_role) as is_author_admin
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
  is_author_admin boolean,
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
    (u.role = 'admin'::public.user_role) as is_author_admin,
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

select 'community_admin_badge.sql ok' as status;
