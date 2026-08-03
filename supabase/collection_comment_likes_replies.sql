-- 맛집 컬렉션 댓글 좋아요 + 대댓글(답글) + 신고 (Dashboard → SQL Editor → Run)
-- community_comment_likes_replies.sql과 동일 패턴을 collection_comments에 적용.

-- ── 컬럼 추가 ──

alter table public.collection_comments
  add column if not exists like_count int not null default 0,
  add column if not exists parent_comment_id uuid references public.collection_comments(id) on delete cascade;

create index if not exists collection_comments_parent_idx
  on public.collection_comments (parent_comment_id);

-- ── 댓글 좋아요 테이블 ──

create table if not exists public.collection_comment_likes (
  comment_id uuid not null references public.collection_comments(id) on delete cascade,
  user_id    uuid not null references public.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (comment_id, user_id)
);

alter table public.collection_comment_likes enable row level security;

drop policy if exists "collection comment likes insert own" on public.collection_comment_likes;
create policy "collection comment likes insert own" on public.collection_comment_likes
  for insert to authenticated with check (user_id = auth.uid());

drop policy if exists "collection comment likes select all" on public.collection_comment_likes;
create policy "collection comment likes select all" on public.collection_comment_likes
  for select to authenticated using (true);

drop policy if exists "collection comment likes delete own" on public.collection_comment_likes;
create policy "collection comment likes delete own" on public.collection_comment_likes
  for delete to authenticated using (user_id = auth.uid());

-- ── 좋아요 카운트 캐시 트리거 ──

create or replace function public.collection_bump_comment_like_count()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if tg_op = 'INSERT' then
    update public.collection_comments set like_count = like_count + 1 where id = new.comment_id;
    return new;
  elsif tg_op = 'DELETE' then
    update public.collection_comments set like_count = greatest(like_count - 1, 0) where id = old.comment_id;
    return old;
  end if;
  return null;
end;
$$;

drop trigger if exists collection_comment_likes_bump on public.collection_comment_likes;
create trigger collection_comment_likes_bump
  after insert or delete on public.collection_comment_likes
  for each row execute function public.collection_bump_comment_like_count();

-- ── 댓글 조회 RPC 재정의: like_count/liked_by_me/parent_comment_id/is_author_owner 포함 ──
-- community_comments_for_post와 동일한 컬럼 형태 유지 → 앱에서 CommunityComment 모델 그대로 재사용

drop function if exists public.collection_comments_for_collection(uuid);

create or replace function public.collection_comments_for_collection(p_collection_id uuid)
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
      select 1 from public.collection_comment_likes l
      where l.comment_id = c.id and l.user_id = auth.uid()
    ) as liked_by_me,
    c.parent_comment_id
  from public.collection_comments c
  join public.users u on u.id = c.user_id
  where c.collection_id = p_collection_id
    and not c.is_hidden
  order by c.created_at asc;
$$;

revoke all on function public.collection_comments_for_collection(uuid) from public;
grant execute on function public.collection_comments_for_collection(uuid) to authenticated;

-- ── 댓글 작성 RPC — parent_comment_id 지원 (기존엔 클라이언트가 insert 직접 호출) ──

create or replace function public.add_collection_comment(
  p_collection_id uuid,
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
  parent_collection_id uuid;
begin
  if p_parent_comment_id is not null then
    select collection_id into parent_collection_id
    from public.collection_comments
    where id = p_parent_comment_id;

    if parent_collection_id is null or parent_collection_id <> p_collection_id then
      raise exception '답글 대상 댓글을 찾을 수 없어요.';
    end if;
  end if;

  insert into public.collection_comments (collection_id, user_id, content, parent_comment_id)
  values (p_collection_id, auth.uid(), p_content, p_parent_comment_id)
  returning id into new_id;

  return new_id;
end;
$$;

revoke all on function public.add_collection_comment(uuid, text, uuid) from public;
grant execute on function public.add_collection_comment(uuid, text, uuid) to authenticated;

-- ── 신고: community_reports 재사용 (post_id/comment_id 중 comment_id만 채워 신고) ──
-- community_reports.comment_id가 community_comments를 참조 중이라면 컬렉션 댓글 id와
-- 겹칠 일이 없어(둘 다 독립 uuid PK) FK 없이도 안전하게 기록 가능한지 확인 필요.
-- → FK가 community_comments(id)로 걸려 있으면 컬렉션 댓글 id insert 시 위반되므로
--   컬렉션 전용 신고 테이블을 별도로 둔다.

create table if not exists public.collection_comment_reports (
  id            uuid primary key default gen_random_uuid(),
  comment_id    uuid not null references public.collection_comments(id) on delete cascade,
  reporter_id   uuid not null references public.users(id) on delete cascade,
  reason        text,
  created_at    timestamptz not null default now()
);

alter table public.collection_comment_reports enable row level security;

drop policy if exists "collection comment reports insert own" on public.collection_comment_reports;
create policy "collection comment reports insert own" on public.collection_comment_reports
  for insert to authenticated with check (reporter_id = auth.uid());

drop policy if exists "collection comment reports select admin" on public.collection_comment_reports;
create policy "collection comment reports select admin" on public.collection_comment_reports
  for select to authenticated using (public.is_admin());

create or replace function public.report_collection_comment(
  p_comment_id uuid,
  p_reason text default null
)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.collection_comment_reports (comment_id, reporter_id, reason)
  values (p_comment_id, auth.uid(), p_reason);
end;
$$;

revoke all on function public.report_collection_comment(uuid, text) from public;
grant execute on function public.report_collection_comment(uuid, text) to authenticated;

-- 확인 (Success 나오면 OK)
select 'ok' as result;
