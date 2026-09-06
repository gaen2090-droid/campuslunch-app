-- 지표 내보내기(엑셀)의 날짜 필터를 실제로 반영하기 위한 range 기반 RPC 2종.
-- admin_realtime_metrics/admin_kpi_metrics/admin_ops_metrics는 "오늘/최근N일/이번달" 고정 계산이라
-- 사용자가 고른 임의 기간(startDate~endDate)을 지원하지 못함. 이 두 함수가 그 gap을 메운다.
--
-- admin_export_daily_metrics: 날짜별 1행 (활성사용자/점심시간사용자/제보/제보참여자/상세조회/배너/푸시)
-- admin_export_restaurant_metrics: 매장별 1행 (기간 내 레벨별 제보수, 제보참여자수, 상세조회수)
--
-- 참고 (엑셀 시트 meta에도 표기할 것):
--  - app_session은 2026-09-05 배포로 "하루 1건"에서 "30분 dedup"으로 바뀜.
--    그 이전 날짜는 유저당 최대 1세션만 잡혀서 활성사용자 수가 과소집계될 수 있음.
--  - crowd_reports.level(crowd_level enum)은 저장 단계(ui_level_to_crowd_level)에서
--    "약간혼잡"과 "자리없음"이 둘 다 full로 합쳐진다 (normal만 구분 가능).
--    레벨별 세부 구분이 필요하면 원본 한글이 남아있는 crowd_reports.metadata->>'status'
--    ('여유로움'/'약간혼잡'/'자리없음')를 써야 한다.
--  - 모든 날짜 경계는 KST(Asia/Seoul) 기준으로 계산한다 (DB 세션 타임존이 UTC이므로
--    created_at을 그대로 ::date 비교하면 안 되고 at time zone 'Asia/Seoul'로 변환 후 비교).

drop function if exists public.admin_export_daily_metrics(date, date);
create or replace function public.admin_export_daily_metrics(p_start date, p_end date)
returns table (
  day date,
  active_users int,
  lunch_users int,
  new_signups int,
  reports int,
  report_participants int,
  detail_views int,
  banner_impressions int,
  banner_clicks int,
  push_delivered int,
  push_clicks int
)
language plpgsql
security definer
set search_path = public
as $$
begin
  if not is_admin() then
    raise exception 'forbidden';
  end if;

  return query
  select
    gs::date as day,
    (
      select count(distinct ae.user_id)::int
      from analytics_events ae
      where ae.event_type = 'app_session'
        and (ae.created_at at time zone 'Asia/Seoul')::date = gs::date
        and not is_stats_excluded(ae.user_id)
    ) as active_users,
    (
      select count(distinct ae.user_id)::int
      from analytics_events ae
      where ae.event_type = 'app_session'
        and (ae.created_at at time zone 'Asia/Seoul')::date = gs::date
        and extract(hour from ae.created_at at time zone 'Asia/Seoul') between 11 and 13
        and not is_stats_excluded(ae.user_id)
    ) as lunch_users,
    (
      select count(*)::int
      from auth.users u
      where (u.created_at at time zone 'Asia/Seoul')::date = gs::date
        and not is_stats_excluded(u.id)
    ) as new_signups,
    (
      select count(*)::int
      from crowd_reports cr
      where (cr.created_at at time zone 'Asia/Seoul')::date = gs::date
        and not is_stats_excluded(cr.user_id)
    ) as reports,
    (
      select count(distinct cr.user_id)::int
      from crowd_reports cr
      where (cr.created_at at time zone 'Asia/Seoul')::date = gs::date
        and not is_stats_excluded(cr.user_id)
    ) as report_participants,
    (
      select count(*)::int
      from analytics_events ae
      where ae.event_type = 'detail_view'
        and (ae.created_at at time zone 'Asia/Seoul')::date = gs::date
        and not is_stats_excluded(ae.user_id)
    ) as detail_views,
    (
      select count(*)::int
      from analytics_events ae
      where ae.event_type = 'banner_impression'
        and (ae.created_at at time zone 'Asia/Seoul')::date = gs::date
        and not is_stats_excluded(ae.user_id)
    ) as banner_impressions,
    (
      select count(*)::int
      from analytics_events ae
      where ae.event_type = 'banner_click'
        and (ae.created_at at time zone 'Asia/Seoul')::date = gs::date
        and not is_stats_excluded(ae.user_id)
    ) as banner_clicks,
    (
      select count(*)::int
      from analytics_events ae
      where ae.event_type = 'push_delivered'
        and (ae.created_at at time zone 'Asia/Seoul')::date = gs::date
        and ae.metadata->>'slot' = 'lunch'
        and not is_stats_excluded(ae.user_id)
    ) as push_delivered,
    (
      select count(*)::int
      from analytics_events ae
      where ae.event_type = 'push_click'
        and (ae.created_at at time zone 'Asia/Seoul')::date = gs::date
        and ae.metadata->>'slot' = 'lunch'
        and not is_stats_excluded(ae.user_id)
    ) as push_clicks
  from generate_series(p_start, p_end, interval '1 day') gs
  order by gs;
end;
$$;

