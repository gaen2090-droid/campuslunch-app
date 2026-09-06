-- 운영 성과 탭: 추천 배너 클릭률(매장별 표 포함), 푸시 오픈율(점심 슬롯)
-- analytics_events.sql, push_analytics.sql 실행 후 Dashboard → SQL Editor → Run

create or replace function public.admin_ops_metrics()
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  tz constant text := 'Asia/Seoul';
  today_start timestamptz := date_trunc('day', now() at time zone tz) at time zone tz;
  week_start timestamptz := today_start - interval '6 days';
  prev_week_start timestamptz := today_start - interval '13 days';
  i int;
  d_start timestamptz;
  d_end timestamptz;
  cnt int;
  ctr_day numeric;

  impressions_7d int;
  clicks_7d int;
  ctr_7d numeric;
  impressions_prev_7d int;
  clicks_prev_7d int;
  ctr_prev_7d numeric;
  daily_ctr_7d jsonb := '[]'::jsonb;
  daily_ctr_30d jsonb := '[]'::jsonb;
  by_restaurant jsonb;

  push_delivered_7d int;
  push_clicks_7d int;
  push_open_rate_7d numeric;
  push_delivered_today int;
  push_clicks_today int;
  push_open_rate_today numeric;
  daily_push_7d jsonb := '[]'::jsonb;
  daily_push_30d jsonb := '[]'::jsonb;
  push_day_obj jsonb;

  -- 리워드 현황
  coupons_today int;
  coupons_7d int;
  coupons_total int;
  unique_recipients int;
  coupons_in_stock int;
  daily_coupons_7d jsonb := '[]'::jsonb;
  daily_coupons_30d jsonb := '[]'::jsonb;
  coupons_per_user_dist jsonb;
  stamp_dist jsonb;
