-- 피크 스케줄 전체 OFF 저장 거부 버그 재발 수정 (2차)
--
-- hotfix_allow_all_peak_schedules_off.sql(184e700)에서 이미 한 번 제거했던
-- "활성화된 피크 스케줄이 최소 1개 필요해요" 제약(enabled_count = 0 체크)이,
-- 답글 알림 작업(reply_push_notifications.sql, 8f4035b)에서
-- admin_update_push_notification_config를 답글 문구 인자 추가 목적으로
-- 재정의하며 실수로 되살아났음. 다시 제거.
--
-- (Dashboard → SQL Editor → Run)

create or replace function public.admin_update_push_notification_config(
  p_peak_schedules jsonb,
  p_weekdays_only boolean,
  p_schedule_days_ahead integer,
  p_peak_fcm_enabled boolean default false,
  p_community_fcm_enabled boolean default true,
  p_peak_local_schedule_enabled boolean default true,
  p_community_comment_title_template text default null,
  p_community_comment_body_template text default null,
  p_news_fcm_enabled boolean default true,
  p_community_reply_title_template text default null,
  p_community_reply_body_template text default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  result jsonb;
  elem jsonb;
  i int;
  v_id text;
  v_hour int;
  v_minute int;
  v_title text;
  v_body text;
  lunch_h int := 12;
  lunch_m int := 0;
  dinner_h int := 18;
  dinner_m int := 0;
  sync_title text;
  sync_body text;
  seen_lunch boolean := false;
  seen_dinner boolean := false;
begin
  if not public.is_admin() then
    raise exception '관리자만 푸시 설정을 변경할 수 있어요.';
  end if;

  if p_peak_schedules is null or jsonb_typeof(p_peak_schedules) <> 'array' then
    raise exception '피크 스케줄 목록이 올바르지 않아요.';
  end if;
  if jsonb_array_length(p_peak_schedules) = 0 then
    raise exception '피크 스케줄을 1개 이상 추가해주세요.';
  end if;
  if jsonb_array_length(p_peak_schedules) > 8 then
    raise exception '피크 스케줄은 최대 8개까지예요.';
  end if;

  for i in 0 .. jsonb_array_length(p_peak_schedules) - 1 loop
    elem := p_peak_schedules -> i;
    v_id := nullif(trim(coalesce(elem ->> 'id', '')), '');
    v_hour := coalesce((elem ->> 'hour')::int, -1);
    v_minute := coalesce((elem ->> 'minute')::int, -1);
    v_title := trim(coalesce(elem ->> 'title_template', ''));
    v_body := trim(coalesce(elem ->> 'body_template', ''));

    if v_id is null then
      raise exception '스케줄 id가 비어 있어요.';
    end if;
    if v_hour < 0 or v_hour > 23 or v_minute < 0 or v_minute > 59 then
      raise exception '스케줄 시각이 올바르지 않아요. (%)', v_id;
    end if;
    if v_title = '' then
      raise exception '스케줄 제목을 입력해주세요. (%)', v_id;
    end if;
    if v_body = '' then
      raise exception '스케줄 본문을 입력해주세요. (%)', v_id;
    end if;

    if v_id = 'lunch' or (not seen_lunch and i = 0) then
      lunch_h := v_hour;
      lunch_m := v_minute;
      seen_lunch := true;
    end if;
    if v_id = 'dinner' or (not seen_dinner and i = 1) then
      dinner_h := v_hour;
      dinner_m := v_minute;
      seen_dinner := true;
    end if;

    if sync_title is null then
      sync_title := v_title;
      sync_body := v_body;
    end if;
  end loop;

  update public.push_notification_config
  set
    peak_schedules = p_peak_schedules,
    lunch_hour = lunch_h,
    lunch_minute = lunch_m,
    dinner_hour = dinner_h,
    dinner_minute = dinner_m,
    title_template = coalesce(sync_title, title_template),
    body_template = coalesce(sync_body, body_template),
    weekdays_only = p_weekdays_only,
    schedule_days_ahead = greatest(1, least(coalesce(p_schedule_days_ahead, 14), 30)),
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
    news_fcm_enabled = coalesce(p_news_fcm_enabled, true),
    community_reply_title_template = coalesce(
      nullif(trim(p_community_reply_title_template), ''),
      community_reply_title_template
    ),
    community_reply_body_template = coalesce(
      nullif(trim(p_community_reply_body_template), ''),
      community_reply_body_template
    ),
    updated_at = now()
  where id = 1
  returning to_jsonb(push_notification_config.*) into result;

  return result;
end;
$$;

select 'hotfix_allow_all_peak_schedules_off_v2.sql ok' as status;
