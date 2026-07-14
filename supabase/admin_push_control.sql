-- 어드민 푸시 통제 (전역 ON/OFF · 운영 스냅샷 · device_tokens 별칭)
-- fcm_push.sql 이후 실행

-- ── config 확장 ──
alter table public.push_notification_config
  add column if not exists peak_fcm_enabled boolean not null default false;

alter table public.push_notification_config
  add column if not exists community_fcm_enabled boolean not null default true;

alter table public.push_notification_config
  add column if not exists peak_local_schedule_enabled boolean not null default true;

-- 기획서의 device_tokens 이름과 호환
create or replace view public.device_tokens as
  select id, user_id, token, platform, updated_at
  from public.user_push_tokens;

-- users 컬럼 호환 (파트너 기획) — prefs와 동기
alter table public.users
  add column if not exists community_comment_push_enabled boolean not null default true;

create or replace function public.sync_community_push_flag_from_prefs()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  update public.users
  set community_comment_push_enabled = new.community_comments
  where id = new.user_id;
  return new;
end;
$$;

drop trigger if exists user_notif_prefs_sync_community on public.user_notification_prefs;
create trigger user_notif_prefs_sync_community
  after insert or update of community_comments on public.user_notification_prefs
  for each row execute function public.sync_community_push_flag_from_prefs();

-- 기존 RPC 교체: 전역 플래그 포함
drop function if exists public.admin_update_push_notification_config(int, int, int, int, text, text, boolean, int);

create or replace function public.admin_update_push_notification_config(
  p_lunch_hour int,
  p_lunch_minute int,
  p_dinner_hour int,
  p_dinner_minute int,
  p_title_template text,
  p_body_template text,
  p_weekdays_only boolean,
  p_schedule_days_ahead int,
  p_peak_fcm_enabled boolean default true,
  p_community_fcm_enabled boolean default true,
  p_peak_local_schedule_enabled boolean default false
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  result jsonb;
begin
  if not public.is_admin() then
    raise exception '관리자만 푸시 설정을 변경할 수 있어요.';
  end if;

  if trim(coalesce(p_title_template, '')) = '' then
    raise exception '제목 템플릿을 입력해주세요.';
  end if;
  if trim(coalesce(p_body_template, '')) = '' then
    raise exception '본문 템플릿을 입력해주세요.';
  end if;
  if position('{gate}' in p_title_template) = 0 then
    raise exception '제목 템플릿에 {gate} 가 포함되어야 해요.';
  end if;

  update public.push_notification_config
  set
    lunch_hour = p_lunch_hour,
    lunch_minute = p_lunch_minute,
    dinner_hour = p_dinner_hour,
    dinner_minute = p_dinner_minute,
    title_template = trim(p_title_template),
    body_template = trim(p_body_template),
    weekdays_only = p_weekdays_only,
    schedule_days_ahead = p_schedule_days_ahead,
    peak_fcm_enabled = coalesce(p_peak_fcm_enabled, true),
    community_fcm_enabled = coalesce(p_community_fcm_enabled, true),
    peak_local_schedule_enabled = coalesce(p_peak_local_schedule_enabled, false),
    updated_at = now()
  where id = 1
  returning to_jsonb(push_notification_config.*) into result;

  return result;
end;
$$;

revoke all on function public.admin_update_push_notification_config(int, int, int, int, text, text, boolean, int, boolean, boolean, boolean) from public;
grant execute on function public.admin_update_push_notification_config(int, int, int, int, text, text, boolean, int, boolean, boolean, boolean) to authenticated;

-- 운영 현황 (어드민)
create or replace function public.admin_push_ops_snapshot()
returns jsonb
language plpgsql
security definer
stable
set search_path = public
as $$
declare
  result jsonb;
begin
  if not public.is_admin() then
    raise exception '관리자만 조회할 수 있어요.';
  end if;

  select jsonb_build_object(
    'token_count', (select count(*)::int from public.user_push_tokens),
    'unique_users_with_token', (select count(distinct user_id)::int from public.user_push_tokens),
    'peak_lunch_on', (
      select count(*)::int from public.user_notification_prefs where peak_lunch
    ),
    'peak_dinner_on', (
      select count(*)::int from public.user_notification_prefs where peak_dinner
    ),
    'community_on', (
      select count(*)::int from public.user_notification_prefs where community_comments
    ),
    'last_peak_sent', coalesce((
      select jsonb_agg(jsonb_build_object(
        'sent_date', s.sent_date,
        'slot', s.slot,
        'created_at', s.created_at
      ) order by s.created_at desc)
      from (
        select * from public.peak_push_sent_log
        order by created_at desc
        limit 10
      ) s
    ), '[]'::jsonb),
    'config', (select to_jsonb(c) from public.push_notification_config c where c.id = 1)
  ) into result;

  return result;
end;
$$;

revoke all on function public.admin_push_ops_snapshot() from public;
grant execute on function public.admin_push_ops_snapshot() to authenticated;

select 'admin_push_control.sql ok' as status;