begin
  if auth.uid() is null then
    raise exception 'login required';
  end if;
  if not public.is_admin() then
    raise exception 'admin only';
  end if;

  -- ── 추천 배너 CTR (최근 7일) ──
  select count(*)::int into impressions_7d from public.analytics_events e
  where e.event_type = 'banner_impression'
    and e.created_at >= week_start and e.created_at < today_start + interval '1 day';

  select count(*)::int into clicks_7d from public.analytics_events e
  where e.event_type = 'banner_click'
    and e.created_at >= week_start and e.created_at < today_start + interval '1 day';

  if coalesce(impressions_7d, 0) > 0 then
    ctr_7d := round((clicks_7d::numeric / impressions_7d) * 1000) / 10;
  else
    ctr_7d := 0;
  end if;

  select count(*)::int into impressions_prev_7d from public.analytics_events e
  where e.event_type = 'banner_impression'
    and e.created_at >= prev_week_start and e.created_at < week_start;

  select count(*)::int into clicks_prev_7d from public.analytics_events e
  where e.event_type = 'banner_click'
    and e.created_at >= prev_week_start and e.created_at < week_start;

  if coalesce(impressions_prev_7d, 0) > 0 then
    ctr_prev_7d := round((clicks_prev_7d::numeric / impressions_prev_7d) * 1000) / 10;
  else
    ctr_prev_7d := 0;
  end if;

  for i in 0..6 loop
    d_start := today_start - ((6 - i) * interval '1 day');
    d_end := d_start + interval '1 day';
    select case when count(*) filter (where event_type = 'banner_impression') > 0
      then round((count(*) filter (where event_type = 'banner_click')::numeric
        / count(*) filter (where event_type = 'banner_impression')) * 1000) / 10
      else 0 end
    into ctr_day
    from public.analytics_events e
    where e.event_type in ('banner_impression', 'banner_click')
      and e.created_at >= d_start and e.created_at < d_end;
    daily_ctr_7d := daily_ctr_7d || jsonb_build_array(coalesce(ctr_day, 0));
  end loop;

  for i in 0..29 loop
    d_start := today_start - ((29 - i) * interval '1 day');
    d_end := d_start + interval '1 day';
    select case when count(*) filter (where event_type = 'banner_impression') > 0
      then round((count(*) filter (where event_type = 'banner_click')::numeric
        / count(*) filter (where event_type = 'banner_impression')) * 1000) / 10
      else 0 end
    into ctr_day
    from public.analytics_events e
    where e.event_type in ('banner_impression', 'banner_click')
      and e.created_at >= d_start and e.created_at < d_end;
    daily_ctr_30d := daily_ctr_30d || jsonb_build_array(coalesce(ctr_day, 0));
  end loop;

  select coalesce(jsonb_agg(row_data order by ctr desc), '[]'::jsonb) into by_restaurant
  from (
    select jsonb_build_object(
      'restaurant_id', r.id::text,
      'name', r.name,
      'impressions', coalesce(imp.cnt, 0),
      'clicks', coalesce(clk.cnt, 0),
      'ctr', case when coalesce(imp.cnt, 0) > 0
        then round((coalesce(clk.cnt, 0)::numeric / imp.cnt) * 1000) / 10
        else 0 end
    ) as row_data,
    case when coalesce(imp.cnt, 0) > 0
      then round((coalesce(clk.cnt, 0)::numeric / imp.cnt) * 1000) / 10
      else 0 end as ctr
    from public.restaurants r
    left join lateral (
      select count(*)::int as cnt from public.analytics_events e
      where e.event_type = 'banner_impression' and e.restaurant_id = r.id
        and e.created_at >= week_start and e.created_at < today_start + interval '1 day'
    ) imp on true
    left join lateral (
      select count(*)::int as cnt from public.analytics_events e
      where e.event_type = 'banner_click' and e.restaurant_id = r.id
        and e.created_at >= week_start and e.created_at < today_start + interval '1 day'
    ) clk on true
    where coalesce(imp.cnt, 0) > 0
  ) t;

  -- ── 푸시 오픈율 (점심 슬롯 단일) ──
  select count(*)::int into push_delivered_7d from public.analytics_events e
  where e.event_type = 'push_delivered' and e.metadata->>'slot' = 'lunch'
    and e.created_at >= week_start and e.created_at < today_start + interval '1 day';

  select count(*)::int into push_clicks_7d from public.analytics_events e
  where e.event_type = 'push_click' and e.metadata->>'slot' = 'lunch'
    and e.created_at >= week_start and e.created_at < today_start + interval '1 day';

  if coalesce(push_delivered_7d, 0) > 0 then
    push_open_rate_7d := round((push_clicks_7d::numeric / push_delivered_7d) * 1000) / 10;
  else
    push_open_rate_7d := 0;
  end if;

  select count(*)::int into push_delivered_today from public.analytics_events e
  where e.event_type = 'push_delivered' and e.metadata->>'slot' = 'lunch'
    and e.created_at >= today_start and e.created_at < today_start + interval '1 day';

  select count(*)::int into push_clicks_today from public.analytics_events e
  where e.event_type = 'push_click' and e.metadata->>'slot' = 'lunch'
    and e.created_at >= today_start and e.created_at < today_start + interval '1 day';

  if coalesce(push_delivered_today, 0) > 0 then
    push_open_rate_today := round((push_clicks_today::numeric / push_delivered_today) * 1000) / 10;
  else
    push_open_rate_today := 0;
  end if;

  for i in 0..6 loop
    d_start := today_start - ((6 - i) * interval '1 day');
    d_end := d_start + interval '1 day';
    select jsonb_build_object(
      'delivered', count(*) filter (where event_type = 'push_delivered'),
      'clicks', count(*) filter (where event_type = 'push_click')
    ) into push_day_obj
    from public.analytics_events e
    where e.event_type in ('push_delivered', 'push_click') and e.metadata->>'slot' = 'lunch'
      and e.created_at >= d_start and e.created_at < d_end;
    daily_push_7d := daily_push_7d || jsonb_build_array(push_day_obj);
  end loop;

  for i in 0..29 loop
    d_start := today_start - ((29 - i) * interval '1 day');
    d_end := d_start + interval '1 day';
    select jsonb_build_object(
      'delivered', count(*) filter (where event_type = 'push_delivered'),
      'clicks', count(*) filter (where event_type = 'push_click')
    ) into push_day_obj
    from public.analytics_events e
    where e.event_type in ('push_delivered', 'push_click') and e.metadata->>'slot' = 'lunch'
      and e.created_at >= d_start and e.created_at < d_end;
    daily_push_30d := daily_push_30d || jsonb_build_array(push_day_obj);
  end loop;

  -- ── 리워드 현황 (쿠폰 지급, 스탬프 분포) ──
  select count(*)::int into coupons_today from public.gifticons g
  where g.status = 'assigned' and g.assigned_at >= today_start and g.assigned_at < today_start + interval '1 day';

  select count(*)::int into coupons_7d from public.gifticons g
  where g.status = 'assigned' and g.assigned_at >= week_start and g.assigned_at < today_start + interval '1 day';

  select count(*)::int into coupons_total from public.gifticons g
  where g.status = 'assigned';

  select count(distinct g.assigned_user_id)::int into unique_recipients from public.gifticons g
  where g.status = 'assigned' and g.assigned_user_id is not null;

  select count(*)::int into coupons_in_stock from public.gifticons g
  where g.status = 'unassigned';

  for i in 0..6 loop
    d_start := today_start - ((6 - i) * interval '1 day');
    d_end := d_start + interval '1 day';
    select count(*)::int into cnt from public.gifticons g
    where g.status = 'assigned' and g.assigned_at >= d_start and g.assigned_at < d_end;
    daily_coupons_7d := daily_coupons_7d || jsonb_build_array(coalesce(cnt, 0));
  end loop;

  for i in 0..29 loop
    d_start := today_start - ((29 - i) * interval '1 day');
    d_end := d_start + interval '1 day';
    select count(*)::int into cnt from public.gifticons g
    where g.status = 'assigned' and g.assigned_at >= d_start and g.assigned_at < d_end;
    daily_coupons_30d := daily_coupons_30d || jsonb_build_array(coalesce(cnt, 0));
  end loop;

  select coalesce(jsonb_object_agg(t.coupon_count::text, t.user_count), '{}'::jsonb) into coupons_per_user_dist
  from (
    select coupon_count, count(*)::int as user_count
    from (
      select g.assigned_user_id, count(*)::int as coupon_count
      from public.gifticons g
      where g.status = 'assigned' and g.assigned_user_id is not null
      group by g.assigned_user_id
    ) per_user
    group by coupon_count
  ) t;

  select jsonb_build_object(
    '0_9', count(*) filter (where ur.total_stamps between 0 and 9),
    '10_19', count(*) filter (where ur.total_stamps between 10 and 19),
    '20_plus', count(*) filter (where ur.total_stamps >= 20)
  ) into stamp_dist
  from public.user_rewards ur;

  return jsonb_build_object(
    'banner_impressions_7d', coalesce(impressions_7d, 0),
    'banner_clicks_7d', coalesce(clicks_7d, 0),
    'banner_ctr_7d', ctr_7d,
    'banner_ctr_prev_7d', ctr_prev_7d,
    'banner_daily_ctr_7d', daily_ctr_7d,
    'banner_daily_ctr_30d', daily_ctr_30d,
    'banner_by_restaurant', by_restaurant,

    'push_delivered_today', coalesce(push_delivered_today, 0),
    'push_clicks_today', coalesce(push_clicks_today, 0),
    'push_open_rate_today', push_open_rate_today,
    'push_delivered_7d', coalesce(push_delivered_7d, 0),
    'push_clicks_7d', coalesce(push_clicks_7d, 0),
    'push_open_rate_7d', push_open_rate_7d,
    'push_daily_7d', daily_push_7d,
    'push_daily_30d', daily_push_30d,

    'coupons_today', coalesce(coupons_today, 0),
    'coupons_7d', coalesce(coupons_7d, 0),
    'coupons_total', coalesce(coupons_total, 0),
    'unique_recipients', coalesce(unique_recipients, 0),
    'coupons_in_stock', coalesce(coupons_in_stock, 0),
    'daily_coupons_7d', daily_coupons_7d,
    'daily_coupons_30d', daily_coupons_30d,
    'coupons_per_user_dist', coupons_per_user_dist,
    'stamp_dist', stamp_dist
  );
end;
$$;

revoke all on function public.admin_ops_metrics() from public;
revoke all on function public.admin_ops_metrics() from anon;
grant execute on function public.admin_ops_metrics() to authenticated;