revoke all on function public.admin_export_daily_metrics(date, date) from public;
revoke all on function public.admin_export_daily_metrics(date, date) from anon;
grant execute on function public.admin_export_daily_metrics(date, date) to authenticated;


drop function if exists public.admin_export_restaurant_metrics(date, date);
create or replace function public.admin_export_restaurant_metrics(p_start date, p_end date)
returns table (
  restaurant_id uuid,
  name varchar,
  area text,
  category text,
  owner_registered boolean,
  reports_relaxed int,
  reports_moderate int,
  reports_full int,
  reports_total int,
  report_participants int,
  detail_views int
)
language plpgsql
security definer
set search_path = public
as $$
begin
  if not is_admin() then
    raise exception 'forbidden';
  end if;

  return query
  select
    r.id as restaurant_id,
    r.name,
    r.area::text,
    r.category::text,
    (r.owner_id is not null) as owner_registered,
    coalesce((
      select count(*)::int from crowd_reports cr
      where cr.restaurant_id = r.id and cr.metadata->>'status' = '여유로움'
        and (cr.created_at at time zone 'Asia/Seoul')::date between p_start and p_end
        and not is_stats_excluded(cr.user_id)
    ), 0) as reports_relaxed,
    coalesce((
      select count(*)::int from crowd_reports cr
      where cr.restaurant_id = r.id and cr.metadata->>'status' = '약간혼잡'
        and (cr.created_at at time zone 'Asia/Seoul')::date between p_start and p_end
        and not is_stats_excluded(cr.user_id)
    ), 0) as reports_moderate,
    coalesce((
      select count(*)::int from crowd_reports cr
      where cr.restaurant_id = r.id and cr.metadata->>'status' = '자리없음'
        and (cr.created_at at time zone 'Asia/Seoul')::date between p_start and p_end
        and not is_stats_excluded(cr.user_id)
    ), 0) as reports_full,
    coalesce((
      select count(*)::int from crowd_reports cr
      where cr.restaurant_id = r.id
        and (cr.created_at at time zone 'Asia/Seoul')::date between p_start and p_end
        and not is_stats_excluded(cr.user_id)
    ), 0) as reports_total,
    coalesce((
      select count(distinct cr.user_id)::int from crowd_reports cr
      where cr.restaurant_id = r.id
        and (cr.created_at at time zone 'Asia/Seoul')::date between p_start and p_end
        and not is_stats_excluded(cr.user_id)
    ), 0) as report_participants,
    coalesce((
      select count(*)::int from analytics_events ae
      where ae.event_type = 'detail_view' and ae.restaurant_id = r.id
        and (ae.created_at at time zone 'Asia/Seoul')::date between p_start and p_end
        and not is_stats_excluded(ae.user_id)
    ), 0) as detail_views
  from restaurants r
  where r.crowd_enabled
  order by r.area, r.name;
end;
$$;

revoke all on function public.admin_export_restaurant_metrics(date, date) from public;
revoke all on function public.admin_export_restaurant_metrics(date, date) from anon;
grant execute on function public.admin_export_restaurant_metrics(date, date) to authenticated;


-- 옛 "시간대 분석" 시트는 실제로는 일자별 행이었고 스스로 "시간대 raw 미연동"이라고
-- 밝혀둔 상태였음. analytics_events.created_at으로 진짜 시간대(0~23시) 버킷을 만든다.
drop function if exists public.admin_export_hourly_metrics(date, date);
create or replace function public.admin_export_hourly_metrics(p_start date, p_end date)
returns table (
  day date,
  hour int,
  active_users int,
  reports int,
  detail_views int
)
language plpgsql
security definer
set search_path = public
as $$
begin
  if not is_admin() then
    raise exception 'forbidden';
  end if;

  return query
  select
    d::date as day,
    h as hour,
    (
      select count(distinct ae.user_id)::int
      from analytics_events ae
      where ae.event_type = 'app_session'
        and (ae.created_at at time zone 'Asia/Seoul')::date = d::date
        and extract(hour from ae.created_at at time zone 'Asia/Seoul')::int = h
        and not is_stats_excluded(ae.user_id)
    ) as active_users,
    (
      select count(*)::int
      from crowd_reports cr
      where (cr.created_at at time zone 'Asia/Seoul')::date = d::date
        and extract(hour from cr.created_at at time zone 'Asia/Seoul')::int = h
        and not is_stats_excluded(cr.user_id)
    ) as reports,
    (
      select count(*)::int
      from analytics_events ae
      where ae.event_type = 'detail_view'
        and (ae.created_at at time zone 'Asia/Seoul')::date = d::date
        and extract(hour from ae.created_at at time zone 'Asia/Seoul')::int = h
        and not is_stats_excluded(ae.user_id)
    ) as detail_views
  from generate_series(p_start, p_end, interval '1 day') d
  cross join generate_series(0, 23) h
  order by d, h;
end;
$$;

revoke all on function public.admin_export_hourly_metrics(date, date) from public;
revoke all on function public.admin_export_hourly_metrics(date, date) from anon;
grant execute on function public.admin_export_hourly_metrics(date, date) to authenticated;
