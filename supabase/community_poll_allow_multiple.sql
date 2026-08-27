-- 투표 복수 선택 허용 여부를 글쓴이가 매 투표마다 정할 수 있게 함
-- (Dashboard → SQL Editor → Run, community_poll.sql 이후 실행)
--
-- 지금까지는 모든 투표가 항상 중복선택 허용이었으나, UI 참고 캡처(투표 만들기
-- 화면의 "복수 선택 허용" 토글)에 맞춰 게시글 단위 설정으로 바꾼다.
-- allow_multiple=false면 옵션을 1개만 선택할 수 있고, submit_poll_vote가
-- 서버단에서 2개 이상 제출을 거부한다(버튼 비활성은 클라이언트 UX일 뿐 최종
-- 방어는 서버).

alter table public.community_poll_options
  add column if not exists allow_multiple boolean not null default false;
-- 옵션 테이블에 두는 이유: "글당 투표 1개" 규칙(§0)상 게시글:투표가 1:1이므로
-- post_id별로 이 값이 전부 동일해야 정상 — create_poll_for_post가 생성 시
-- 모든 옵션에 같은 값을 써서 이를 보장한다. 별도 poll 테이블을 새로 만들지
-- 않고 기존 옵션 테이블에 얹어 스키마 변경을 최소화한다.

-- ── create_poll_for_post: p_allow_multiple 파라미터 추가 ──

drop function if exists public.create_poll_for_post(uuid, text[]);

create or replace function public.create_poll_for_post(
  p_post_id uuid,
  p_options text[],
  p_allow_multiple boolean default false
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
    raise exception '투표 항목은 2개에서 5개 사이여야 해요.';
  end if;

  foreach v_option in array p_options loop
    if trim(coalesce(v_option, '')) = '' then
      raise exception '빈 항목은 등록할 수 없어요.';
    end if;
    insert into public.community_poll_options (post_id, label, sort_order, allow_multiple)
    values (p_post_id, trim(v_option), v_idx, coalesce(p_allow_multiple, false));
    v_idx := v_idx + 1;
  end loop;
end;
$$;

revoke all on function public.create_poll_for_post(uuid, text[], boolean) from public;
grant execute on function public.create_poll_for_post(uuid, text[], boolean) to authenticated;

-- ── submit_poll_vote: allow_multiple=false인 투표에 2개 이상 제출 시 거부 ──

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
  v_allow_multiple boolean;
  v_option_id uuid;
begin
  if v_uid is null then
    raise exception '로그인이 필요해요.';
  end if;

  if p_option_ids is null or array_length(p_option_ids, 1) is null then
    raise exception '선택한 항목이 없어요.';
  end if;

  -- 모든 옵션이 같은 게시글에 속하는지 검증 + allow_multiple 값 확보
  -- (uuid는 min/max 집계가 없으므로 대표값은 서브쿼리로 하나만 뽑는다)
  select count(distinct post_id), bool_and(allow_multiple)
  into v_distinct_post_count, v_allow_multiple
  from public.community_poll_options
  where id = any(p_option_ids);

  select post_id into v_post_id
  from public.community_poll_options
  where id = any(p_option_ids)
  limit 1;

  if v_distinct_post_count is null or v_distinct_post_count <> 1 then
    raise exception '유효하지 않은 투표 항목이에요.';
  end if;

  if not coalesce(v_allow_multiple, false) and array_length(p_option_ids, 1) > 1 then
    raise exception '이 투표는 항목을 1개만 선택할 수 있어요.';
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

-- ── community_poll_options_for_post: allow_multiple 반환 추가 ──

drop function if exists public.community_poll_options_for_post(uuid);

create or replace function public.community_poll_options_for_post(p_post_id uuid)
returns table (
  id uuid,
  label text,
  sort_order int,
  vote_count int,
  voted_by_me boolean,
  allow_multiple boolean
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
    ) as voted_by_me,
    o.allow_multiple
  from public.community_poll_options o
  where o.post_id = p_post_id
  order by o.sort_order;
$$;

revoke all on function public.community_poll_options_for_post(uuid) from public;
grant execute on function public.community_poll_options_for_post(uuid) to authenticated;

select 'community_poll_allow_multiple.sql ok' as status;
