-- 게시글 공지 고정(핀) 기능 + 어드민 게시글 검색 (Dashboard → SQL Editor → Run)
-- 실행 순서: community_owner_badge_fix.sql, community_phase2_admin.sql 이후
--
-- 관리자가 게시글을 "공지"로 지정할 수 있게 한다. 앱 커뮤니티 화면에서
-- 관리자 공지(community_notices)와 핀된 게시글을 함께 가로 스크롤로 최대 5개 노출한다.

alter table public.community_posts
  add column if not exists is_pinned boolean not null default false;

create index if not exists community_posts_is_pinned_idx
  on public.community_posts (is_pinned) where is_pinned;

-- ── 관리자: 게시글 공지 고정/해제 ──

create or replace function public.admin_set_post_pinned(
  p_post_id uuid,
  p_pinned  boolean
)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if not public.is_admin() then
    raise exception '관리자만 설정할 수 있어요.';
  end if;

  update public.community_posts
  set is_pinned = p_pinned
  where id = p_post_id;
end;
$$;

revoke all on function public.admin_set_post_pinned(uuid, boolean) from public;
grant execute on function public.admin_set_post_pinned(uuid, boolean) to authenticated;

-- ── 어드민 게시글 목록에 검색어(p_query) 파라미터 + is_pinned 추가 ──

drop function if exists public.admin_list_community_posts(int);

create or replace function public.admin_list_community_posts(
  p_limit int default 50,
  p_query text default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
begin
  if not public.is_admin() then
    raise exception '관리자만 조회할 수 있어요.';
  end if;

  return coalesce((
    select jsonb_agg(row_to_json(t) order by t.created_at desc)
    from (
      select
        p.id,
        p.content,
        p.image_urls,
        p.is_hidden,
        p.is_pinned,
        p.like_count,
        p.comment_count,
        p.created_at,
        u.nickname
      from public.community_posts p
      join public.users u on u.id = p.user_id
      where p_query is null
        or trim(p_query) = ''
        or p.content ilike '%' || replace(replace(trim(p_query), '%', '\%'), '_', '\_') || '%'
        or u.nickname ilike '%' || replace(replace(trim(p_query), '%', '\%'), '_', '\_') || '%'
      order by p.created_at desc
      limit p_limit
    ) t
  ), '[]'::jsonb);
end;
$$;

revoke all on function public.admin_list_community_posts(int, text) from public;
grant execute on function public.admin_list_community_posts(int, text) to authenticated;

-- ── 앱: 핀된 게시글 최대 5개 (최신순) ──

create or replace function public.community_pinned_posts()
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
    exists (
      select 1 from public.restaurants ro
      where ro.owner_id = p.user_id and ro.is_active
    ) as is_author_owner
  from public.community_posts p
  join public.users u on u.id = p.user_id
  left join public.restaurants r on r.id = p.restaurant_id
  where not p.is_hidden
    and p.is_pinned
  order by p.created_at desc
  limit 5;
$$;

revoke all on function public.community_pinned_posts() from public;
grant execute on function public.community_pinned_posts() to authenticated;

select 'community_post_pin.sql ok' as status;
