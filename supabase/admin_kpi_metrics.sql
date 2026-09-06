-- KPI 탭 지표: 목표 달성률 6종(신규가입자/점심DAU/WAU/제보/일평균참여자/커버리지) +
-- 참고용 누적 스냅샷(누적 제보, 누적 게시글, 매장별 누적 제보)
-- push_analytics.sql(admin_dashboard_metrics), stats_excluded_users.sql,
-- community_phase1.sql, crowd_status.sql 실행 후 Dashboard → SQL Editor → Run

create or replace function public.admin_kpi_metrics()
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  tz constant text := 'Asia/Seoul';
  today_start timestamptz := date_trunc('day', now() at time zone tz) at time zone tz;
  month_start timestamptz := date_trunc('month', now() at time zone tz) at time zone tz;
  prev_month_start timestamptz := date_trunc('month', (now() at time zone tz) - interval '1 month') at time zone tz;
  prev_month_same_point timestamptz;
  days_elapsed_this_month int := (extract(day from (now() at time zone tz))::int);
  month_end timestamptz;
  i int;
  d_start timestamptz;
  d_end timestamptz;
  cnt int;
  total_reports int;
  total_posts int;
  monthly_reports jsonb := '[]'::jsonb;
  monthly_posts jsonb := '[]'::jsonb;
  total_by_restaurant jsonb;

  -- 1. 신규 가입자 (누적형)
  new_users_this_month int;
  new_users_prev_month_same_point int;
  new_users_daily_this_month jsonb := '[]'::jsonb;

  -- 2. 점심시간 일평균 사용자 (평균형)
  lunch_daily_this_month jsonb := '[]'::jsonb;
  lunch_avg_this_month numeric;
  lunch_avg_7d numeric;
  lunch_by_weekday jsonb;
  lunch_30min_avg jsonb := '[]'::jsonb;

  -- 3. WAU (누적형 취급 - 현재 최근 7일 값)
  wau_current int;
  wau_8w jsonb := '[]'::jsonb;
  wau_prev_week int;
  wau_new_ratio numeric;
  wau_existing_ratio numeric;

  -- 4. 제보 건수 (누적형)
  reports_this_month int;
  reports_prev_month_same_point int;
  reports_daily_this_month jsonb := '[]'::jsonb;
  reports_user_month int;
  reports_owner_month int;
  reports_hourly_month jsonb;
  top_restaurants_month jsonb;

  -- 5. 일평균 제보 참여자 (평균형)
  participants_daily_this_month jsonb := '[]'::jsonb;
  participants_avg_this_month numeric;
  participants_avg_7d numeric;
  avg_reports_per_participant_month numeric;
  repeat_rate_7d numeric;

  -- 6. 실시간 혼잡도 커버리지 (평균형, 시점 스냅샷 일자별 근사)
  coverage_daily_this_month jsonb := '[]'::jsonb;
  coverage_avg_this_month numeric;
  coverage_avg_7d numeric;
  coverage_current numeric;
  coverage_total_restaurants int;
  coverage_below_target_days int;
  sparse_restaurants jsonb;

  -- 보조: 활성 사용자 추이 (DAU/WAU/MAU) - 목표 대상 아님
  active_daily_7d jsonb := '[]'::jsonb;
  active_daily_30d jsonb := '[]'::jsonb;
  active_today int;
  active_yesterday int;
  active_avg_7d numeric;
  active_avg_30d numeric;
  active_monthly_6m jsonb := '[]'::jsonb;
  active_month_current int;
  active_month_prev int;
