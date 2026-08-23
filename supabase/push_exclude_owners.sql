-- 피크(점심/저녁)·소식 알림에 "사장님 제외" 옵션 추가
-- Dashboard → SQL Editor → Run
-- (hotfix_allow_all_peak_schedules_off_v2.sql, push_peak_schedules.sql, news_push.sql 이후)
--
-- "사장님으로 등록된 계정"의 기준은 restaurants.owner_id에 연결된 유저다.
-- users.role='owner'는 코드 경로에 따라 실제 소유 매장과 어긋날 수 있는 파생값이라
-- (rpc_claim_owner.sql 하단의 role 복구 쿼리 참고) 기준으로 쓰지 않는다.
--
-- ⚠️ 이 파일의 list_news_push_tokens()는 0-인자 버전이다. news_push_owner_target.sql
--    (이 파일 다음에 실행)이 1-인자(p_target) 버전으로 대체하며 0-인자 버전을 drop한다.
--    이 파일을 news_push_owner_target.sql보다 나중에 재실행하면 두 오버로드가 같이
--    남아 무인자 호출이 모호(ambiguous)해진다 — 재실행 시 반드시 news_push_owner_target.sql을
--    다시 실행해 1-인자 버전으로 되돌릴 것.

-- ── 1. 설정 컬럼 추가 ──
alter table public.push_notification_config
  add column if not exists peak_exclude_owners boolean not null default false;
alter table public.push_notification_config
  add column if not exists news_exclude_owners boolean not null default false;

-- ── 2. admin_update_push_notification_config 재정의 (라이브 11-인자 → 13-인자) ──
drop function if exists public.admin_update_push_notification_config(
  jsonb, boolean, integer, boolean, boolean, boolean, text, text, boolean, text, text
);

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
  p_community_reply_body_template text default null,
  p_peak_exclude_owners boolean default false,
  p_news_exclude_owners boolean default false
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
    peak_exclude_owners = coalesce(p_peak_exclude_owners, false),
    news_exclude_owners = coalesce(p_news_exclude_owners, false),
    updated_at = now()
  where id = 1
  returning to_jsonb(push_notification_config.*) into result;

  return result;
end;
$$;

revoke all on function public.admin_update_push_notification_config(
  jsonb, boolean, integer, boolean, boolean, boolean, text, text, boolean, text, text, boolean, boolean
) from public;
grant execute on function public.admin_update_push_notification_config(
  jsonb, boolean, integer, boolean, boolean, boolean, text, text, boolean, text, text, boolean, boolean
) to authenticated;

-- ── 3. 사장님 판정 헬퍼 ──
create or replace function public.is_any_restaurant_owner(p_user_id uuid)
returns boolean
language sql
stable
set search_path = public
as $$
  select exists (
    select 1 from public.restaurants r where r.owner_id = p_user_id
  );
$$;

revoke all on function public.is_any_restaurant_owner(uuid) from public;
grant execute on function public.is_any_restaurant_owner(uuid) to authenticated, service_role;

-- ── 4. list_peak_push_tokens: 설정에 따라 사장님 제외 ──
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
  )
  and not (
    coalesce((select c.peak_exclude_owners from public.push_notification_config c where c.id = 1), false)
    and public.is_any_restaurant_owner(t.user_id)
  );
$$;

revoke all on function public.list_peak_push_tokens(text) from public;
grant execute on function public.list_peak_push_tokens(text) to service_role;

-- ── 5. list_news_push_tokens: 설정에 따라 사장님 제외 ──
create or replace function public.list_news_push_tokens()
returns table (token text)
language sql
stable
security definer
set search_path = public
as $$
  select t.token
  from public.user_push_tokens t
  left join public.user_notification_prefs p on p.user_id = t.user_id
  where coalesce(p.news, true)
    and not (
      coalesce((select c.news_exclude_owners from public.push_notification_config c where c.id = 1), false)
      and public.is_any_restaurant_owner(t.user_id)
    );
$$;

revoke all on function public.list_news_push_tokens() from public;
grant execute on function public.list_news_push_tokens() to service_role;

select 'push_exclude_owners.sql ok' as status;
