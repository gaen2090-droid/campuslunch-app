-- 운영 성과 탭: 친구 초대(리퍼럴) 통계 추가
-- 실행 순서: referral_program.sql, referral_cycle_reset.sql, admin_ops_metrics.sql 이후
-- Dashboard → SQL Editor → Run

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

  -- 친구 초대(리퍼럴) 현황
  referrals_today int;
  referrals_7d int;
  referrals_total int;
  unique_referrers int;
  unique_referred int;
  daily_referrals_7d jsonb := '[]'::jsonb;
  daily_referrals_30d jsonb := '[]'::jsonb;
  top_referrers jsonb;
  recent_referrals jsonb;
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

  -- ── 친구 초대(리퍼럴) 현황 ──
  select count(*)::int into referrals_today from public.referrals r
  where r.created_at >= today_start and r.created_at < today_start + interval '1 day';

  select count(*)::int into referrals_7d from public.referrals r
  where r.created_at >= week_start and r.created_at < today_start + interval '1 day';

  select count(*)::int into referrals_total from public.referrals r;

  select count(distinct r.referrer_user_id)::int into unique_referrers from public.referrals r;
  select count(distinct r.referred_user_id)::int into unique_referred from public.referrals r;

  for i in 0..6 loop
    d_start := today_start - ((6 - i) * interval '1 day');
    d_end := d_start + interval '1 day';
    select count(*)::int into cnt from public.referrals r
    where r.created_at >= d_start and r.created_at < d_end;
    daily_referrals_7d := daily_referrals_7d || jsonb_build_array(coalesce(cnt, 0));
  end loop;

  for i in 0..29 loop
    d_start := today_start - ((29 - i) * interval '1 day');
    d_end := d_start + interval '1 day';
    select count(*)::int into cnt from public.referrals r
    where r.created_at >= d_start and r.created_at < d_end;
    daily_referrals_30d := daily_referrals_30d || jsonb_build_array(coalesce(cnt, 0));
  end loop;

  -- 추천인별 누적 성사 건수 랭킹 (어뷰징 감시용, 상위 20명)
  -- + 최근 24시간/7일 내 건수도 함께 보여줘서 "최근에 갑자기 많이 하는" 패턴 확인 가능
  select coalesce(jsonb_agg(row_data order by total_count desc, last_24h_count desc), '[]'::jsonb) into top_referrers
  from (
    select
      jsonb_build_object(
        'user_id', u.id::text,
        'nickname', coalesce(u.nickname, ''),
        'email', coalesce(u.email, ''),
        'total_count', per_user.total_count,
        'last_24h_count', per_user.last_24h_count,
        'last_7d_count', per_user.last_7d_count,
        'last_referred_at', per_user.last_referred_at
      ) as row_data,
      per_user.total_count,
      per_user.last_24h_count
    from (
      select
        r.referrer_user_id,
        count(*)::int as total_count,
        count(*) filter (where r.created_at >= now() - interval '24 hours')::int as last_24h_count,
        count(*) filter (where r.created_at >= now() - interval '7 days')::int as last_7d_count,
        max(r.created_at) as last_referred_at
      from public.referrals r
      group by r.referrer_user_id
    ) per_user
    join public.users u on u.id = per_user.referrer_user_id
    order by per_user.total_count desc, per_user.last_24h_count desc
    limit 20
  ) t;

  -- 최근 성사 이력 (시간순, 최근 50건) - 특정 유저의 초대가 짧은 시간에 몰리는지 육안 확인용
  select coalesce(jsonb_agg(row_data order by created_at desc), '[]'::jsonb) into recent_referrals
  from (
    select
      jsonb_build_object(
        'id', r.id::text,
        'created_at', r.created_at,
        'referrer_user_id', r.referrer_user_id::text,
        'referrer_nickname', coalesce(ru.nickname, ''),
        'referred_user_id', r.referred_user_id::text,
        'referred_nickname', coalesce(du.nickname, '')
      ) as row_data,
      r.created_at
    from public.referrals r
    join public.users ru on ru.id = r.referrer_user_id
    join public.users du on du.id = r.referred_user_id
    order by r.created_at desc
    limit 50
  ) t;

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
    'stamp_dist', stamp_dist,

    'referrals_today', coalesce(referrals_today, 0),
    'referrals_7d', coalesce(referrals_7d, 0),
    'referrals_total', coalesce(referrals_total, 0),
    'unique_referrers', coalesce(unique_referrers, 0),
    'unique_referred', coalesce(unique_referred, 0),
    'daily_referrals_7d', daily_referrals_7d,
    'daily_referrals_30d', daily_referrals_30d,
    'top_referrers', top_referrers,
    'recent_referrals', recent_referrals
  );
end;
$$;

revoke all on function public.admin_ops_metrics() from public;
revoke all on function public.admin_ops_metrics() from anon;
grant execute on function public.admin_ops_metrics() to authenticated;
