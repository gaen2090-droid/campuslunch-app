-- 커뮤니티 자유게시판 Phase 1 (Dashboard → SQL Editor → Run)
-- docs/PLAN_community_and_collections.md 기획 반영

-- ── 테이블 ──

create table if not exists public.community_posts (
  id            uuid primary key default gen_random_uuid(),
  user_id       uuid not null references public.users(id) on delete cascade,
  content       text not null check (char_length(content) between 1 and 1000),
  image_urls    text[] not null default '{}',
  restaurant_id uuid references public.restaurants(id) on delete set null,
  like_count    int not null default 0,
  comment_count int not null default 0,
  is_hidden     boolean not null default false,
  created_at    timestamptz not null default now(),
  updated_at    timestamptz
);
create index if not exists community_posts_feed_idx
  on public.community_posts (created_at desc) where not is_hidden;

create table if not exists public.community_comments (
  id         uuid primary key default gen_random_uuid(),
  post_id    uuid not null references public.community_posts(id) on delete cascade,
  user_id    uuid not null references public.users(id) on delete cascade,
  content    text not null check (char_length(content) between 1 and 500),
  is_hidden  boolean not null default false,
  created_at timestamptz not null default now()
);
create index if not exists community_comments_post_idx
  on public.community_comments (post_id, created_at);

create table if not exists public.community_likes (
  post_id    uuid not null references public.community_posts(id) on delete cascade,
  user_id    uuid not null references public.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (post_id, user_id)
);

create table if not exists public.community_reports (
  id          uuid primary key default gen_random_uuid(),
  reporter_id uuid not null references public.users(id) on delete cascade,
  post_id     uuid references public.community_posts(id) on delete cascade,
  comment_id  uuid references public.community_comments(id) on delete cascade,
  reason      text,
  created_at  timestamptz not null default now(),
  check (post_id is not null or comment_id is not null)
);

-- ── RLS ──

alter table public.community_posts    enable row level security;
alter table public.community_comments enable row level security;
alter table public.community_likes    enable row level security;
alter table public.community_reports  enable row level security;

drop policy if exists "posts insert own" on public.community_posts;
create policy "posts insert own" on public.community_posts
  for insert to authenticated with check (user_id = auth.uid());

drop policy if exists "posts select visible" on public.community_posts;
create policy "posts select visible" on public.community_posts
  for select to authenticated using (not is_hidden or public.is_admin());

drop policy if exists "posts update own or admin" on public.community_posts;
create policy "posts update own or admin" on public.community_posts
  for update to authenticated
  using (user_id = auth.uid() or public.is_admin())
  with check (user_id = auth.uid() or public.is_admin());

drop policy if exists "posts delete own or admin" on public.community_posts;
create policy "posts delete own or admin" on public.community_posts
  for delete to authenticated using (user_id = auth.uid() or public.is_admin());

drop policy if exists "comments insert own" on public.community_comments;
create policy "comments insert own" on public.community_comments
  for insert to authenticated with check (user_id = auth.uid());

drop policy if exists "comments select visible" on public.community_comments;
create policy "comments select visible" on public.community_comments
  for select to authenticated using (not is_hidden or public.is_admin());

drop policy if exists "comments update own or admin" on public.community_comments;
create policy "comments update own or admin" on public.community_comments
  for update to authenticated
  using (user_id = auth.uid() or public.is_admin())
  with check (user_id = auth.uid() or public.is_admin());

drop policy if exists "comments delete own or admin" on public.community_comments;
create policy "comments delete own or admin" on public.community_comments
  for delete to authenticated using (user_id = auth.uid() or public.is_admin());

drop policy if exists "likes insert own" on public.community_likes;
create policy "likes insert own" on public.community_likes
  for insert to authenticated with check (user_id = auth.uid());

drop policy if exists "likes select all" on public.community_likes;
create policy "likes select all" on public.community_likes
  for select to authenticated using (true);

drop policy if exists "likes delete own" on public.community_likes;
create policy "likes delete own" on public.community_likes
  for delete to authenticated using (user_id = auth.uid());

drop policy if exists "reports insert own" on public.community_reports;
create policy "reports insert own" on public.community_reports
  for insert to authenticated with check (reporter_id = auth.uid());

drop policy if exists "reports select admin" on public.community_reports;
create policy "reports select admin" on public.community_reports
  for select to authenticated using (public.is_admin());

-- ── 카운트 캐시 트리거 (해당 테이블에만 정확히 바인딩) ──

create or replace function public.community_bump_like_count()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if tg_op = 'INSERT' then
    update public.community_posts set like_count = like_count + 1 where id = new.post_id;
    return new;
  elsif tg_op = 'DELETE' then
    update public.community_posts set like_count = greatest(like_count - 1, 0) where id = old.post_id;
    return old;
  end if;
  return null;
end;
$$;

drop trigger if exists community_likes_bump on public.community_likes;
create trigger community_likes_bump
  after insert or delete on public.community_likes
  for each row execute function public.community_bump_like_count();

create or replace function public.community_bump_comment_count()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if tg_op = 'INSERT' then
    update public.community_posts set comment_count = comment_count + 1 where id = new.post_id;
    return new;
  elsif tg_op = 'DELETE' then
    update public.community_posts set comment_count = greatest(comment_count - 1, 0) where id = old.post_id;
    return old;
  end if;
  return null;
end;
$$;

drop trigger if exists community_comments_bump on public.community_comments;
create trigger community_comments_bump
  after insert or delete on public.community_comments
  for each row execute function public.community_bump_comment_count();

-- ── 피드 조회 RPC (닉네임/관련매장 조인, users 테이블 직접 노출 없이) ──

create or replace function public.community_feed(
  p_limit int default 20,
  p_before timestamptz default null
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
  where not p.is_hidden
    and (p_before is null or p.created_at < p_before)
  order by p.created_at desc
  limit p_limit;
$$;

revoke all on function public.community_feed(int, timestamptz) from public;
grant execute on function public.community_feed(int, timestamptz) to authenticated;

-- ── 댓글 조회 RPC ──

create or replace function public.community_comments_for_post(p_post_id uuid)
returns table (
  id uuid,
  content text,
  nickname text,
  created_at timestamptz,
  is_owner boolean
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
    (c.user_id = auth.uid()) as is_owner
  from public.community_comments c
  join public.users u on u.id = c.user_id
  where c.post_id = p_post_id
    and not c.is_hidden
  order by c.created_at asc;
$$;

revoke all on function public.community_comments_for_post(uuid) from public;
grant execute on function public.community_comments_for_post(uuid) to authenticated;

-- ── Storage 버킷 (게시글 이미지, public read) ──

insert into storage.buckets (id, name, public)
values ('community', 'community', true)
on conflict (id) do nothing;

drop policy if exists "community images public read" on storage.objects;
create policy "community images public read" on storage.objects
  for select using (bucket_id = 'community');

drop policy if exists "community images own upload" on storage.objects;
create policy "community images own upload" on storage.objects
  for insert to authenticated
  with check (bucket_id = 'community' and (storage.foldername(name))[1] = auth.uid()::text);

drop policy if exists "community images own delete" on storage.objects;
create policy "community images own delete" on storage.objects
  for delete to authenticated
  using (bucket_id = 'community' and (storage.foldername(name))[1] = auth.uid()::text);
