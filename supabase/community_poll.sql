-- 커뮤니티 자유게시판 투표 기능 (Dashboard → SQL Editor → Run)
-- docs/PLAN_community_poll.md 반영
--
-- 규칙(§0): 옵션 2~5개, 중복선택(복수응답) 허용, 마감 없음, 투표 즉시 결과 공개,
-- 1인 1회(재투표 불가). 게시 후 투표는 수정도 삭제도 전혀 불가능, 글당 투표 1개.

-- ── 테이블 ──

create table if not exists public.community_poll_options (
  id         uuid primary key default gen_random_uuid(),
  post_id    uuid not null references public.community_posts(id) on delete cascade,
  label      text not null check (char_length(label) between 1 and 40),
  sort_order int not null default 0,
  vote_count int not null default 0
);
create index if not exists community_poll_options_post_idx
  on public.community_poll_options (post_id, sort_order);

create table if not exists public.community_poll_votes (
  option_id  uuid not null references public.community_poll_options(id) on delete cascade,
  user_id    uuid not null references public.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (option_id, user_id)
);
create index if not exists community_poll_votes_user_idx
  on public.community_poll_votes (user_id);

-- ── RLS ──
-- 옵션: select만 정책 존재(insert/update/delete 정책 없음) → 클라이언트발 쓰기는
-- RLS가 전부 거부. 생성은 create_poll_for_post RPC(security definer)를 통해서만 가능.
-- 이 설계로 "게시 후 옵션 수정/삭제 전면 금지"가 DB 레벨에서 원천 강제된다.

alter table public.community_poll_options enable row level security;
alter table public.community_poll_votes   enable row level security;

drop policy if exists "poll options select visible" on public.community_poll_options;
create policy "poll options select visible" on public.community_poll_options
  for select to authenticated using (
    exists (
      select 1 from public.community_posts p
      where p.id = post_id and (not p.is_hidden or public.is_admin())
    )
  );

-- 투표: 본인 투표만 insert. delete 정책 없음(재투표/취소 불가 — §0 "1인 1회").
drop policy if exists "poll votes insert own" on public.community_poll_votes;
create policy "poll votes insert own" on public.community_poll_votes
  for insert to authenticated with check (user_id = auth.uid());

drop policy if exists "poll votes select own" on public.community_poll_votes;
create policy "poll votes select own" on public.community_poll_votes
  for select to authenticated using (user_id = auth.uid());

-- ── vote_count 캐시 갱신 트리거 ──
-- community_bump_like_count()(community_phase1.sql)와 동일 패턴.
-- 이 트리거는 community_poll_votes에만 바인딩되어 다른 테이블에 새지 않는다.

create or replace function public.community_bump_poll_vote_count()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if tg_op = 'INSERT' then
    update public.community_poll_options
    set vote_count = vote_count + 1
    where id = new.option_id;
    return new;
  elsif tg_op = 'DELETE' then
    update public.community_poll_options
    set vote_count = greatest(vote_count - 1, 0)
    where id = old.option_id;
    return old;
  end if;
  return null;
end;
$$;

drop trigger if exists trg_community_poll_vote_count on public.community_poll_votes;
create trigger trg_community_poll_vote_count
  after insert or delete on public.community_poll_votes
  for each row execute function public.community_bump_poll_vote_count();

-- ── RPC: 투표 생성 (게시글 작성/수정 시 최초 1회) ──
-- 해당 post_id에 옵션이 이미 하나라도 있으면 거부 → "글당 투표 1개" 서버단 강제.
-- 동시 요청 경합(더블탭 등)에 안전하도록 advisory lock으로 post_id를 잠근다.

create or replace function public.create_poll_for_post(
  p_post_id uuid,
  p_options text[]
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_option text;
  v_idx int := 0;
begin
  if v_uid is null then
    raise exception '로그인이 필요해요.';
  end if;

  if not exists (
    select 1 from public.community_posts p
    where p.id = p_post_id and p.user_id = v_uid
  ) then
    raise exception '본인 게시글에만 투표를 추가할 수 있어요.';
  end if;

  perform pg_advisory_xact_lock(hashtextextended(p_post_id::text, 0));

  if exists (
    select 1 from public.community_poll_options where post_id = p_post_id
  ) then
    raise exception '이 게시글에는 이미 투표가 있어요. 게시 후에는 투표를 수정할 수 없어요.';
  end if;

  if p_options is null or array_length(p_options, 1) is null
     or array_length(p_options, 1) < 2 or array_length(p_options, 1) > 5 then
    raise exception '투표 옵션은 2개에서 5개 사이여야 해요.';
  end if;

  foreach v_option in array p_options loop
    if trim(coalesce(v_option, '')) = '' then
      raise exception '빈 옵션은 등록할 수 없어요.';
    end if;
    insert into public.community_poll_options (post_id, label, sort_order)
    values (p_post_id, trim(v_option), v_idx);
    v_idx := v_idx + 1;
  end loop;
end;
$$;

revoke all on function public.create_poll_for_post(uuid, text[]) from public;
grant execute on function public.create_poll_for_post(uuid, text[]) to authenticated;

-- ── RPC: 투표 제출 (중복선택 허용, 1인 1회) ──

create or replace function public.submit_poll_vote(p_option_ids uuid[])
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_post_id uuid;
  v_distinct_post_count int;
  v_option_id uuid;
begin
  if v_uid is null then
    raise exception '로그인이 필요해요.';
  end if;

  if p_option_ids is null or array_length(p_option_ids, 1) is null then
    raise exception '선택한 옵션이 없어요.';
  end if;

  -- 모든 옵션이 같은 게시글에 속하는지 검증
  select count(distinct post_id), min(post_id)
  into v_distinct_post_count, v_post_id
  from public.community_poll_options
  where id = any(p_option_ids);

  if v_distinct_post_count is null or v_distinct_post_count <> 1 then
    raise exception '유효하지 않은 투표 옵션이에요.';
  end if;

  perform pg_advisory_xact_lock(hashtextextended(v_uid::text || ':' || v_post_id::text, 0));

  -- 이미 이 게시글의 투표에 참여했다면(옵션 중 하나라도) 재투표 거부
  if exists (
    select 1
    from public.community_poll_votes v
    join public.community_poll_options o on o.id = v.option_id
    where v.user_id = v_uid and o.post_id = v_post_id
  ) then
    raise exception '이미 투표했어요. 재투표는 할 수 없어요.';
  end if;

  foreach v_option_id in array p_option_ids loop
    insert into public.community_poll_votes (option_id, user_id)
    values (v_option_id, v_uid);
  end loop;
end;
$$;

revoke all on function public.submit_poll_vote(uuid[]) from public;
grant execute on function public.submit_poll_vote(uuid[]) to authenticated;

-- ── RPC: 게시글의 투표 옵션 + 결과 조회 ──

create or replace function public.community_poll_options_for_post(p_post_id uuid)
returns table (
  id uuid,
  label text,
  sort_order int,
  vote_count int,
  voted_by_me boolean
)
language sql
stable
security definer
set search_path = public
as $$
  select
    o.id,
    o.label,
    o.sort_order,
    o.vote_count,
    exists (
      select 1 from public.community_poll_votes v
      where v.option_id = o.id and v.user_id = auth.uid()
    ) as voted_by_me
  from public.community_poll_options o
  where o.post_id = p_post_id
  order by o.sort_order;
$$;

revoke all on function public.community_poll_options_for_post(uuid) from public;
grant execute on function public.community_poll_options_for_post(uuid) to authenticated;

select 'community_poll.sql ok' as status;
