-- 앱 분석 이벤트 (DAU/MAU, 추천 배너 클릭률)
-- Dashboard → SQL Editor → Run
--
-- ⚠️ event_type does not exist 오류:
--    예전에 다른 구조로 analytics_events 가 만들어진 경우입니다.
--    아래 DO 블록이 구버전 테이블을 감지해 비우거나 재생성합니다.

DO $$
BEGIN
  IF EXISTS (
    SELECT 1
    FROM information_schema.tables
    WHERE table_schema = 'public'
      AND table_name = 'analytics_events'
  ) AND NOT EXISTS (
    SELECT 1
    FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name = 'analytics_events'
      AND column_name = 'event_type'
  ) THEN
    RAISE NOTICE 'Replacing legacy public.analytics_events (missing event_type)';
    DROP TABLE public.analytics_events CASCADE;
  END IF;
END $$;

create table if not exists public.analytics_events (
  id bigint generated always as identity primary key,
  user_id uuid references auth.users (id) on delete set null,
  event_type text not null check (
    event_type in ('app_session', 'banner_impression', 'banner_click')
  ),
  restaurant_id uuid references public.restaurants (id) on delete set null,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

-- 구버전 테이블에 컬럼만 빠진 경우 (드묾)
alter table public.analytics_events
  add column if not exists event_type text,
  add column if not exists restaurant_id uuid references public.restaurants (id) on delete set null,
  add column if not exists metadata jsonb not null default '{}'::jsonb,
  add column if not exists user_id uuid references auth.users (id) on delete set null,
  add column if not exists created_at timestamptz not null default now();

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conname = 'analytics_events_event_type_check'
  ) THEN
    ALTER TABLE public.analytics_events
      ADD CONSTRAINT analytics_events_event_type_check
      CHECK (event_type in ('app_session', 'banner_impression', 'banner_click'));
  END IF;
EXCEPTION
  WHEN duplicate_object THEN NULL;
END $$;

create index if not exists analytics_events_type_created_idx
  on public.analytics_events (event_type, created_at desc);

create index if not exists analytics_events_user_created_idx
  on public.analytics_events (user_id, created_at desc)
  where user_id is not null;

alter table public.analytics_events enable row level security;

drop policy if exists "analytics_events_insert_auth" on public.analytics_events;
create policy "analytics_events_insert_auth" on public.analytics_events
  for insert to authenticated
  with check (user_id is null or user_id = auth.uid());

-- ── 일 1회 접속 기록 (DAU/MAU 집계용) ──
create or replace function public.record_app_session()
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  uid uuid := auth.uid();
  day_start timestamptz;
begin
  if uid is null then
    return;
  end if;

  day_start := date_trunc('day', now() at time zone 'Asia/Seoul') at time zone 'Asia/Seoul';

  if exists (
    select 1
    from public.analytics_events e
    where e.user_id = uid
      and e.event_type = 'app_session'
      and e.created_at >= day_start
  ) then
    return;
  end if;

  insert into public.analytics_events (user_id, event_type)
  values (uid, 'app_session');

  update public.users
  set last_login_at = now(), updated_at = now()
  where id = uid;
end;
$$;

revoke all on function public.record_app_session() from public;
grant execute on function public.record_app_session() to authenticated;

