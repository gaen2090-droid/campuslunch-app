-- 댓글 좋아요 + 대댓글(답글) (Dashboard → SQL Editor → Run)
-- community_comments에 like_count/parent_comment_id 컬럼 추가, community_comment_likes
-- 테이블 신설, community_comments_for_post RPC를 좋아요/답글 여부 포함하도록 재정의.

-- ── 컬럼 추가 ──

alter table public.community_comments
  add column if not exists like_count int not null default 0,
  add column if not exists parent_comment_id uuid references public.community_comments(id) on delete cascade;

create index if not exists community_comments_parent_idx
  on public.community_comments (parent_comment_id);

-- ── 댓글 좋아요 테이블 ──

create table if not exists public.community_comment_likes (
  comment_id uuid not null references public.community_comments(id) on delete cascade,
  user_id    uuid not null references public.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (comment_id, user_id)
);

alter table public.community_comment_likes enable row level security;

drop policy if exists "comment likes insert own" on public.community_comment_likes;
create policy "comment likes insert own" on public.community_comment_likes
  for insert to authenticated with check (user_id = auth.uid());

drop policy if exists "comment likes select all" on public.community_comment_likes;
create policy "comment likes select all" on public.community_comment_likes
  for select to authenticated using (true);

drop policy if exists "comment likes delete own" on public.community_comment_likes;
create policy "comment likes delete own" on public.community_comment_likes
  for delete to authenticated using (user_id = auth.uid());

-- ── 좋아요 카운트 캐시 트리거 (게시글 좋아요와 동일 패턴) ──

create or replace function public.community_bump_comment_like_count()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if tg_op = 'INSERT' then
    update public.community_comments set like_count = like_count + 1 where id = new.comment_id;
    return new;
  elsif tg_op = 'DELETE' then
    update public.community_comments set like_count = greatest(like_count - 1, 0) where id = old.comment_id;
    return old;
  end if;
  return null;
end;
$$;

drop trigger if exists community_comment_likes_bump on public.community_comment_likes;
create trigger community_comment_likes_bump
  after insert or delete on public.community_comment_likes
  for each row execute function public.community_bump_comment_like_count();

-- ── 댓글 조회 RPC 재정의: like_count/liked_by_me/parent_comment_id 포함 ──

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
    u.nickname,
    c.created_at,
    (c.user_id = auth.uid()) as is_owner,
    (u.role = 'owner'::public.user_role) as is_author_owner,
    c.like_count,
    exists (
      select 1 from public.community_comment_likes l
      where l.comment_id = c.id and l.user_id = auth.uid()
    ) as liked_by_me,
    c.parent_comment_id
  from public.community_comments c
  join public.users u on u.id = c.user_id
  where c.post_id = p_post_id
    and not c.is_hidden
  order by c.created_at asc;
$$;

revoke all on function public.community_comments_for_post(uuid) from public;
grant execute on function public.community_comments_for_post(uuid) to authenticated;

-- ── 댓글 작성 RPC — parent_comment_id 지원 (기존엔 클라이언트가 insert 직접 호출) ──

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
begin
  if p_parent_comment_id is not null then
    select post_id into parent_post_id
    from public.community_comments
    where id = p_parent_comment_id;

    if parent_post_id is null or parent_post_id <> p_post_id then
      raise exception '답글 대상 댓글을 찾을 수 없어요.';
    end if;
  end if;

  insert into public.community_comments (post_id, user_id, content, parent_comment_id)
  values (p_post_id, auth.uid(), p_content, p_parent_comment_id)
  returning id into new_id;

  return new_id;
end;
$$;

revoke all on function public.add_community_comment(uuid, text, uuid) from public;
grant execute on function public.add_community_comment(uuid, text, uuid) to authenticated;

-- 확인 (Success 나오면 OK)
select 'ok' as result;
