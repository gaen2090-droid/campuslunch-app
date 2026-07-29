-- 푸시 운영 스냅샷: 「알림 ON ∩ 토큰 있음」수신 가능 인원/기기 수
-- Dashboard → SQL Editor → Run

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
    -- 참고용: 등록된 토큰 전체
    'token_count', (select count(*)::int from public.user_push_tokens),
    'unique_users_with_token', (
      select count(distinct user_id)::int from public.user_push_tokens
    ),
    -- 레거시(알림만 ON, 토큰 유무 무관) — UI는 reachable 우선
    'peak_lunch_on', (
      select count(*)::int from public.user_notification_prefs where peak_lunch
    ),
    'peak_dinner_on', (
      select count(*)::int from public.user_notification_prefs where peak_dinner
    ),
    'community_on', (
      select count(*)::int from public.user_notification_prefs where community_comments
    ),
    -- 실수신: 알림 ON + FCM 토큰 있음
    'lunch_users', (
      select count(distinct t.user_id)::int
      from public.user_push_tokens t
      join public.user_notification_prefs p on p.user_id = t.user_id
      where p.peak_lunch
    ),
    'lunch_devices', (
      select count(*)::int
      from public.user_push_tokens t
      join public.user_notification_prefs p on p.user_id = t.user_id
      where p.peak_lunch
    ),
    'dinner_users', (
      select count(distinct t.user_id)::int
      from public.user_push_tokens t
      join public.user_notification_prefs p on p.user_id = t.user_id
      where p.peak_dinner
    ),
    'dinner_devices', (
      select count(*)::int
      from public.user_push_tokens t
      join public.user_notification_prefs p on p.user_id = t.user_id
      where p.peak_dinner
    ),
    'community_users', (
      select count(distinct t.user_id)::int
      from public.user_push_tokens t
      join public.user_notification_prefs p on p.user_id = t.user_id
      where p.community_comments
    ),
    'community_devices', (
      select count(*)::int
      from public.user_push_tokens t
      join public.user_notification_prefs p on p.user_id = t.user_id
      where p.community_comments
    ),
    -- 설정 전파 = 전체 토큰에 data-only 1회씩
    'config_refresh_devices', (select count(*)::int from public.user_push_tokens),
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

select 'admin_push_ops_snapshot_v2 ok' as status;
