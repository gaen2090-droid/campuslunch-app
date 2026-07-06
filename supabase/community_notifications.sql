-- 커뮤니티 댓글 알림 (Dashboard → SQL Editor → Run)
-- 개별 게시글 알림 토글(구독) + "내 활동" 알림 리스트(내 글/구독한 글에 달린 댓글).

create table if not exists public.community_post_subscriptions (
  post_id    uuid not null references public.community_posts(id) on delete cascade,
  user_id    uuid not null references public.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (post_id, user_id)
);

alter table public.community_post_subscriptions enable row level security;

drop policy if exists "subscriptions insert own" on public.community_post_subscriptions;
create policy "subscriptions insert own" on public.community_post_subscriptions
  for insert to authenticated with check (user_id = auth.uid());

drop policy if exists "subscriptions select own" on public.community_post_subscriptions;
create policy "subscriptions select own" on public.community_post_subscriptions
  for select to authenticated using (user_id = auth.uid());

drop policy if exists "subscriptions delete own" on public.community_post_subscriptions;
create policy "subscriptions delete own" on public.community_post_subscriptions
  for delete to authenticated using (user_id = auth.uid());

-- 알림 리스트: 내가 쓴 글 + 내가 구독한 글에 달린, 내가 쓰지 않은 댓글
create or replace function public.community_comment_notifications()
returns table (
  comment_id uuid,
  post_id uuid,
  post_content text,
  commenter_nickname text,
  comment_content text,
  created_at timestamptz
)
language sql
stable
security definer
set search_path = public
as $$
  select
    c.id as comment_id,
    c.post_id,
    p.content as post_content,
    u.nickname as commenter_nickname,
    c.content as comment_content,
    c.created_at
  from public.community_comments c
  join public.community_posts p on p.id = c.post_id
  join public.users u on u.id = c.user_id
  where not c.is_hidden
    and not p.is_hidden
    and c.user_id <> auth.uid()
    and (
      p.user_id = auth.uid()
      or exists (
        select 1 from public.community_post_subscriptions s
        where s.post_id = p.id and s.user_id = auth.uid()
      )
    )
  order by c.created_at desc
  limit 100;
$$;

revoke all on function public.community_comment_notifications() from public;
grant execute on function public.community_comment_notifications() to authenticated;

-- 알림 탭 시 해당 게시글을 community_feed와 동일한 형태로 단건 조회
create or replace function public.community_post_by_id(p_post_id uuid)
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
    (p.user_id = auth.uid()) as is_owner
  from public.community_posts p
  join public.users u on u.id = p.user_id
  left join public.restaurants r on r.id = p.restaurant_id
  where p.id = p_post_id
    and not p.is_hidden;
$$;

revoke all on function public.community_post_by_id(uuid) from public;
grant execute on function public.community_post_by_id(uuid) to authenticated;
