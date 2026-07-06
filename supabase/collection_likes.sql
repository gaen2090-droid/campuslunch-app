-- 맛집 컬렉션 좋아요 (Dashboard → SQL Editor → Run)

create table if not exists public.collection_likes (
  collection_id uuid not null references public.collections(id) on delete cascade,
  user_id       uuid not null references public.users(id) on delete cascade,
  created_at    timestamptz not null default now(),
  primary key (collection_id, user_id)
);

alter table public.collection_likes enable row level security;

drop policy if exists "collection likes insert own" on public.collection_likes;
create policy "collection likes insert own" on public.collection_likes
  for insert to authenticated with check (user_id = auth.uid());

drop policy if exists "collection likes select all" on public.collection_likes;
create policy "collection likes select all" on public.collection_likes
  for select to authenticated using (true);

drop policy if exists "collection likes delete own" on public.collection_likes;
create policy "collection likes delete own" on public.collection_likes
  for delete to authenticated using (user_id = auth.uid());

-- 앱에서 컬렉션 목록 조회 시 좋아요 수/내 좋아요 여부/댓글 수까지 함께 반환
drop function if exists public.collections_with_likes();
create or replace function public.collections_with_likes()
returns table (
  id uuid,
  title text,
  subtitle text,
  sort_order int,
  like_count int,
  liked_by_me boolean,
  comment_count int
)
language sql
stable
security definer
set search_path = public
as $$
  select
    c.id,
    c.title,
    c.subtitle,
    c.sort_order,
    (select count(*) from public.collection_likes l where l.collection_id = c.id)::int as like_count,
    exists (
      select 1 from public.collection_likes l
      where l.collection_id = c.id and l.user_id = auth.uid()
    ) as liked_by_me,
    (
      select count(*) from public.collection_comments cc
      where cc.collection_id = c.id and not cc.is_hidden
    )::int as comment_count
  from public.collections c
  where c.is_published
  order by c.sort_order asc;
$$;

revoke all on function public.collections_with_likes() from public;
grant execute on function public.collections_with_likes() to authenticated;
