-- 피크 푸시: 고정 점심/저녁 2회 → peak_schedules JSON 배열로 자유 커스텀
-- Dashboard → SQL Editor → Run
--
-- 각 스케줄: { id, label, enabled, hour, minute, title_template, body_template }
-- 문구는 자유 입력 (구역명 {gate} 플레이스홀더는 사용하지 않음)

alter table public.push_notification_config
  add column if not exists peak_schedules jsonb;

-- 기존 lunch/dinner + 공통 문구 → schedules 시드 (이미 있으면면 유지)
update public.push_notification_config c
set peak_schedules = jsonb_build_array(
  jsonb_build_object(
    'id', 'lunch',
    'label', '점심',
    'enabled', true,
    'hour', c.lunch_hour,
    'minute', c.lunch_minute,
    'title_template', regexp_replace(c.title_template, '\{gate\}', '캠퍼스', 'g'),
    'body_template', regexp_replace(c.body_template, '\{gate\}', '캠퍼스', 'g')
  ),
  jsonb_build_object(
    'id', 'dinner',
    'label', '저녁',
    'enabled', true,
    'hour', c.dinner_hour,
    'minute', c.dinner_minute,
    'title_template', regexp_replace(c.title_template, '\{gate\}', '캠퍼스', 'g'),
    'body_template', regexp_replace(c.body_template, '\{gate\}', '캠퍼스', 'g')
  )
)
where c.id = 1
  and (c.peak_schedules is null or jsonb_typeof(c.peak_schedules) <> 'array'
       or jsonb_array_length(c.peak_schedules) = 0);

-- 커스텀 슬롯 토큰: lunch/dinner는 기존 pref, 그 외는 둘 중 하나라도 ON이면 수신
create or replace function public.list_peak_push_tokens(p_slot text)
returns table (user_id uuid, token text)
language sql
stable
security definer
set search_path = public
as $$
  select t.user_id, t.token
  from public.user_push_tokens t
  join public.user_notification_prefs p on p.user_id = t.user_id
  where (
    (p_slot = 'lunch' and p.peak_lunch)
    or (p_slot = 'dinner' and p.peak_dinner)
    or (
      p_slot is distinct from 'lunch'
      and p_slot is distinct from 'dinner'
      and (p.peak_lunch or p.peak_dinner)
    )
  );
$$;

revoke all on function public.list_peak_push_tokens(text) from public;
grant execute on function public.list_peak_push_tokens(text) to service_role;

-- 구 RPC 오버로드 정리 후 schedules 기반 저장
drop function if exists public.admin_update_push_notification_config(
  int, int, int, int, text, text, boolean, int, boolean, boolean, boolean, text, text
);
drop function if exists public.admin_update_push_notification_config(
  int, int, int, int, text, text, boolean, int, boolean, boolean, boolean, text, text, text, text
);
drop function if exists public.admin_update_push_notification_config(
  int, int, int, int, text, text, boolean, int, boolean, boolean, boolean
);
drop function if exists public.admin_update_push_notification_config(
  int, int, int, int, text, text, boolean, int
);

create or replace function public.admin_update_push_notification_config(
  p_peak_schedules jsonb,
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
  elem jsonb;
  i int;
  v_id text;
  v_hour int;
  v_minute int;
  v_title text;
  v_body text;
  v_enabled boolean;
  enabled_count int := 0;
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
    v_enabled := coalesce((elem ->> 'enabled')::boolean, true);

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

    if v_enabled then
      enabled_count := enabled_count + 1;
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

  if enabled_count = 0 then
    raise exception '활성화된 피크 스케줄이 최소 1개 필요해요.';
  end if;

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
    updated_at = now()
  where id = 1
  returning to_jsonb(push_notification_config.*) into result;

  return result;
end;
$$;

revoke all on function public.admin_update_push_notification_config(
  jsonb, boolean, int, boolean, boolean, boolean, text, text
) from public;
grant execute on function public.admin_update_push_notification_config(
  jsonb, boolean, int, boolean, boolean, boolean, text, text
) to authenticated;

select 'push_peak_schedules.sql ok' as status;