begin
  if auth.uid() is null then
    raise exception 'login required';
  end if;
  if not public.is_admin() then
    raise exception 'admin only';
  end if;

  month_end := month_start + interval '1 month';
  prev_month_same_point := prev_month_start + (days_elapsed_this_month - 1) * interval '1 day';

  -- ── 참고용 누적 스냅샷 (기존 유지, KPI "누적 제보/게시글" 카드가 사용) ──
  for i in 0..5 loop
    d_start := (date_trunc('month', (now() at time zone tz) - ((5 - i) * interval '1 month')) at time zone tz);
    d_end := d_start + interval '1 month';
    select count(*)::int into cnt from public.crowd_reports cr
    where cr.created_at >= d_start and cr.created_at < d_end
      and cr.source in ('user', 'owner') and not public.is_stats_excluded(cr.user_id);
    monthly_reports := monthly_reports || jsonb_build_array(coalesce(cnt, 0));

    select count(*)::int into cnt from public.community_posts cp
    where cp.created_at >= d_start and cp.created_at < d_end;
    monthly_posts := monthly_posts || jsonb_build_array(coalesce(cnt, 0));
  end loop;

  select count(*)::int into total_reports from public.crowd_reports cr
  where cr.source in ('user', 'owner') and not public.is_stats_excluded(cr.user_id);

  select count(*)::int into total_posts from public.community_posts cp;

  select coalesce(jsonb_object_agg(t.restaurant_id, t.report_count), '{}'::jsonb) into total_by_restaurant
  from (
    select cr.restaurant_id::text as restaurant_id, count(*)::int as report_count
    from public.crowd_reports cr
    where cr.source in ('user', 'owner') and not public.is_stats_excluded(cr.user_id)
    group by cr.restaurant_id
  ) t;

  -- ── 1. 신규 가입자 (이번 달 누적) ──
  select count(*)::int into new_users_this_month from public.users u
  where u.created_at >= month_start and u.created_at < today_start + interval '1 day';

  select count(*)::int into new_users_prev_month_same_point from public.users u
  where u.created_at >= prev_month_start and u.created_at < prev_month_same_point;

  for i in 0..(days_elapsed_this_month - 1) loop
    d_start := month_start + (i * interval '1 day');
    d_end := d_start + interval '1 day';
    select count(*)::int into cnt from public.users u
    where u.created_at >= d_start and u.created_at < d_end;
    new_users_daily_this_month := new_users_daily_this_month || jsonb_build_array(coalesce(cnt, 0));
  end loop;

  -- ── 2. 점심시간 일평균 사용자 (11-14시, 이번 달 현재까지 일평균) ──
  for i in 0..(days_elapsed_this_month - 1) loop
    d_start := month_start + (i * interval '1 day') + interval '11 hours';
    d_end := month_start + (i * interval '1 day') + interval '14 hours';
    select count(distinct e.user_id)::int into cnt from public.analytics_events e
    where e.event_type = 'app_session' and e.user_id is not null
      and e.created_at >= d_start and e.created_at < d_end;
    lunch_daily_this_month := lunch_daily_this_month || jsonb_build_array(coalesce(cnt, 0));
  end loop;

  select coalesce(avg(v::numeric), 0) into lunch_avg_this_month
  from jsonb_array_elements_text(lunch_daily_this_month) v;
  lunch_avg_this_month := round(lunch_avg_this_month, 1);

  select coalesce(avg(t.lunch_cnt), 0) into lunch_avg_7d
  from (
    select gs, (
      select count(distinct e.user_id)::int from public.analytics_events e
      where e.event_type = 'app_session' and e.user_id is not null
        and e.created_at >= today_start - (gs * interval '1 day') + interval '11 hours'
        and e.created_at < today_start - (gs * interval '1 day') + interval '14 hours'
    ) as lunch_cnt
    from generate_series(0, 6) gs
  ) t;
  lunch_avg_7d := round(coalesce(lunch_avg_7d, 0), 1);

  select coalesce(jsonb_object_agg(dow::text, avg_cnt), '{}'::jsonb) into lunch_by_weekday
  from (
    select extract(dow from (daily.d_start at time zone tz))::int as dow, round(avg(daily.lunch_cnt), 1) as avg_cnt
    from (
      select
        month_start + (gs * interval '1 day') as d_start,
        (
          select count(distinct e.user_id)::int from public.analytics_events e
          where e.event_type = 'app_session' and e.user_id is not null
            and e.created_at >= month_start + (gs * interval '1 day') + interval '11 hours'
            and e.created_at < month_start + (gs * interval '1 day') + interval '14 hours'
        ) as lunch_cnt
      from generate_series(0, days_elapsed_this_month - 1) gs
    ) daily
    group by dow
  ) t;

  for i in 0..5 loop
    d_start := today_start + interval '11 hours' + (i * interval '30 minutes');
    d_end := d_start + interval '30 minutes';
    select count(distinct e.user_id)::int into cnt from public.analytics_events e
    where e.event_type = 'app_session' and e.user_id is not null
      and e.created_at >= d_start and e.created_at < d_end;
    lunch_30min_avg := lunch_30min_avg || jsonb_build_array(coalesce(cnt, 0));
  end loop;

  -- ── 3. WAU (최근 7일, 8주 추이) ──
  select count(distinct e.user_id)::int into wau_current from public.analytics_events e
  where e.event_type = 'app_session' and e.user_id is not null
    and e.created_at >= today_start - interval '6 days' and e.created_at < today_start + interval '1 day';

  select count(distinct e.user_id)::int into wau_prev_week from public.analytics_events e
  where e.event_type = 'app_session' and e.user_id is not null
    and e.created_at >= today_start - interval '13 days' and e.created_at < today_start - interval '6 days';

  for i in 0..7 loop
    d_end := today_start + interval '1 day' - ((7 - i) * interval '7 days');
    d_start := d_end - interval '7 days';
    select count(distinct e.user_id)::int into cnt from public.analytics_events e
    where e.event_type = 'app_session' and e.user_id is not null
      and e.created_at >= d_start and e.created_at < d_end;
    wau_8w := wau_8w || jsonb_build_array(coalesce(cnt, 0));
  end loop;

  select
    case when count(distinct e.user_id) > 0
      then round((count(distinct e.user_id) filter (where u.created_at >= today_start - interval '6 days'))::numeric
        / count(distinct e.user_id) * 100, 1)
      else 0
    end
  into wau_new_ratio
  from public.analytics_events e
  join public.users u on u.id = e.user_id
  where e.event_type = 'app_session'
    and e.created_at >= today_start - interval '6 days' and e.created_at < today_start + interval '1 day';

  wau_existing_ratio := round(100 - coalesce(wau_new_ratio, 0), 1);

  -- ── 보조: 활성 사용자 추이 (DAU 7/30일, MAU 6개월) ──
  select count(distinct e.user_id)::int into active_today from public.analytics_events e
  where e.event_type = 'app_session' and e.user_id is not null
    and e.created_at >= today_start and e.created_at < today_start + interval '1 day';

  select count(distinct e.user_id)::int into active_yesterday from public.analytics_events e
  where e.event_type = 'app_session' and e.user_id is not null
    and e.created_at >= today_start - interval '1 day' and e.created_at < today_start;

  for i in 0..6 loop
    d_start := today_start - ((6 - i) * interval '1 day');
    d_end := d_start + interval '1 day';
    select count(distinct e.user_id)::int into cnt from public.analytics_events e
    where e.event_type = 'app_session' and e.user_id is not null
      and e.created_at >= d_start and e.created_at < d_end;
    active_daily_7d := active_daily_7d || jsonb_build_array(coalesce(cnt, 0));
  end loop;

  for i in 0..29 loop
    d_start := today_start - ((29 - i) * interval '1 day');
    d_end := d_start + interval '1 day';
    select count(distinct e.user_id)::int into cnt from public.analytics_events e
    where e.event_type = 'app_session' and e.user_id is not null
      and e.created_at >= d_start and e.created_at < d_end;
    active_daily_30d := active_daily_30d || jsonb_build_array(coalesce(cnt, 0));
  end loop;

  select coalesce(avg(v::numeric), 0) into active_avg_7d
  from jsonb_array_elements_text(active_daily_7d) v;
  active_avg_7d := round(active_avg_7d, 1);

  select coalesce(avg(v::numeric), 0) into active_avg_30d
  from jsonb_array_elements_text(active_daily_30d) v;
  active_avg_30d := round(active_avg_30d, 1);

  for i in 0..5 loop
    d_start := (date_trunc('month', (now() at time zone tz) - ((5 - i) * interval '1 month')) at time zone tz);
    d_end := d_start + interval '1 month';
    select count(distinct e.user_id)::int into cnt from public.analytics_events e
    where e.event_type = 'app_session' and e.user_id is not null
      and e.created_at >= d_start and e.created_at < d_end;
    active_monthly_6m := active_monthly_6m || jsonb_build_array(coalesce(cnt, 0));
  end loop;

  select count(distinct e.user_id)::int into active_month_current from public.analytics_events e
  where e.event_type = 'app_session' and e.user_id is not null
    and e.created_at >= today_start - interval '29 days' and e.created_at < today_start + interval '1 day';

  select count(distinct e.user_id)::int into active_month_prev from public.analytics_events e
  where e.event_type = 'app_session' and e.user_id is not null
    and e.created_at >= today_start - interval '59 days' and e.created_at < today_start - interval '29 days';

  -- ── 4. 제보 건수 (이번 달 누적) ──
  select count(*)::int into reports_this_month from public.crowd_reports cr
  where cr.created_at >= month_start and cr.created_at < today_start + interval '1 day'
    and cr.source in ('user', 'owner') and not public.is_stats_excluded(cr.user_id);

  select count(*)::int into reports_prev_month_same_point from public.crowd_reports cr
  where cr.created_at >= prev_month_start and cr.created_at < prev_month_same_point
    and cr.source in ('user', 'owner') and not public.is_stats_excluded(cr.user_id);

  for i in 0..(days_elapsed_this_month - 1) loop
    d_start := month_start + (i * interval '1 day');
    d_end := d_start + interval '1 day';
    select count(*)::int into cnt from public.crowd_reports cr
    where cr.created_at >= d_start and cr.created_at < d_end
      and cr.source in ('user', 'owner') and not public.is_stats_excluded(cr.user_id);
    reports_daily_this_month := reports_daily_this_month || jsonb_build_array(coalesce(cnt, 0));
  end loop;

  select count(*)::int into reports_user_month from public.crowd_reports cr
  where cr.created_at >= month_start and cr.created_at < today_start + interval '1 day'
    and cr.source = 'user' and not public.is_stats_excluded(cr.user_id);

  select count(*)::int into reports_owner_month from public.crowd_reports cr
  where cr.created_at >= month_start and cr.created_at < today_start + interval '1 day'
    and cr.source = 'owner' and not public.is_stats_excluded(cr.user_id);

  select coalesce(jsonb_object_agg(t.h::text, t.report_count), '{}'::jsonb) into reports_hourly_month
  from (
    select extract(hour from (cr.created_at at time zone tz))::int as h, count(*)::int as report_count
    from public.crowd_reports cr
    where cr.created_at >= month_start and cr.created_at < today_start + interval '1 day'
      and cr.source in ('user', 'owner') and not public.is_stats_excluded(cr.user_id)
    group by h
  ) t;

  select coalesce(jsonb_agg(t.row_data order by t.report_count desc), '[]'::jsonb) into top_restaurants_month
  from (
    select jsonb_build_object('restaurant_id', r.id::text, 'name', r.name, 'count', count(*)::int) as row_data,
      count(*)::int as report_count
    from public.crowd_reports cr
    join public.restaurants r on r.id = cr.restaurant_id
    where cr.created_at >= month_start and cr.created_at < today_start + interval '1 day'
      and cr.source in ('user', 'owner') and not public.is_stats_excluded(cr.user_id)
    group by r.id, r.name
    order by report_count desc
    limit 10
  ) t;

  -- ── 5. 일평균 제보 참여자 (이번 달 현재까지 일평균) ──
  for i in 0..(days_elapsed_this_month - 1) loop
    d_start := month_start + (i * interval '1 day');
    d_end := d_start + interval '1 day';
    select count(distinct cr.user_id)::int into cnt from public.crowd_reports cr
    where cr.created_at >= d_start and cr.created_at < d_end
      and cr.source in ('user', 'owner') and not public.is_stats_excluded(cr.user_id);
    participants_daily_this_month := participants_daily_this_month || jsonb_build_array(coalesce(cnt, 0));
  end loop;

  select coalesce(avg(v::numeric), 0) into participants_avg_this_month
  from jsonb_array_elements_text(participants_daily_this_month) v;
  participants_avg_this_month := round(participants_avg_this_month, 1);

  select coalesce(avg(t.participant_cnt), 0) into participants_avg_7d
  from (
    select gs, (
      select count(distinct cr.user_id)::int from public.crowd_reports cr
      where cr.created_at >= today_start - (gs * interval '1 day')
        and cr.created_at < today_start - (gs * interval '1 day') + interval '1 day'
        and cr.source in ('user', 'owner') and not public.is_stats_excluded(cr.user_id)
    ) as participant_cnt
    from generate_series(0, 6) gs
  ) t;
  participants_avg_7d := round(coalesce(participants_avg_7d, 0), 1);

  if coalesce(participants_avg_this_month, 0) > 0 then
    avg_reports_per_participant_month := round(
      (reports_this_month::numeric / nullif(days_elapsed_this_month, 0)) / nullif(participants_avg_this_month, 0), 1
    );
  else
    avg_reports_per_participant_month := 0;
  end if;

  select
    case when count(*) > 0
      then round((count(*) filter (where repeat_cnt >= 2)::numeric / count(*)) * 100, 1)
      else 0
    end
  into repeat_rate_7d
  from (
    select cr.user_id, count(*)::int as repeat_cnt from public.crowd_reports cr
    where cr.created_at >= today_start - interval '6 days' and cr.created_at < today_start + interval '1 day'
      and cr.source in ('user', 'owner') and not public.is_stats_excluded(cr.user_id)
    group by cr.user_id
  ) t;

  -- ── 6. 실시간 혼잡도 커버리지 (이번 달 일별 스냅샷 근사 + 현재값) ──
  select count(*)::int into coverage_total_restaurants from public.restaurants r where r.crowd_enabled;

  if coalesce(coverage_total_restaurants, 0) > 0 then
    select round((count(distinct cr.restaurant_id)::numeric / coverage_total_restaurants) * 100, 1)
    into coverage_current
    from public.crowd_reports cr
    join public.restaurants r on r.id = cr.restaurant_id
    where r.crowd_enabled and cr.created_at >= now() - interval '15 minutes'
      and cr.source in ('user', 'owner');
  else
    coverage_current := 0;
  end if;

  -- 과거 일자의 "15분 이내"는 재현 불가하므로, 일별 근사치로 "그날 최초 제보~마지막 제보 사이 매장 커버 비율"
  -- 대신 각 날짜의 "해당 날짜에 1건이라도 제보된 매장 비율"을 근사값으로 사용(정확한 15분 스냅샷 아님, 추세 참고용).
  if coalesce(coverage_total_restaurants, 0) > 0 then
    for i in 0..(days_elapsed_this_month - 1) loop
      d_start := month_start + (i * interval '1 day');
      d_end := d_start + interval '1 day';
      select count(distinct cr.restaurant_id)::int into cnt
      from public.crowd_reports cr
      join public.restaurants r on r.id = cr.restaurant_id
      where r.crowd_enabled and cr.created_at >= d_start and cr.created_at < d_end
        and cr.source in ('user', 'owner');
      coverage_daily_this_month := coverage_daily_this_month
        || jsonb_build_array(round((coalesce(cnt, 0)::numeric / coverage_total_restaurants) * 100, 1));
    end loop;
  end if;

  select coalesce(avg(v::numeric), 0) into coverage_avg_this_month
  from jsonb_array_elements_text(coverage_daily_this_month) v;
  coverage_avg_this_month := round(coverage_avg_this_month, 1);

  select coalesce(avg(elem::text::numeric), 0) into coverage_avg_7d
  from jsonb_array_elements(coverage_daily_this_month) with ordinality as t(elem, ord)
  where ord > jsonb_array_length(coverage_daily_this_month) - 7;
  coverage_avg_7d := round(coalesce(coverage_avg_7d, 0), 1);

  select coalesce(jsonb_agg(t.row_data order by t.sparse_count asc), '[]'::jsonb) into sparse_restaurants
  from (
    select jsonb_build_object('restaurant_id', r.id::text, 'name', r.name, 'report_count', coalesce(rc.cnt, 0)) as row_data,
      coalesce(rc.cnt, 0) as sparse_count
    from public.restaurants r
    left join lateral (
      select count(*)::int as cnt from public.crowd_reports cr
      where cr.restaurant_id = r.id
        and cr.created_at >= month_start and cr.created_at < today_start + interval '1 day'
        and cr.source in ('user', 'owner')
    ) rc on true
    where r.crowd_enabled
    order by coalesce(rc.cnt, 0) asc
    limit 10
  ) t;

  return jsonb_build_object(
    'total_reports', coalesce(total_reports, 0),
    'total_posts', coalesce(total_posts, 0),
    'monthly_reports', monthly_reports,
    'monthly_posts', monthly_posts,
    'total_by_restaurant', total_by_restaurant,

    'new_users_this_month', coalesce(new_users_this_month, 0),
    'new_users_prev_month_same_point', coalesce(new_users_prev_month_same_point, 0),
    'new_users_daily_this_month', new_users_daily_this_month,
    'total_signups', (select count(*)::int from public.users),

    'lunch_daily_this_month', lunch_daily_this_month,
    'lunch_avg_this_month', lunch_avg_this_month,
    'lunch_avg_7d', lunch_avg_7d,
    'lunch_by_weekday', lunch_by_weekday,
    'lunch_30min_avg', lunch_30min_avg,

    'wau_current', coalesce(wau_current, 0),
    'wau_prev_week', coalesce(wau_prev_week, 0),
    'wau_8w', wau_8w,
    'wau_new_ratio', coalesce(wau_new_ratio, 0),
    'wau_existing_ratio', coalesce(wau_existing_ratio, 0),

    'reports_this_month', coalesce(reports_this_month, 0),
    'reports_prev_month_same_point', coalesce(reports_prev_month_same_point, 0),
    'reports_daily_this_month', reports_daily_this_month,
    'reports_user_month', coalesce(reports_user_month, 0),
    'reports_owner_month', coalesce(reports_owner_month, 0),
    'reports_hourly_month', reports_hourly_month,
    'top_restaurants_month', top_restaurants_month,

    'participants_daily_this_month', participants_daily_this_month,
    'participants_avg_this_month', participants_avg_this_month,
    'participants_avg_7d', participants_avg_7d,
    'avg_reports_per_participant_month', coalesce(avg_reports_per_participant_month, 0),
    'repeat_rate_7d', coalesce(repeat_rate_7d, 0),

    'coverage_daily_this_month', coverage_daily_this_month,
    'coverage_avg_this_month', coverage_avg_this_month,
    'coverage_avg_7d', coverage_avg_7d,
    'coverage_current', coalesce(coverage_current, 0),
    'coverage_total_restaurants', coalesce(coverage_total_restaurants, 0),
    'sparse_restaurants', sparse_restaurants,

    'active_today', coalesce(active_today, 0),
    'active_yesterday', coalesce(active_yesterday, 0),
    'active_daily_7d', active_daily_7d,
    'active_daily_30d', active_daily_30d,
    'active_avg_7d', active_avg_7d,
    'active_avg_30d', active_avg_30d,
    'active_monthly_6m', active_monthly_6m,
    'active_month_current', coalesce(active_month_current, 0),
    'active_month_prev', coalesce(active_month_prev, 0)
  );
end;
$$;

revoke all on function public.admin_kpi_metrics() from public;
revoke all on function public.admin_kpi_metrics() from anon;
grant execute on function public.admin_kpi_metrics() to authenticated;
