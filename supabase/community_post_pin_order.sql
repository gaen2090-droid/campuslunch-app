-- 공지 게시글(핀) 노출 순서 지정 (Dashboard → SQL Editor → Run)
-- 실행 순서: community_post_pin.sql 이후
--
-- 관리자가 핀 게시글의 노출 순서를 지정할 수 있게 한다. 값이 작을수록 먼저
-- 노출된다. 새로 핀할 때는 기존 최댓값 + 1로 맨 뒤에 붙는다.

alter table public.community_posts
  add column if not exists pin_order int not null default 0;

-- ── 관리자: 게시글 공지 고정/해제 (순서 자동 부여) ──

create or replace function public.admin_set_post_pinned(
  p_post_id uuid,
  p_pinned  boolean
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_next_order int;
begin
  if not public.is_admin() then
    raise exception '관리자만 설정할 수 있어요.';
  end if;

  if p_pinned then
    select coalesce(max(pin_order), 0) + 1 into v_next_order
    from public.community_posts
    where is_pinned;

    update public.community_posts
    set is_pinned = true, pin_order = v_next_order
    where id = p_post_id;
  else
    update public.community_posts
    set is_pinned = false, pin_order = 0
    where id = p_post_id;
  end if;
end;
$$;

revoke all on function public.admin_set_post_pinned(uuid, boolean) from public;
grant execute on function public.admin_set_post_pinned(uuid, boolean) to authenticated;

-- ── 관리자: 핀 게시글 순서 일괄 재지정 ──

create or replace function public.admin_reorder_pinned_posts(
  p_post_ids uuid[]
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

  update public.community_posts p
  set pin_order = o.ord
  from unnest(p_post_ids) with ordinality as o(id, ord)
  where p.id = o.id;
end;
$$;

revoke all on function public.admin_reorder_pinned_posts(uuid[]) from public;
grant execute on function public.admin_reorder_pinned_posts(uuid[]) to authenticated;

-- ── 어드민 게시글 목록에 pin_order 포함 ──

drop function if exists public.admin_list_community_posts(int, text);

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
        p.pin_order,
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

-- ── 어드민: 핀 게시글만 순서대로 별도 조회 ──

create or replace function public.admin_list_pinned_posts()
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
    select jsonb_agg(row_to_json(t) order by t.pin_order asc)
    from (
      select
        p.id,
        p.content,
        p.image_urls,
        p.is_hidden,
        p.is_pinned,
        p.pin_order,
        p.like_count,
        p.comment_count,
        p.created_at,
        u.nickname
      from public.community_posts p
      join public.users u on u.id = p.user_id
      where p.is_pinned
    ) t
  ), '[]'::jsonb);
end;
$$;

revoke all on function public.admin_list_pinned_posts() from public;
grant execute on function public.admin_list_pinned_posts() to authenticated;

-- ── 앱: 핀된 게시글 최대 5개 (지정 순서) ──

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
  order by p.pin_order asc
  limit 5;
$$;

revoke all on function public.community_pinned_posts() from public;
grant execute on function public.community_pinned_posts() to authenticated;

select 'community_post_pin_order.sql ok' as status;
