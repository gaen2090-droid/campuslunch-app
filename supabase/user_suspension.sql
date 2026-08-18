-- 유저 이용 정지 — 커뮤니티(글쓰기/댓글)와 제보 기능을 각각 독립적으로,
-- 관리자가 지정한 기간만큼 정지시킬 수 있다. 로그인 자체는 막지 않는다.
-- 정책 근거: COMMUNITY_POLICY.md 제9조("계정 이용 정지"), REPORT_OPERATION_POLICY.md
-- 제6조("제보 기능 이용 제한", "계정 이용 제한").
-- Dashboard → SQL Editor → Run (rpc_admin_users.sql, admin_moderation_notifications.sql 이후)

-- admin_moderation_notifications.target_kind CHECK에 정지 알림 종류 추가
alter table public.admin_moderation_notifications
  drop constraint if exists admin_moderation_notifications_target_kind_check;
alter table public.admin_moderation_notifications
  add constraint admin_moderation_notifications_target_kind_check
  check (target_kind in (
    'post', 'comment', 'collection',
    'community_suspend', 'report_suspend',
    'community_unsuspend', 'report_unsuspend'
  ));

alter table public.users
  add column if not exists community_suspended_until timestamptz,
  add column if not exists community_suspend_reason text,
  add column if not exists report_suspended_until timestamptz,
  add column if not exists report_suspend_reason text;

-- 정지 알림 헤드라인에 "n일간 정지됐어요"를 표시하기 위해 종료 시각을 함께 싣는다.
alter table public.admin_moderation_notifications
  add column if not exists suspended_until timestamptz;

-- ── 정지 여부 판단 헬퍼 ──
create or replace function public.is_community_suspended(p_user_id uuid)
returns boolean
language sql
stable
as $$
  select exists (
    select 1 from public.users u
    where u.id = p_user_id
      and u.community_suspended_until is not null
      and u.community_suspended_until > now()
  );
$$;

create or replace function public.is_report_suspended(p_user_id uuid)
returns boolean
language sql
stable
as $$
  select exists (
    select 1 from public.users u
    where u.id = p_user_id
      and u.report_suspended_until is not null
      and u.report_suspended_until > now()
  );
$$;

