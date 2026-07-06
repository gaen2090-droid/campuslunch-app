-- 맛집 컬렉션 댓글 (Dashboard → SQL Editor → Run)
-- community_comments와 동일한 형태로 컬렉션 단위 댓글 지원.

create table if not exists public.collection_comments (
  id            uuid primary key default gen_random_uuid(),
  collection_id uuid not null references public.collections(id) on delete cascade,
  user_id       uuid not null references public.users(id) on delete cascade,
  content       text not null check (char_length(content) between 1 and 500),
  is_hidden     boolean not null default false,
  created_at    timestamptz not null default now()
);
create index if not exists collection_comments_collection_idx
  on public.collection_comments (collection_id, created_at);

alter table public.collection_comments enable row level security;

drop policy if exists "collection comments insert own" on public.collection_comments;
create policy "collection comments insert own" on public.collection_comments
  for insert to authenticated with check (user_id = auth.uid());

drop policy if exists "collection comments select visible" on public.collection_comments;
create policy "collection comments select visible" on public.collection_comments
  for select to authenticated using (not is_hidden or public.is_admin());

drop policy if exists "collection comments delete own or admin" on public.collection_comments;
create policy "collection comments delete own or admin" on public.collection_comments
  for delete to authenticated using (user_id = auth.uid() or public.is_admin());

-- community_comments_for_post와 동일한 컬럼 형태로 반환해 앱에서 CommunityComment 모델 재사용
create or replace function public.collection_comments_for_collection(p_collection_id uuid)
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
  from public.collection_comments c
  join public.users u on u.id = c.user_id
  where c.collection_id = p_collection_id
    and not c.is_hidden
  order by c.created_at asc;
$$;

revoke all on function public.collection_comments_for_collection(uuid) from public;
grant execute on function public.collection_comments_for_collection(uuid) to authenticated;

-- 웹 어드민: 전체 컬렉션 댓글 목록 (숨김 포함, 관리자만)
create or replace function public.admin_list_collection_comments(p_limit int default 100)
returns table (
  id uuid,
  collection_id uuid,
  collection_title text,
  content text,
  nickname text,
  is_hidden boolean,
  created_at timestamptz
)
language sql
stable
security definer
set search_path = public
as $$
  select
    c.id,
    c.collection_id,
    col.title as collection_title,
    c.content,
    u.nickname,
    c.is_hidden,
    c.created_at
  from public.collection_comments c
  join public.collections col on col.id = c.collection_id
  join public.users u on u.id = c.user_id
  where public.is_admin()
  order by c.created_at desc
  limit p_limit;
$$;

revoke all on function public.admin_list_collection_comments(int) from public;
grant execute on function public.admin_list_collection_comments(int) to authenticated;
