-- 캠퍼스런치 어드민 대시보드 v2: 실시간 지표 / KPI / 운영 성과 전면 개편
-- 실행 순서: analytics_events.sql, push_analytics.sql, owner_detail_view_stats.sql,
--           crowd_status.sql, rewards.sql, admin_kpi_targets.sql 이후
-- Dashboard → SQL Editor → Run

-- ═══════════════════════════════════════════════════════════════
-- 0. app_session: 하루 1건 → 30분 dedup으로 변경 (시간대별 분석 위해)
-- ═══════════════════════════════════════════════════════════════
-- ⚠️ 이 변경 이전 데이터는 유저당 하루 1건(최초 접속 시각)만 있어
--    과거 날짜의 "시간대별/점심시간대별 추이"는 부정확하거나 비어있을 수 있음.
--    이후 데이터부터 정상적으로 시간대별 분석이 가능해진다.

create or replace function public.record_app_session()
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  uid uuid := auth.uid();
  dedup_start timestamptz;
begin
  if uid is null then
    return;
  end if;

  update public.users
  set last_login_at = now(), updated_at = now()
  where id = uid;

  if public.is_stats_excluded(uid) then
    return;
  end if;

  dedup_start := now() - interval '30 minutes';

  if exists (
    select 1
    from public.analytics_events e
    where e.user_id = uid
      and e.event_type = 'app_session'
      and e.created_at >= dedup_start
  ) then
    return;
  end if;

  insert into public.analytics_events (user_id, event_type)
  values (uid, 'app_session');
end;
$$;

revoke all on function public.record_app_session() from public;
grant execute on function public.record_app_session() to authenticated;

-- ═══════════════════════════════════════════════════════════════
-- 1. 실시간 지표: admin_realtime_metrics()
-- ═══════════════════════════════════════════════════════════════
create or replace function public.admin_realtime_metrics()
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  tz constant text := 'Asia/Seoul';
  today_start timestamptz := date_trunc('day', now() at time zone tz) at time zone tz;
  yesterday_start timestamptz := today_start - interval '1 day';
  week_start timestamptz := today_start - interval '6 days';
  month_start30 timestamptz := today_start - interval '29 days';
  lunch_start timestamptz := today_start + interval '11 hours';
  lunch_end timestamptz := today_start + interval '14 hours';
  yesterday_lunch_start timestamptz := yesterday_start + interval '11 hours';
  yesterday_lunch_end timestamptz := yesterday_start + interval '14 hours';

  active_today int;
  active_yesterday int;
  hourly_active jsonb := '[]'::jsonb;
  daily_active_7d jsonb := '[]'::jsonb;
  daily_active_30d jsonb := '[]'::jsonb;
  new_users_today int;
  existing_users_today int;

  lunch_users_today int;
  lunch_users_yesterday int;
  lunch_30min jsonb := '[]'::jsonb;
  lunch_daily_7d jsonb := '[]'::jsonb;
  lunch_daily_30d jsonb := '[]'::jsonb;

  new_signups_today int;
  new_signups_yesterday int;
  daily_signups_7d jsonb := '[]'::jsonb;
  daily_signups_30d jsonb := '[]'::jsonb;
  total_signups int;

  reports_today int;
  reports_yesterday int;
  reports_week int;
  reports_total int;
  hourly_reports jsonb := '[]'::jsonb;
  daily_reports_7d jsonb := '[]'::jsonb;
  daily_reports_30d jsonb := '[]'::jsonb;
  reports_user_today int;
  reports_owner_today int;
  reports_by_level jsonb;
  top_restaurants_by_reports jsonb;

  participants_today int;
  participants_yesterday int;
  daily_participants_7d jsonb := '[]'::jsonb;
  daily_participants_30d jsonb := '[]'::jsonb;
  avg_reports_per_participant numeric;
  dist_1 int;
  dist_2 int;
  dist_3plus int;
  repeat_reporter_rate numeric;

  coverage_restaurants_with_report int;
  coverage_total_restaurants int;
  coverage_rate numeric;
  covered_restaurants jsonb;
  uncovered_restaurants jsonb;

  detail_views_today int;
  detail_views_yesterday int;
  hourly_detail_views jsonb := '[]'::jsonb;
  daily_detail_views_7d jsonb := '[]'::jsonb;
  daily_detail_views_30d jsonb := '[]'::jsonb;
  top_restaurants_by_views jsonb;

  top5_restaurants jsonb;

  i int;
  h_start timestamptz;
  h_end timestamptz;
  d_start timestamptz;
  d_end timestamptz;
  cnt int;
