-- 좋아요 앱 푸시(FCM) 제거 (Dashboard → SQL Editor → Run)
-- 실행 순서: community_push_v2.sql 이후. 앱 푸시는 점심/저녁 피크 + 댓글만 유지.
-- 알림창(인박스)의 좋아요 표시는 community_inbox_notifications()에 그대로 남아있음 — 영향 없음.

drop trigger if exists community_likes_fcm_push on public.community_likes;
drop function if exists public.notify_community_like_push();
drop function if exists public.list_community_like_push_recipients(uuid, uuid);

alter table public.push_notification_config
  drop column if exists community_like_title_template;
alter table public.push_notification_config
  drop column if exists community_like_body_template;

-- ── 어드민 설정 RPC: 좋아요 문구 파라미터 제거 ──

drop function if exists public.admin_update_push_notification_config(
  int, int, int, int, text, text, boolean, int, boolean, boolean, boolean, text, text, text, text
);

create or replace function public.admin_update_push_notification_config(
  p_lunch_hour int,
  p_lunch_minute int,
  p_dinner_hour int,
  p_dinner_minute int,
  p_title_template text,
  p_body_template text,
  p_weekdays_only boolean,
  p_schedule_days_ahead int,
  p_peak_fcm_enabled boolean default false,
  p_community_fcm_enabled boolean default true,
  p_peak_local_schedule_enabled boolean default true,
  p_community_comment_title_template text default null,
  p_community_comment_body_template text default null
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
    raise exception '피크 제목 템플릿을 입력해주세요.';
  end if;
  if trim(coalesce(p_body_template, '')) = '' then
    raise exception '피크 본문을 입력해주세요.';
  end if;
  if position('{gate}' in p_title_template) = 0 then
    raise exception '피크 제목 템플릿에 {gate} 가 포함되어야 해요.';
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
    peak_fcm_enabled = coalesce(p_peak_fcm_enabled, false),
    community_fcm_enabled = coalesce(p_community_fcm_enabled, true),
    peak_local_schedule_enabled = coalesce(p_peak_local_schedule_enabled, true),
    community_comment_title_template = coalesce(
      nullif(trim(p_community_comment_title_template), ''),
      community_comment_title_template
    ),
    community_comment_body_template = coalesce(
      nullif(trim(p_community_comment_body_template), ''),
      community_comment_body_template
    ),
    updated_at = now()
  where id = 1
  returning to_jsonb(push_notification_config.*) into result;

  return result;
end;
$$;

revoke all on function public.admin_update_push_notification_config(
  int, int, int, int, text, text, boolean, int, boolean, boolean, boolean, text, text
) from public;
grant execute on function public.admin_update_push_notification_config(
  int, int, int, int, text, text, boolean, int, boolean, boolean, boolean, text, text
) to authenticated;

select 'community_push_remove_like.sql ok' as status;
