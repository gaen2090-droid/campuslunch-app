-- 사장님 커뮤니티 활동 매장: 여러 매장을 가진 사장님이 "이 매장 사장님"으로 표시될
-- 매장을 직접 선택. 글/댓글 작성 시점의 선택값을 스냅샷으로 저장해, 나중에 활동
-- 매장을 바꿔도 과거 글/댓글의 표시 이름은 그대로 유지된다.
-- (Dashboard → SQL Editor → Run, community_owner_badge_fix.sql 이후)

-- ── 1. users: 현재 활동 매장 ──
alter table public.users
  add column if not exists active_owner_restaurant_id uuid references public.restaurants(id) on delete set null;

create or replace function public.set_active_owner_restaurant(p_restaurant_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.uid() is null then
    raise exception '로그인이 필요해요.';
  end if;

  if p_restaurant_id is not null and not exists (
    select 1 from public.restaurants r
    where r.id = p_restaurant_id and r.owner_id = auth.uid() and r.is_active
  ) then
    raise exception '본인 매장만 선택할 수 있어요.';
  end if;

  update public.users
  set active_owner_restaurant_id = p_restaurant_id
  where id = auth.uid();
end;
$$;

grant execute on function public.set_active_owner_restaurant(uuid) to authenticated;

-- ── 2. community_posts / community_comments: 작성 시점 활동 매장 스냅샷 ──
alter table public.community_posts
  add column if not exists author_owner_restaurant_id uuid references public.restaurants(id) on delete set null;

alter table public.community_comments
  add column if not exists author_owner_restaurant_id uuid references public.restaurants(id) on delete set null;

-- ── 3. 글 작성: INSERT 트리거로 스냅샷 자동 기록 (클라이언트가 community_posts에 직접 insert) ──
create or replace function public.community_posts_set_owner_snapshot()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  select active_owner_restaurant_id into new.author_owner_restaurant_id
  from public.users where id = new.user_id;
  return new;
end;
$$;

drop trigger if exists trg_community_posts_owner_snapshot on public.community_posts;
create trigger trg_community_posts_owner_snapshot
  before insert on public.community_posts
  for each row execute function public.community_posts_set_owner_snapshot();

-- ── 4. 댓글 작성 RPC — 스냅샷 함께 기록 ──
create or replace function public.add_community_comment(
  p_post_id uuid,
  p_content text,
  p_parent_comment_id uuid default null
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  new_id uuid;
  parent_post_id uuid;
  v_owner_restaurant_id uuid;
begin
  if p_parent_comment_id is not null then
    select post_id into parent_post_id
    from public.community_comments
    where id = p_parent_comment_id;

    if parent_post_id is null or parent_post_id <> p_post_id then
      raise exception '답글 대상 댓글을 찾을 수 없어요.';
    end if;
  end if;

  select active_owner_restaurant_id into v_owner_restaurant_id
  from public.users where id = auth.uid();

  insert into public.community_comments (
    post_id, user_id, content, parent_comment_id, author_owner_restaurant_id
  )
  values (p_post_id, auth.uid(), p_content, p_parent_comment_id, v_owner_restaurant_id)
  returning id into new_id;

  return new_id;
end;
$$;

revoke all on function public.add_community_comment(uuid, text, uuid) from public;
grant execute on function public.add_community_comment(uuid, text, uuid) to authenticated;

-- ── 5. 조회 RPC: 스냅샷 매장 이름으로 "OO 가게 사장님" 표시 ──
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
  order by c.created_at asc;
$$;

revoke all on function public.community_comments_for_post(uuid) from public;
grant execute on function public.community_comments_for_post(uuid) to authenticated;

select 'community_owner_active_restaurant.sql ok' as status;