begin
  if auth.uid() is null then
    raise exception 'login required';
  end if;
  if not public.is_admin() then
    raise exception 'admin only';
  end if;

  -- ── 오늘 활성 사용자 ──
  select count(distinct e.user_id)::int into active_today
  from public.analytics_events e
  where e.event_type = 'app_session' and e.user_id is not null
    and e.created_at >= today_start and e.created_at < today_start + interval '1 day';

  select count(distinct e.user_id)::int into active_yesterday
  from public.analytics_events e
  where e.event_type = 'app_session' and e.user_id is not null
    and e.created_at >= yesterday_start and e.created_at < today_start;

  for i in 0..23 loop
    h_start := today_start + (i * interval '1 hour');
    h_end := h_start + interval '1 hour';
    select count(distinct e.user_id)::int into cnt
    from public.analytics_events e
    where e.event_type = 'app_session' and e.user_id is not null
      and e.created_at >= h_start and e.created_at < h_end;
    hourly_active := hourly_active || jsonb_build_array(coalesce(cnt, 0));
  end loop;

  for i in 0..6 loop
    d_start := today_start - ((6 - i) * interval '1 day');
    d_end := d_start + interval '1 day';
    select count(distinct e.user_id)::int into cnt
    from public.analytics_events e
    where e.event_type = 'app_session' and e.user_id is not null
      and e.created_at >= d_start and e.created_at < d_end;
    daily_active_7d := daily_active_7d || jsonb_build_array(coalesce(cnt, 0));
  end loop;

  for i in 0..29 loop
    d_start := today_start - ((29 - i) * interval '1 day');
    d_end := d_start + interval '1 day';
    select count(distinct e.user_id)::int into cnt
    from public.analytics_events e
    where e.event_type = 'app_session' and e.user_id is not null
      and e.created_at >= d_start and e.created_at < d_end;
    daily_active_30d := daily_active_30d || jsonb_build_array(coalesce(cnt, 0));
  end loop;

  select count(distinct e.user_id)::int into new_users_today
  from public.analytics_events e
  join public.users u on u.id = e.user_id
  where e.event_type = 'app_session'
    and e.created_at >= today_start and e.created_at < today_start + interval '1 day'
    and u.created_at >= today_start and u.created_at < today_start + interval '1 day';

  existing_users_today := coalesce(active_today, 0) - coalesce(new_users_today, 0);

  -- ── 점심시간 사용자 (11-14시) ──
  select count(distinct e.user_id)::int into lunch_users_today
  from public.analytics_events e
  where e.event_type = 'app_session' and e.user_id is not null
    and e.created_at >= lunch_start and e.created_at < lunch_end;

  select count(distinct e.user_id)::int into lunch_users_yesterday
  from public.analytics_events e
  where e.event_type = 'app_session' and e.user_id is not null
    and e.created_at >= yesterday_lunch_start and e.created_at < yesterday_lunch_end;

  for i in 0..5 loop
    h_start := lunch_start + (i * interval '30 minutes');
    h_end := h_start + interval '30 minutes';
    select count(distinct e.user_id)::int into cnt
    from public.analytics_events e
    where e.event_type = 'app_session' and e.user_id is not null
      and e.created_at >= h_start and e.created_at < h_end;
    lunch_30min := lunch_30min || jsonb_build_array(coalesce(cnt, 0));
  end loop;

  for i in 0..6 loop
    d_start := today_start - ((6 - i) * interval '1 day') + interval '11 hours';
    d_end := today_start - ((6 - i) * interval '1 day') + interval '14 hours';
    select count(distinct e.user_id)::int into cnt
    from public.analytics_events e
    where e.event_type = 'app_session' and e.user_id is not null
      and e.created_at >= d_start and e.created_at < d_end;
    lunch_daily_7d := lunch_daily_7d || jsonb_build_array(coalesce(cnt, 0));
  end loop;

  for i in 0..29 loop
    d_start := today_start - ((29 - i) * interval '1 day') + interval '11 hours';
    d_end := today_start - ((29 - i) * interval '1 day') + interval '14 hours';
    select count(distinct e.user_id)::int into cnt
    from public.analytics_events e
    where e.event_type = 'app_session' and e.user_id is not null
      and e.created_at >= d_start and e.created_at < d_end;
    lunch_daily_30d := lunch_daily_30d || jsonb_build_array(coalesce(cnt, 0));
  end loop;

  -- ── 신규 가입자 ──
  select count(*)::int into new_signups_today
  from public.users u
  where u.created_at >= today_start and u.created_at < today_start + interval '1 day';

  select count(*)::int into new_signups_yesterday
  from public.users u
  where u.created_at >= yesterday_start and u.created_at < today_start;

  for i in 0..6 loop
    d_start := today_start - ((6 - i) * interval '1 day');
    d_end := d_start + interval '1 day';
    select count(*)::int into cnt from public.users u
    where u.created_at >= d_start and u.created_at < d_end;
    daily_signups_7d := daily_signups_7d || jsonb_build_array(coalesce(cnt, 0));
  end loop;

  for i in 0..29 loop
    d_start := today_start - ((29 - i) * interval '1 day');
    d_end := d_start + interval '1 day';
    select count(*)::int into cnt from public.users u
    where u.created_at >= d_start and u.created_at < d_end;
    daily_signups_30d := daily_signups_30d || jsonb_build_array(coalesce(cnt, 0));
  end loop;

  select count(*)::int into total_signups from public.users;

  -- ── 제보 현황 ──
  select count(*)::int into reports_today from public.crowd_reports cr
  where cr.created_at >= today_start and cr.created_at < today_start + interval '1 day'
    and cr.source in ('user', 'owner') and not public.is_stats_excluded(cr.user_id);

  select count(*)::int into reports_yesterday from public.crowd_reports cr
  where cr.created_at >= yesterday_start and cr.created_at < today_start
    and cr.source in ('user', 'owner') and not public.is_stats_excluded(cr.user_id);

  select count(*)::int into reports_week from public.crowd_reports cr
  where cr.created_at >= week_start and cr.created_at < today_start + interval '1 day'
    and cr.source in ('user', 'owner') and not public.is_stats_excluded(cr.user_id);

  select count(*)::int into reports_total from public.crowd_reports cr
  where cr.source in ('user', 'owner') and not public.is_stats_excluded(cr.user_id);

  for i in 0..23 loop
    h_start := today_start + (i * interval '1 hour');
    h_end := h_start + interval '1 hour';
    select count(*)::int into cnt from public.crowd_reports cr
    where cr.created_at >= h_start and cr.created_at < h_end
      and cr.source in ('user', 'owner') and not public.is_stats_excluded(cr.user_id);
    hourly_reports := hourly_reports || jsonb_build_array(coalesce(cnt, 0));
  end loop;

  for i in 0..6 loop
    d_start := today_start - ((6 - i) * interval '1 day');
    d_end := d_start + interval '1 day';
    select count(*)::int into cnt from public.crowd_reports cr
    where cr.created_at >= d_start and cr.created_at < d_end
      and cr.source in ('user', 'owner') and not public.is_stats_excluded(cr.user_id);
    daily_reports_7d := daily_reports_7d || jsonb_build_array(coalesce(cnt, 0));
  end loop;

  for i in 0..29 loop
    d_start := today_start - ((29 - i) * interval '1 day');
    d_end := d_start + interval '1 day';
    select count(*)::int into cnt from public.crowd_reports cr
    where cr.created_at >= d_start and cr.created_at < d_end
      and cr.source in ('user', 'owner') and not public.is_stats_excluded(cr.user_id);
    daily_reports_30d := daily_reports_30d || jsonb_build_array(coalesce(cnt, 0));
  end loop;

  select count(*)::int into reports_user_today from public.crowd_reports cr
  where cr.created_at >= today_start and cr.created_at < today_start + interval '1 day'
    and cr.source = 'user' and not public.is_stats_excluded(cr.user_id);

  select count(*)::int into reports_owner_today from public.crowd_reports cr
  where cr.created_at >= today_start and cr.created_at < today_start + interval '1 day'
    and cr.source = 'owner' and not public.is_stats_excluded(cr.user_id);

  select coalesce(jsonb_object_agg(t.level_key, t.report_count), '{}'::jsonb) into reports_by_level
  from (
    select cr.level::text as level_key, count(*)::int as report_count
    from public.crowd_reports cr
    where cr.created_at >= today_start and cr.created_at < today_start + interval '1 day'
      and cr.source in ('user', 'owner') and not public.is_stats_excluded(cr.user_id)
    group by cr.level
  ) t;

  select coalesce(jsonb_agg(t.row_data order by t.report_count desc), '[]'::jsonb) into top_restaurants_by_reports
  from (
    select jsonb_build_object(
      'restaurant_id', cr.restaurant_id::text,
      'name', r.name,
      'count', count(*)::int
    ) as row_data, count(*)::int as report_count
    from public.crowd_reports cr
    join public.restaurants r on r.id = cr.restaurant_id
    where cr.created_at >= today_start and cr.created_at < today_start + interval '1 day'
      and cr.source in ('user', 'owner') and not public.is_stats_excluded(cr.user_id)
    group by cr.restaurant_id, r.name
    order by report_count desc
    limit 10
  ) t;

  -- ── 오늘 제보 참여자 ──
  select count(distinct cr.user_id)::int into participants_today from public.crowd_reports cr
  where cr.created_at >= today_start and cr.created_at < today_start + interval '1 day'
    and cr.source in ('user', 'owner') and not public.is_stats_excluded(cr.user_id);

  select count(distinct cr.user_id)::int into participants_yesterday from public.crowd_reports cr
  where cr.created_at >= yesterday_start and cr.created_at < today_start
    and cr.source in ('user', 'owner') and not public.is_stats_excluded(cr.user_id);

  for i in 0..6 loop
    d_start := today_start - ((6 - i) * interval '1 day');
    d_end := d_start + interval '1 day';
    select count(distinct cr.user_id)::int into cnt from public.crowd_reports cr
    where cr.created_at >= d_start and cr.created_at < d_end
      and cr.source in ('user', 'owner') and not public.is_stats_excluded(cr.user_id);
    daily_participants_7d := daily_participants_7d || jsonb_build_array(coalesce(cnt, 0));
  end loop;

  for i in 0..29 loop
    d_start := today_start - ((29 - i) * interval '1 day');
    d_end := d_start + interval '1 day';
    select count(distinct cr.user_id)::int into cnt from public.crowd_reports cr
    where cr.created_at >= d_start and cr.created_at < d_end
      and cr.source in ('user', 'owner') and not public.is_stats_excluded(cr.user_id);
    daily_participants_30d := daily_participants_30d || jsonb_build_array(coalesce(cnt, 0));
  end loop;

  if coalesce(participants_today, 0) > 0 then
    avg_reports_per_participant := round((reports_today::numeric / participants_today), 1);
  else
    avg_reports_per_participant := 0;
  end if;

  select
    count(*) filter (where t.report_count = 1)::int,
    count(*) filter (where t.report_count = 2)::int,
    count(*) filter (where t.report_count >= 3)::int
  into dist_1, dist_2, dist_3plus
  from (
    select cr.user_id, count(*)::int as report_count from public.crowd_reports cr
    where cr.created_at >= today_start and cr.created_at < today_start + interval '1 day'
      and cr.source in ('user', 'owner') and not public.is_stats_excluded(cr.user_id)
    group by cr.user_id
  ) t;

  select
    case when count(*) > 0
      then round((count(*) filter (where repeat_cnt >= 2)::numeric / count(*)) * 100, 1)
      else 0
    end
  into repeat_reporter_rate
  from (
    select cr.user_id, count(*)::int as repeat_cnt from public.crowd_reports cr
    where cr.created_at >= week_start and cr.created_at < today_start + interval '1 day'
      and cr.source in ('user', 'owner') and not public.is_stats_excluded(cr.user_id)
    group by cr.user_id
  ) t;

  -- ── 실시간 혼잡도 커버리지 (최근 15분 이내 제보) ──
  select count(*)::int into coverage_total_restaurants
  from public.restaurants r where r.crowd_enabled;

  select count(distinct cr.restaurant_id)::int into coverage_restaurants_with_report
  from public.crowd_reports cr
  join public.restaurants r on r.id = cr.restaurant_id
  where r.crowd_enabled
    and cr.created_at >= now() - interval '15 minutes'
    and cr.source in ('user', 'owner');

  if coalesce(coverage_total_restaurants, 0) > 0 then
    coverage_rate := round((coverage_restaurants_with_report::numeric / coverage_total_restaurants) * 100, 1);
  else
    coverage_rate := 0;
  end if;

  select coalesce(jsonb_agg(jsonb_build_object(
    'restaurant_id', restaurant_id, 'name', name, 'last_report_at', last_report_at
  ) order by last_report_at desc), '[]'::jsonb)
  into covered_restaurants
  from (
    select r.id::text as restaurant_id, r.name, max(cr.created_at) as last_report_at
    from public.restaurants r
    join public.crowd_reports cr on cr.restaurant_id = r.id
      and cr.created_at >= now() - interval '15 minutes'
      and cr.source in ('user', 'owner')
    where r.crowd_enabled
    group by r.id, r.name
  ) t;

  select coalesce(jsonb_agg(jsonb_build_object(
    'restaurant_id', restaurant_id, 'name', name, 'last_report_at', last_report_at
  ) order by last_report_at desc nulls last), '[]'::jsonb)
  into uncovered_restaurants
  from (
    select r.id::text as restaurant_id, r.name,
      (select max(cr2.created_at) from public.crowd_reports cr2
       where cr2.restaurant_id = r.id and cr2.source in ('user', 'owner')) as last_report_at
    from public.restaurants r
    where r.crowd_enabled
      and not exists (
        select 1 from public.crowd_reports cr
        where cr.restaurant_id = r.id
          and cr.created_at >= now() - interval '15 minutes'
          and cr.source in ('user', 'owner')
      )
  ) t;

  -- ── 오늘 매장 상세 조회 ──
  select count(*)::int into detail_views_today from public.analytics_events e
  where e.event_type = 'detail_view'
    and e.created_at >= today_start and e.created_at < today_start + interval '1 day';

  select count(*)::int into detail_views_yesterday from public.analytics_events e
  where e.event_type = 'detail_view'
    and e.created_at >= yesterday_start and e.created_at < today_start;

  for i in 0..23 loop
    h_start := today_start + (i * interval '1 hour');
    h_end := h_start + interval '1 hour';
    select count(*)::int into cnt from public.analytics_events e
    where e.event_type = 'detail_view' and e.created_at >= h_start and e.created_at < h_end;
    hourly_detail_views := hourly_detail_views || jsonb_build_array(coalesce(cnt, 0));
  end loop;

  for i in 0..6 loop
    d_start := today_start - ((6 - i) * interval '1 day');
    d_end := d_start + interval '1 day';
    select count(*)::int into cnt from public.analytics_events e
    where e.event_type = 'detail_view' and e.created_at >= d_start and e.created_at < d_end;
    daily_detail_views_7d := daily_detail_views_7d || jsonb_build_array(coalesce(cnt, 0));
  end loop;

  for i in 0..29 loop
    d_start := today_start - ((29 - i) * interval '1 day');
    d_end := d_start + interval '1 day';
    select count(*)::int into cnt from public.analytics_events e
    where e.event_type = 'detail_view' and e.created_at >= d_start and e.created_at < d_end;
    daily_detail_views_30d := daily_detail_views_30d || jsonb_build_array(coalesce(cnt, 0));
  end loop;

  select coalesce(jsonb_agg(t.row_data order by t.view_count desc), '[]'::jsonb) into top_restaurants_by_views
  from (
    select jsonb_build_object('restaurant_id', r.id::text, 'name', r.name, 'count', count(*)::int) as row_data,
      count(*)::int as view_count
    from public.analytics_events e
    join public.restaurants r on r.id = e.restaurant_id
    where e.event_type = 'detail_view'
      and e.created_at >= today_start and e.created_at < today_start + interval '1 day'
    group by r.id, r.name
    order by view_count desc
    limit 10
  ) t;

  -- ── 오늘 제보 많은 매장 TOP 10 (혼잡도/마지막제보시각/오늘조회수 포함) ──
  select coalesce(jsonb_agg(row_data order by report_count desc), '[]'::jsonb) into top5_restaurants
  from (
    select jsonb_build_object(
      'restaurant_id', r.id::text,
      'name', r.name,
      'today_reports', coalesce(rc.cnt, 0),
      'week_reports', coalesce(wc.cnt, 0),
      'current_level', cs.level,
      'last_report_at', lr.last_at,
      'today_detail_views', coalesce(dv.cnt, 0)
    ) as row_data,
    coalesce(rc.cnt, 0) as report_count
    from public.restaurants r
    left join lateral (
      select count(*)::int as cnt from public.crowd_reports cr
      where cr.restaurant_id = r.id
        and cr.created_at >= today_start and cr.created_at < today_start + interval '1 day'
        and cr.source in ('user', 'owner') and not public.is_stats_excluded(cr.user_id)
    ) rc on true
    left join lateral (
      select count(*)::int as cnt from public.crowd_reports cr
      where cr.restaurant_id = r.id
        and cr.created_at >= week_start and cr.created_at < today_start + interval '1 day'
        and cr.source in ('user', 'owner') and not public.is_stats_excluded(cr.user_id)
    ) wc on true
    left join lateral (
      select max(cr.created_at) as last_at from public.crowd_reports cr
      where cr.restaurant_id = r.id and cr.source in ('user', 'owner')
    ) lr on true
    left join lateral (
      select count(*)::int as cnt from public.analytics_events e
      where e.restaurant_id = r.id and e.event_type = 'detail_view'
        and e.created_at >= today_start and e.created_at < today_start + interval '1 day'
    ) dv on true
    left join public.crowd_status cs on cs.restaurant_id = r.id
    where r.crowd_enabled
    order by coalesce(rc.cnt, 0) desc
    limit 10
  ) t;

  return jsonb_build_object(
    'active_today', coalesce(active_today, 0),
    'active_yesterday', coalesce(active_yesterday, 0),
    'hourly_active', hourly_active,
    'daily_active_7d', daily_active_7d,
    'daily_active_30d', daily_active_30d,
    'new_users_today', coalesce(new_users_today, 0),
    'existing_users_today', existing_users_today,

    'lunch_users_today', coalesce(lunch_users_today, 0),
    'lunch_users_yesterday', coalesce(lunch_users_yesterday, 0),
    'lunch_30min', lunch_30min,
    'lunch_daily_7d', lunch_daily_7d,
    'lunch_daily_30d', lunch_daily_30d,

    'new_signups_today', coalesce(new_signups_today, 0),
    'new_signups_yesterday', coalesce(new_signups_yesterday, 0),
    'daily_signups_7d', daily_signups_7d,
    'daily_signups_30d', daily_signups_30d,
    'total_signups', coalesce(total_signups, 0),

    'reports_today', coalesce(reports_today, 0),
    'reports_yesterday', coalesce(reports_yesterday, 0),
    'reports_week', coalesce(reports_week, 0),
    'reports_total', coalesce(reports_total, 0),
    'hourly_reports', hourly_reports,
    'daily_reports_7d', daily_reports_7d,
    'daily_reports_30d', daily_reports_30d,
    'reports_user_today', coalesce(reports_user_today, 0),
    'reports_owner_today', coalesce(reports_owner_today, 0),
    'reports_by_level', reports_by_level,
    'top_restaurants_by_reports', top_restaurants_by_reports,

    'participants_today', coalesce(participants_today, 0),
    'participants_yesterday', coalesce(participants_yesterday, 0),
    'daily_participants_7d', daily_participants_7d,
    'daily_participants_30d', daily_participants_30d,
    'avg_reports_per_participant', avg_reports_per_participant,
    'participant_dist_1', coalesce(dist_1, 0),
    'participant_dist_2', coalesce(dist_2, 0),
    'participant_dist_3plus', coalesce(dist_3plus, 0),
    'repeat_reporter_rate', coalesce(repeat_reporter_rate, 0),

    'coverage_rate', coalesce(coverage_rate, 0),
    'coverage_restaurants_with_report', coalesce(coverage_restaurants_with_report, 0),
    'coverage_total_restaurants', coalesce(coverage_total_restaurants, 0),
    'covered_restaurants', covered_restaurants,
    'uncovered_restaurants', uncovered_restaurants,

    'detail_views_today', coalesce(detail_views_today, 0),
    'detail_views_yesterday', coalesce(detail_views_yesterday, 0),
    'hourly_detail_views', hourly_detail_views,
    'daily_detail_views_7d', daily_detail_views_7d,
    'daily_detail_views_30d', daily_detail_views_30d,
    'top_restaurants_by_views', top_restaurants_by_views,

    'top_restaurants_by_reports_full', top5_restaurants
  );
end;
$$;

revoke all on function public.admin_realtime_metrics() from public;
revoke all on function public.admin_realtime_metrics() from anon;
grant execute on function public.admin_realtime_metrics() to authenticated;
