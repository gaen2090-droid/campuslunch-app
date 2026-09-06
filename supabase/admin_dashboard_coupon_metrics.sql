-- admin_dashboard_metrics 에 "오늘 쿠폰 제공" 지표 추가
-- (오늘 지급된 기프티콘 수, 최근 7일 일별 지급 추이)
-- push_analytics.sql, rewards.sql 실행 후 Dashboard → SQL Editor → Run

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
  daily_push_open_rates jsonb := '[]'::jsonb;
  daily_gifticon_assigned jsonb := '[]'::jsonb;
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
  push_delivered_today int;
  push_clicks_today int;
  push_open_rate double precision;
  today_reports int;
  week_reports int;
  today_gifticons_assigned int;
  month_gifticons_assigned int;
  gifticon_count int;
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

    select count(*)::int
    into push_delivered_today
    from public.analytics_events e
    where e.event_type = 'push_delivered'
      and e.created_at >= day_start
      and e.created_at < day_end;

    select count(*)::int
    into push_clicks_today
    from public.analytics_events e
    where e.event_type = 'push_click'
      and e.created_at >= day_start
      and e.created_at < day_end;

    if push_delivered_today > 0 then
      push_open_rate := round((push_clicks_today::numeric / push_delivered_today) * 1000) / 10;
    else
      push_open_rate := 0;
    end if;

    daily_push_open_rates := daily_push_open_rates || jsonb_build_array(push_open_rate);

    select count(*)::int
    into gifticon_count
    from public.gifticons g
    where g.status = 'assigned'
      and g.assigned_at >= day_start
      and g.assigned_at < day_end;

    daily_gifticon_assigned := daily_gifticon_assigned || jsonb_build_array(coalesce(gifticon_count, 0));
  end loop;

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

  select count(*)::int into push_delivered_today
  from public.analytics_events e
  where e.event_type = 'push_delivered'
    and e.created_at >= today_start
    and e.created_at < today_start + interval '1 day';

  select count(*)::int into push_clicks_today
  from public.analytics_events e
  where e.event_type = 'push_click'
    and e.created_at >= today_start
    and e.created_at < today_start + interval '1 day';

  if push_delivered_today > 0 then
    push_open_rate := round((push_clicks_today::numeric / push_delivered_today) * 1000) / 10;
  else
    push_open_rate := 0;
  end if;

  select count(*)::int into today_reports
  from public.crowd_reports cr
  where cr.created_at >= today_start
    and cr.created_at < today_start + interval '1 day'
    and cr.source in ('user', 'owner')
    and not public.is_stats_excluded(cr.user_id);

  select count(*)::int into week_reports
  from public.crowd_reports cr
  where cr.created_at >= week_start
    and cr.created_at < today_start + interval '1 day'
    and cr.source in ('user', 'owner')
    and not public.is_stats_excluded(cr.user_id);

  select count(*)::int into today_gifticons_assigned
  from public.gifticons g
  where g.status = 'assigned'
    and g.assigned_at >= today_start
    and g.assigned_at < today_start + interval '1 day';

  select count(*)::int into month_gifticons_assigned
  from public.gifticons g
  where g.status = 'assigned'
    and g.assigned_at >= date_trunc('month', now() at time zone tz) at time zone tz
    and g.assigned_at < today_start + interval '1 day';

  select coalesce(jsonb_agg(jsonb_build_array(nickname, cnt)), '[]'::jsonb)
  into top_reporters
  from (
    select
      coalesce(cr.metadata->>'nickname', '익명') as nickname,
      count(*)::int as cnt
    from public.crowd_reports cr
    where cr.created_at >= today_start
      and cr.created_at < today_start + interval '1 day'
      and cr.source = 'user'
      and not public.is_stats_excluded(cr.user_id)
    group by 1
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
      and not public.is_stats_excluded(cr.user_id)
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
      and not public.is_stats_excluded(cr.user_id)
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
    'push_open_rate', push_open_rate,
    'daily_push_open_rates', daily_push_open_rates,
    'today_gifticons_assigned', coalesce(today_gifticons_assigned, 0),
    'daily_gifticons_assigned', daily_gifticon_assigned,
    'month_gifticons_assigned', coalesce(month_gifticons_assigned, 0),
    'top_reporters', top_reporters,
    'today_by_restaurant', today_by_restaurant,
    'week_by_restaurant', week_by_restaurant
  );
end;
$$;

revoke all on function public.admin_dashboard_metrics() from public;
revoke all on function public.admin_dashboard_metrics() from anon;
grant execute on function public.admin_dashboard_metrics() to authenticated;