-- ── 추천 배너 노출/클릭 ──
create or replace function public.record_banner_event(
  p_event text,
  p_restaurant_id uuid
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  uid uuid := auth.uid();
begin
  if uid is null then
    return;
  end if;
  if p_event not in ('banner_impression', 'banner_click') then
    raise exception 'invalid banner event';
  end if;
  if p_restaurant_id is null then
    return;
  end if;

  insert into public.analytics_events (user_id, event_type, restaurant_id)
  values (uid, p_event, p_restaurant_id);
end;
$$;

revoke all on function public.record_banner_event(text, uuid) from public;
grant execute on function public.record_banner_event(text, uuid) to authenticated;

-- ── 관리자 대시보드 지표 ──
create or replace function public.admin_dashboard_metrics()
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  tz constant text := 'Asia/Seoul';
  today_start timestamptz;
  week_start timestamptz;
  mau_start timestamptz;
  daily_dau jsonb := '[]'::jsonb;
  daily_click_rates jsonb := '[]'::jsonb;
  monthly_mau jsonb := '[]'::jsonb;
  i int;
  day_start timestamptz;
  day_end timestamptz;
  month_start timestamptz;
  month_end timestamptz;
  dau_count int;
  mau_count int;
  month_users int;
  impressions_today int;
  clicks_today int;
  click_rate double precision;
  today_reports int;
  week_reports int;
  top_reporters jsonb;
  today_by_restaurant jsonb;
  week_by_restaurant jsonb;
begin
  if auth.uid() is null then
    raise exception 'login required';
  end if;
  if not public.is_admin() then
    raise exception 'admin only';
  end if;

  today_start := date_trunc('day', now() at time zone tz) at time zone tz;
  week_start := today_start - interval '6 days';
  mau_start := today_start - interval '29 days';

  -- DAU: 최근 7일 (오래된 순)
  for i in 0..6 loop
    day_start := today_start - ((6 - i) * interval '1 day');
    day_end := day_start + interval '1 day';

    select count(distinct e.user_id)::int
    into dau_count
    from public.analytics_events e
    where e.event_type = 'app_session'
      and e.user_id is not null
      and e.created_at >= day_start
      and e.created_at < day_end;

    daily_dau := daily_dau || jsonb_build_array(coalesce(dau_count, 0));
  end loop;

  select count(distinct e.user_id)::int
  into dau_count
  from public.analytics_events e
  where e.event_type = 'app_session'
    and e.user_id is not null
    and e.created_at >= today_start
    and e.created_at < today_start + interval '1 day';

  select count(distinct e.user_id)::int
  into mau_count
  from public.analytics_events e
  where e.event_type = 'app_session'
    and e.user_id is not null
    and e.created_at >= mau_start
    and e.created_at < today_start + interval '1 day';

  -- MAU: 최근 6개월 (오래된 순)
  for i in 0..5 loop
    month_start := (
      date_trunc('month', (now() at time zone tz) - ((5 - i) * interval '1 month'))
      at time zone tz
    );
    month_end := month_start + interval '1 month';

    select count(distinct e.user_id)::int
    into month_users
    from public.analytics_events e
    where e.event_type = 'app_session'
      and e.user_id is not null
      and e.created_at >= month_start
      and e.created_at < month_end;

    monthly_mau := monthly_mau || jsonb_build_array(coalesce(month_users, 0));
  end loop;

  -- 배너 클릭률: 최근 7일 (일별 %)
  for i in 0..6 loop
    day_start := today_start - ((6 - i) * interval '1 day');
    day_end := day_start + interval '1 day';

    select count(*)::int
    into impressions_today
    from public.analytics_events e
    where e.event_type = 'banner_impression'
      and e.created_at >= day_start
      and e.created_at < day_end;

    select count(*)::int
    into clicks_today
    from public.analytics_events e
    where e.event_type = 'banner_click'
      and e.created_at >= day_start
      and e.created_at < day_end;

    if impressions_today > 0 then
      click_rate := round((clicks_today::numeric / impressions_today) * 1000) / 10;
    else
      click_rate := 0;
    end if;

    daily_click_rates := daily_click_rates || jsonb_build_array(click_rate);
  end loop;

  -- 오늘 배너 클릭률
  select count(*)::int into impressions_today
  from public.analytics_events e
  where e.event_type = 'banner_impression'
    and e.created_at >= today_start
    and e.created_at < today_start + interval '1 day';

  select count(*)::int into clicks_today
  from public.analytics_events e
  where e.event_type = 'banner_click'
    and e.created_at >= today_start
    and e.created_at < today_start + interval '1 day';

  if impressions_today > 0 then
    click_rate := round((clicks_today::numeric / impressions_today) * 1000) / 10;
  else
    click_rate := 0;
  end if;

  -- 제보 수
  select count(*)::int into today_reports
  from public.crowd_reports cr
  where cr.created_at >= today_start
    and cr.created_at < today_start + interval '1 day'
    and cr.source in ('user', 'owner');

  select count(*)::int into week_reports
  from public.crowd_reports cr
  where cr.created_at >= week_start
    and cr.created_at < today_start + interval '1 day'
    and cr.source in ('user', 'owner');

  select coalesce(jsonb_agg(row order by cnt desc), '[]'::jsonb)
  into top_reporters
  from (
    select jsonb_build_array(
      coalesce(cr.metadata ->> 'nickname', '익명'),
      count(*)::int
    ) as row,
    count(*)::int as cnt
    from public.crowd_reports cr
    where cr.created_at >= today_start
      and cr.created_at < today_start + interval '1 day'
      and cr.source in ('user', 'owner')
      and cr.metadata ? 'user_id'
    group by coalesce(cr.metadata ->> 'nickname', '익명')
    order by cnt desc
    limit 3
  ) t;

  select coalesce(jsonb_object_agg(restaurant_id, cnt), '{}'::jsonb)
  into today_by_restaurant
  from (
    select cr.restaurant_id::text as restaurant_id, count(*)::int as cnt
    from public.crowd_reports cr
    where cr.created_at >= today_start
      and cr.created_at < today_start + interval '1 day'
      and cr.source in ('user', 'owner')
    group by cr.restaurant_id
  ) t;

  select coalesce(jsonb_object_agg(restaurant_id, cnt), '{}'::jsonb)
  into week_by_restaurant
  from (
    select cr.restaurant_id::text as restaurant_id, count(*)::int as cnt
    from public.crowd_reports cr
    where cr.created_at >= week_start
      and cr.created_at < today_start + interval '1 day'
      and cr.source in ('user', 'owner')
    group by cr.restaurant_id
  ) t;

  return jsonb_build_object(
    'dau_today', coalesce(dau_count, 0),
    'mau', coalesce(mau_count, 0),
    'daily_dau', daily_dau,
    'monthly_mau', monthly_mau,
    'today_reports', coalesce(today_reports, 0),
    'week_reports', coalesce(week_reports, 0),
    'banner_click_rate', click_rate,
    'daily_click_rates', daily_click_rates,
    'top_reporters', top_reporters,
    'today_by_restaurant', today_by_restaurant,
    'week_by_restaurant', week_by_restaurant
  );
end;
$$;

revoke all on function public.admin_dashboard_metrics() from public;
revoke all on function public.admin_dashboard_metrics() from anon;
grant execute on function public.admin_dashboard_metrics() to authenticated;
