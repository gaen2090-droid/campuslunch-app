-- 캠퍼스런치 소식 알림 (업데이트/이벤트 등 운영 소식) — 어드민 웹에서 수동 발송
-- Dashboard → SQL Editor → Run (reward_push.sql 이후)
--
-- 주의: upsert_notification_prefs 라이브 시그니처는 4-인자
-- (peak_lunch, peak_dinner, community_comments, reward_gifticon) 이므로,
-- news 인자를 추가하면 5-인자가 되어 반드시 4-인자 버전을 DROP 후 재생성해야
-- 오버로드가 남지 않는다.

-- ═══════════════════════════════════════════════════════════════
-- 1. user_notification_prefs에 news 컬럼 추가
-- ═══════════════════════════════════════════════════════════════

alter table public.user_notification_prefs
  add column if not exists news boolean not null default true;

-- ═══════════════════════════════════════════════════════════════
-- 2. upsert_notification_prefs / get_notification_prefs 재정의
--    (기존 4-인자 오버로드가 남지 않도록 반드시 DROP 후 재생성)
-- ═══════════════════════════════════════════════════════════════

drop function if exists public.upsert_notification_prefs(boolean, boolean, boolean, boolean);

create or replace function public.upsert_notification_prefs(
  p_peak_lunch boolean,
  p_peak_dinner boolean,
  p_community_comments boolean,
  p_reward_gifticon boolean default true,
  p_news boolean default true
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  uid uuid := auth.uid();
  result jsonb;
begin
  if uid is null then
    raise exception 'NOT_AUTHENTICATED';
  end if;

  insert into public.user_notification_prefs (
    user_id, peak_lunch, peak_dinner, community_comments, reward_gifticon, news, updated_at
  )
  values (
    uid,
    coalesce(p_peak_lunch, true),
    coalesce(p_peak_dinner, true),
    coalesce(p_community_comments, true),
    coalesce(p_reward_gifticon, true),
    coalesce(p_news, true),
    now()
  )
  on conflict (user_id) do update set
    peak_lunch = excluded.peak_lunch,
    peak_dinner = excluded.peak_dinner,
    community_comments = excluded.community_comments,
    reward_gifticon = excluded.reward_gifticon,
    news = excluded.news,
    updated_at = now()
  returning to_jsonb(user_notification_prefs.*) into result;

  return result;
end;
$$;

revoke all on function public.upsert_notification_prefs(boolean, boolean, boolean, boolean, boolean) from public;
grant execute on function public.upsert_notification_prefs(boolean, boolean, boolean, boolean, boolean) to authenticated;

create or replace function public.get_notification_prefs()
returns jsonb
language sql
security definer
stable
set search_path = public
as $$
  select coalesce(
    (
      select to_jsonb(p)
      from public.user_notification_prefs p
      where p.user_id = auth.uid()
    ),
    jsonb_build_object(
      'user_id', auth.uid(),
      'peak_lunch', true,
      'peak_dinner', true,
      'community_comments', true,
      'reward_gifticon', true,
      'news', true
    )
  );
$$;

revoke all on function public.get_notification_prefs() from public;
grant execute on function public.get_notification_prefs() to authenticated;

-- ═══════════════════════════════════════════════════════════════
-- 3. 소식 알림 수신 대상 토큰 (prefs row 없는 유저는 기본값 true로 포함)
-- ═══════════════════════════════════════════════════════════════

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
  where coalesce(p.news, true);
$$;

revoke all on function public.list_news_push_tokens() from public;
grant execute on function public.list_news_push_tokens() to service_role;

-- ═══════════════════════════════════════════════════════════════
-- 4. push_notification_config에 news_fcm_enabled 킬스위치 추가
-- ═══════════════════════════════════════════════════════════════

alter table public.push_notification_config
  add column if not exists news_fcm_enabled boolean not null default true;

-- ═══════════════════════════════════════════════════════════════
-- 4b. admin_update_push_notification_config에 news_fcm_enabled 인자 추가
--     (라이브 시그니처는 8-인자이므로 반드시 DROP 후 9-인자로 재생성)
-- ═══════════════════════════════════════════════════════════════

drop function if exists public.admin_update_push_notification_config(
  jsonb, boolean, integer, boolean, boolean, boolean, text, text
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
  p_news_fcm_enabled boolean default true
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
    news_fcm_enabled = coalesce(p_news_fcm_enabled, true),
    updated_at = now()
  where id = 1
  returning to_jsonb(push_notification_config.*) into result;

  return result;
end;
$$;

revoke all on function public.admin_update_push_notification_config(
  jsonb, boolean, integer, boolean, boolean, boolean, text, text, boolean
) from public;
grant execute on function public.admin_update_push_notification_config(
  jsonb, boolean, integer, boolean, boolean, boolean, text, text, boolean
) to authenticated;

-- ═══════════════════════════════════════════════════════════════
-- 5. 수신현황 스냅샷에 소식/리워드 알림 도달 지표 추가
--    (admin_push_ops_snapshot: 라이브 정의 기준으로 재정의, 오버로드 걱정 없음 — 인자 없음)
-- ═══════════════════════════════════════════════════════════════

create or replace function public.admin_push_ops_snapshot()
returns jsonb
language plpgsql
stable security definer
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
    'unique_users_with_token', (
      select count(distinct user_id)::int from public.user_push_tokens
    ),
    'peak_lunch_on', (
      select count(*)::int from public.user_notification_prefs where peak_lunch
    ),
    'peak_dinner_on', (
      select count(*)::int from public.user_notification_prefs where peak_dinner
    ),
    'community_on', (
      select count(*)::int from public.user_notification_prefs where community_comments
    ),
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
    'reward_users', (
      select count(distinct t.user_id)::int
      from public.user_push_tokens t
      left join public.user_notification_prefs p on p.user_id = t.user_id
      where coalesce(p.reward_gifticon, true)
    ),
    'reward_devices', (
      select count(*)::int
      from public.user_push_tokens t
      left join public.user_notification_prefs p on p.user_id = t.user_id
      where coalesce(p.reward_gifticon, true)
    ),
    'news_users', (
      select count(distinct t.user_id)::int
      from public.user_push_tokens t
      left join public.user_notification_prefs p on p.user_id = t.user_id
      where coalesce(p.news, true)
    ),
    'news_devices', (
      select count(*)::int
      from public.user_push_tokens t
      left join public.user_notification_prefs p on p.user_id = t.user_id
      where coalesce(p.news, true)
    ),
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

-- ═══════════════════════════════════════════════════════════════
-- 6. 어드민이 임의 발송 — 대상 토큰 목록 + 로그 테이블
-- ═══════════════════════════════════════════════════════════════

create table if not exists public.news_push_sent_log (
  id uuid primary key default gen_random_uuid(),
  title text not null,
  body text not null,
  sent_count int not null default 0,
  failed_count int not null default 0,
  sent_by uuid references public.users(id) on delete set null,
  created_at timestamptz not null default now()
);

alter table public.news_push_sent_log enable row level security;

drop policy if exists "news_push_sent_log_admin_select" on public.news_push_sent_log;
create policy "news_push_sent_log_admin_select" on public.news_push_sent_log
  for select to authenticated
  using (public.is_admin());

create or replace function public.admin_log_news_push(
  p_title text,
  p_body text,
  p_sent_count int,
  p_failed_count int
)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  -- service_role(Edge Function)에서 실제 발송 완료 후 기록하므로 auth.uid()가 없을 수 있음.
  -- 어드민 웹이 직접 호출하는 경로는 authorizeRequest()가 이미 admin JWT를 검증했음.
  insert into public.news_push_sent_log (title, body, sent_count, failed_count, sent_by)
  values (p_title, p_body, p_sent_count, p_failed_count, auth.uid());
end;
$$;

revoke all on function public.admin_log_news_push(text, text, int, int) from public;
grant execute on function public.admin_log_news_push(text, text, int, int) to authenticated, service_role;

-- ═══════════════════════════════════════════════════════════════
-- 7. push_edge_runtime_config에 news_url 컬럼 추가
--    (Dashboard에서 supabase.co/functions/v1/send-news-push 값 채워넣기)
-- ═══════════════════════════════════════════════════════════════

alter table public.push_edge_runtime_config
  add column if not exists news_url text;

select 'news_push.sql ok' as status;