-- ── 어드민: 정지 설정/해제 ──
-- p_days: 정지 기간(일). null 또는 0 이하면 정지를 해제한다.
create or replace function public.admin_set_community_suspension(
  p_user_id uuid,
  p_days    int,
  p_reason  text default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_until timestamptz;
  v_reason text;
  v_was_suspended boolean;
begin
  if not public.is_admin() then
    raise exception '관리자만 처리할 수 있어요.';
  end if;
  if p_user_id is null then
    raise exception 'user id가 필요해요.';
  end if;
  if exists (
    select 1 from public.users u
    where u.id = p_user_id and u.role = 'admin'::public.user_role
  ) then
    raise exception '관리자 계정은 정지할 수 없어요.';
  end if;

  v_until := case when p_days is null or p_days <= 0
    then null
    else now() + make_interval(days => p_days)
  end;
  v_reason := nullif(trim(coalesce(p_reason, '')), '');

  if v_until is not null and v_reason is null then
    raise exception '정지 사유를 입력해주세요.';
  end if;

  select public.is_community_suspended(p_user_id) into v_was_suspended;

  update public.users
  set community_suspended_until = v_until,
      community_suspend_reason = case when v_until is null then null else v_reason end
  where id = p_user_id;

  if not found then
    return jsonb_build_object('ok', false, 'message', '해당 회원을 찾을 수 없어요.');
  end if;

  if v_until is not null then
    insert into public.admin_moderation_notifications
      (recipient_user_id, target_kind, reason, suspended_until)
    values (p_user_id, 'community_suspend', v_reason, v_until);
  elsif v_was_suspended then
    insert into public.admin_moderation_notifications
      (recipient_user_id, target_kind, reason)
    values (p_user_id, 'community_unsuspend', null);
  end if;

  return jsonb_build_object(
    'ok', true,
    'id', p_user_id,
    'community_suspended_until', v_until
  );
end;
$$;

create or replace function public.admin_set_report_suspension(
  p_user_id uuid,
  p_days    int,
  p_reason  text default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_until timestamptz;
  v_reason text;
  v_was_suspended boolean;
begin
  if not public.is_admin() then
    raise exception '관리자만 처리할 수 있어요.';
  end if;
  if p_user_id is null then
    raise exception 'user id가 필요해요.';
  end if;
  if exists (
    select 1 from public.users u
    where u.id = p_user_id and u.role = 'admin'::public.user_role
  ) then
    raise exception '관리자 계정은 정지할 수 없어요.';
  end if;

  v_until := case when p_days is null or p_days <= 0
    then null
    else now() + make_interval(days => p_days)
  end;
  v_reason := nullif(trim(coalesce(p_reason, '')), '');

  if v_until is not null and v_reason is null then
    raise exception '정지 사유를 입력해주세요.';
  end if;

  select public.is_report_suspended(p_user_id) into v_was_suspended;

  update public.users
  set report_suspended_until = v_until,
      report_suspend_reason = case when v_until is null then null else v_reason end
  where id = p_user_id;

  if not found then
    return jsonb_build_object('ok', false, 'message', '해당 회원을 찾을 수 없어요.');
  end if;

  if v_until is not null then
    insert into public.admin_moderation_notifications
      (recipient_user_id, target_kind, reason, suspended_until)
    values (p_user_id, 'report_suspend', v_reason, v_until);
  elsif v_was_suspended then
    insert into public.admin_moderation_notifications
      (recipient_user_id, target_kind, reason)
    values (p_user_id, 'report_unsuspend', null);
  end if;

  return jsonb_build_object(
    'ok', true,
    'id', p_user_id,
    'report_suspended_until', v_until
  );
end;
$$;

revoke all on function public.admin_set_community_suspension(uuid, int, text) from public;
revoke all on function public.admin_set_report_suspension(uuid, int, text) from public;
grant execute on function public.admin_set_community_suspension(uuid, int, text) to authenticated;
grant execute on function public.admin_set_report_suspension(uuid, int, text) to authenticated;

-- ── admin_list_users(): 정지 상태 컬럼 포함해서 재정의 ──
-- Postgres는 함수 반환 타입을 제자리에서 못 바꾸므로 drop 후 재생성.
drop function if exists public.admin_list_users();

create or replace function public.admin_list_users()
returns jsonb
language plpgsql
security definer
set search_path = public, auth
as $$
begin
  if not public.is_admin() then
    raise exception '관리자만 조회할 수 있어요.';
  end if;

  return coalesce((
    select jsonb_agg(row_to_json(t) order by t.created_at desc)
    from (
      select
        u.id,
        u.email,
        u.nickname,
        u.role::text as role,
        u.provider,
        u.created_at,
        u.last_login_at,
        u.community_suspended_until,
        u.community_suspend_reason,
        u.report_suspended_until,
        u.report_suspend_reason,
        coalesce((
          select count(*)::int
          from public.crowd_reports cr
          where cr.user_id = u.id
        ), 0) as crowd_report_count,
        coalesce(ur.total_stamps, 0) as total_stamps,
        exists (
          select 1 from public.restaurants r where r.owner_id = u.id
        ) as is_owner
      from public.users u
      left join public.user_rewards ur on ur.user_id = u.id
      order by u.created_at desc
    ) t
  ), '[]'::jsonb);
end;
$$;

revoke all on function public.admin_list_users() from public;
grant execute on function public.admin_list_users() to authenticated;

-- ── 커뮤니티 글쓰기/댓글 RLS에 정지 체크 반영 ──
-- community_phase1.sql의 "posts insert own" / "comments insert own"을
-- 정지 체크가 포함된 조건으로 덮어쓴다. add_community_comment RPC도
-- 결국 이 INSERT를 거치므로 별도 RPC 수정 없이 여기서 함께 막힌다.
drop policy if exists "posts insert own" on public.community_posts;
create policy "posts insert own" on public.community_posts
  for insert to authenticated
  with check (
    user_id = auth.uid()
    and not public.is_community_suspended(auth.uid())
  );

drop policy if exists "comments insert own" on public.community_comments;
create policy "comments insert own" on public.community_comments
  for insert to authenticated
  with check (
    user_id = auth.uid()
    and not public.is_community_suspended(auth.uid())
  );

-- ⚠️ 인박스 RPC(community_inbox_notifications)는 여기서 재정의하지 않는다.
-- comment_reply_notifications.sql이 이미 더 최신 버전(reply kind, is_read 컬럼
-- 포함)을 배포해뒀고, 그 파일의 admin_ 접두사 분기를 정지/해제 kind는
-- 접두사 없이 통과하도록 이미 고쳐뒀다(target_kind in ('post','comment','collection')
-- 일 때만 'admin_' 접두사).
--
-- 이 파일 실행 후 반드시 comment_reply_notifications.sql을 다시 실행할 것 —
-- 순서가 바뀌면(이 파일이 나중에 실행되면) 정지/해제 알림이 'admin_community_suspend'
-- 같은 값으로 잘못 나가서 앱에서 일반 댓글 알림(초록 배경)으로 오표시된다.

-- ── 이용 제한 내역: 커뮤니티 메뉴 → "이용 제한 내역" 전용 조회 RPC ──
-- 인박스(community_inbox_notifications)와 달리 댓글/좋아요와 섞이지 않고
-- 본인의 정지/해제 이력만 반환한다. 알림창과 동일한 표시 형식(헤드라인+사유)을
-- 쓰되 화면에서 빨간 배경 강조는 하지 않는다.
create or replace function public.my_suspension_history()
returns table (
  kind text,
  event_id text,
  reason text,
  suspended_until timestamptz,
  created_at timestamptz
)
language sql
stable
security definer
set search_path = public
as $$
  select
    n.target_kind as kind,
    n.id::text as event_id,
    n.reason,
    n.suspended_until,
    n.created_at
  from public.admin_moderation_notifications n
  where n.recipient_user_id = auth.uid()
    and n.target_kind in (
      'community_suspend', 'report_suspend',
      'community_unsuspend', 'report_unsuspend'
    )
  order by n.created_at desc
  limit 100;
$$;

revoke all on function public.my_suspension_history() from public;
grant execute on function public.my_suspension_history() to authenticated;

-- ── 홈 화면 정지/해제 팝업: "정지 후 첫 로그인" 판단 ──
-- 인박스 카드 읽음(community_inbox_reads)과는 별개 상태. 관리자 알림 카드는
-- 개별 읽음 경로가 없다는 기존 설계(community_inbox_read_state.sql 참고)를
-- 유지하면서, 팝업 확인 여부만 이 테이블로 추적한다.
create table if not exists public.suspension_popup_seen (
  user_id  uuid not null references public.users(id) on delete cascade,
  event_id text not null,
  seen_at  timestamptz not null default now(),
  primary key (user_id, event_id)
);

alter table public.suspension_popup_seen enable row level security;

drop policy if exists "suspension popup seen select own" on public.suspension_popup_seen;
create policy "suspension popup seen select own" on public.suspension_popup_seen
  for select to authenticated using (user_id = auth.uid());

-- 로그인 직후 호출: 아직 팝업으로 확인 안 한 가장 최근 정지/해제 알림 1건.
-- 없으면 빈 결과.
create or replace function public.my_pending_suspension_popup()
returns table (
  kind text,
  event_id text,
  reason text,
  suspended_until timestamptz,
  created_at timestamptz
)
language sql
stable
security definer
set search_path = public
as $$
  select
    n.target_kind as kind,
    n.id::text as event_id,
    n.reason,
    n.suspended_until,
    n.created_at
  from public.admin_moderation_notifications n
  where n.recipient_user_id = auth.uid()
    and n.target_kind in (
      'community_suspend', 'report_suspend',
      'community_unsuspend', 'report_unsuspend'
    )
    and not exists (
      select 1 from public.suspension_popup_seen s
      where s.user_id = auth.uid() and s.event_id = n.id::text
    )
  order by n.created_at desc
  limit 1;
$$;

revoke all on function public.my_pending_suspension_popup() from public;
grant execute on function public.my_pending_suspension_popup() to authenticated;

create or replace function public.mark_suspension_popup_seen(p_event_id text)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
begin
  if v_uid is null then
    raise exception '로그인이 필요해요.';
  end if;

  insert into public.suspension_popup_seen (user_id, event_id)
  values (v_uid, p_event_id)
  on conflict (user_id, event_id) do nothing;
end;
$$;

revoke all on function public.mark_suspension_popup_seen(text) from public;
grant execute on function public.mark_suspension_popup_seen(text) to authenticated;

select 'user_suspension.sql ok' as status;
