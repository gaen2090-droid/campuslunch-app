-- 혼잡도 AI 예측 (admin-web 전용, 1단계)
-- Dashboard → SQL Editor: stats_excluded_users.sql 이후 실행
-- (is_stats_excluded() 함수가 있어야 함)
--
-- 점심시간(12:00~13:00, KST) 제보를 15분 단위 4개 구간으로 모아 매장별
-- 대표 혼잡도(최빈값)를 계산하는 관리자 전용 RPC. 머신러닝이 아니라 통계
-- 집계이며, "AI 예측"은 admin-web UI 라벨일 뿐이다.
--
-- 대상: restaurants.crowd_enabled=true (제보 대상 매장)만
-- 제외: 통계 제외 유저(is_stats_excluded) — 단, campuslunch2026@gmail.com
--       ("청룡의 아들", 관리자 제보 전용 계정)은 지금 표본이 적은 초기
--       단계라 예외적으로 포함한다. 다른 통계 제외 계정은 그대로 제외.
--       그 외: '영업안함' 제보, 주말(토/일) 제보
-- 중복 처리: 같은 유저가 같은 매장·같은 15분 구간·같은 날짜에 여러 번
--            제보해도 그 날 그 구간엔 최신 1건만 반영 (헤비 제보자 방지)
-- 최소 표본: 구간당 유효 제보 3건 미만이면 sample_size만 채우고
--            predicted_level/predicted_status는 null ("데이터 부족")

create or replace function public.admin_crowd_prediction_lunch()
returns table (
  restaurant_id uuid,
  restaurant_name varchar,
  slot_start_minute int,   -- 720=12:00, 735=12:15, 750=12:30, 765=12:45 (자정 기준 분)
  sample_size int,
  predicted_level int,     -- 1=여유로움, 2=약간혼잡, 3=자리없음 (표본 부족 시 null)
  predicted_status text,   -- level_to_ui_status(predicted_level) (표본 부족 시 null)
  level_1_count int,
  level_2_count int,
  level_3_count int
)
language plpgsql
stable
security definer
set search_path = public
as $$
begin
  if not public.is_admin() then
    raise exception 'admin only';
  end if;

  return query
  with local_reports as (
    -- KST 로컬시각 기준 요일/시각으로 필터링 + 매장별 유저별 15분 구간별
    -- 최신 제보 1건만 남긴다.
    select distinct on (cr.restaurant_id, r_local.slot_start_minute, cr.user_id)
      cr.restaurant_id,
      r_local.slot_start_minute,
      public.report_row_level(cr.metadata, cr.level::text) as report_level,
      cr.created_at
    from public.crowd_reports cr
    join public.users u on u.id = cr.user_id
    cross join lateral (
      select
        (extract(dow from timezone('Asia/Seoul', cr.created_at))::int) as dow,
        (extract(hour from timezone('Asia/Seoul', cr.created_at))::int * 60
          + extract(minute from timezone('Asia/Seoul', cr.created_at))::int
          / 15 * 15) as slot_start_minute
    ) r_local
    where r_local.dow between 1 and 5  -- 평일(월=1~금=5)만
      and r_local.slot_start_minute in (720, 735, 750, 765)  -- 12:00~13:00, 15분 단위
      and coalesce(nullif(trim(cr.metadata->>'status'), ''), '') <> '영업안함'
      and (
        not public.is_stats_excluded(cr.user_id)
        or lower(u.email) = 'campuslunch2026@gmail.com'
      )
    order by cr.restaurant_id, r_local.slot_start_minute, cr.user_id, cr.created_at desc
  ),
  slots as (
    select unnest(array[720, 735, 750, 765]) as slot_start_minute
  ),
  targets as (
    select r.id as restaurant_id, r.name as restaurant_name
    from public.restaurants r
    where r.crowd_enabled = true
  ),
  grid as (
    select t.restaurant_id, t.restaurant_name, s.slot_start_minute
    from targets t
    cross join slots s
  ),
  agg as (
    select
      lr.restaurant_id,
      lr.slot_start_minute,
      count(*) as sample_size,
      count(*) filter (where lr.report_level = 1) as level_1_count,
      count(*) filter (where lr.report_level = 2) as level_2_count,
      count(*) filter (where lr.report_level = 3) as level_3_count
    from local_reports lr
    group by lr.restaurant_id, lr.slot_start_minute
  )
  select
    g.restaurant_id,
    g.restaurant_name,
    g.slot_start_minute,
    coalesce(a.sample_size, 0)::int as sample_size,
    case
      when coalesce(a.sample_size, 0) < 3 then null
      else (
        select lvl
        from (values (1, a.level_1_count), (2, a.level_2_count), (3, a.level_3_count)) as v(lvl, cnt)
        order by v.cnt desc, v.lvl asc
        limit 1
      )
    end as predicted_level,
    case
      when coalesce(a.sample_size, 0) < 3 then null
      else public.level_to_ui_status((
        select lvl
        from (values (1, a.level_1_count), (2, a.level_2_count), (3, a.level_3_count)) as v(lvl, cnt)
        order by v.cnt desc, v.lvl asc
        limit 1
      ))
    end as predicted_status,
    coalesce(a.level_1_count, 0)::int as level_1_count,
    coalesce(a.level_2_count, 0)::int as level_2_count,
    coalesce(a.level_3_count, 0)::int as level_3_count
  from grid g
  left join agg a
    on a.restaurant_id = g.restaurant_id
    and a.slot_start_minute = g.slot_start_minute
  order by g.restaurant_name, g.slot_start_minute;
end;
$$;

revoke all on function public.admin_crowd_prediction_lunch() from public;
grant execute on function public.admin_crowd_prediction_lunch() to authenticated;

comment on function public.admin_crowd_prediction_lunch() is
  '점심(12~13시, 평일, KST) 15분 단위 매장별 대표 혼잡도 통계 집계. admin-web "혼잡도 AI 예측" 탭 전용. 구간당 표본 3건 미만이면 predicted_level/status=null. campuslunch2026@gmail.com(관리자 제보 전용)은 통계 제외 예외로 포함.';

-- ── 표본 추적: 최근 7일 일별 유효 제보 수 ──
-- admin_crowd_prediction_lunch()와 동일한 필터(평일·12~13시·영업안함 제외·
-- 청룡의 아들 계정 예외 포함, 매장·구간·유저 중복은 최신 1건)를 쓰되,
-- 매장/구간으로 나누지 않고 날짜별 총합만 낸다 — "하루에 얼마나 쌓이는지"
-- 증가 속도 추정용. 표본 추적 카드(admin-web "혼잡도 AI 예측" 상단)에서 사용.
create or replace function public.admin_crowd_prediction_daily_counts(p_days int default 7)
returns table (
  report_date date,
  valid_report_count int
)
language plpgsql
stable
security definer
set search_path = public
as $$
begin
  if not public.is_admin() then
    raise exception 'admin only';
  end if;

  return query
  with local_reports as (
    select distinct on (cr.restaurant_id, r_local.slot_start_minute, cr.user_id, r_local.report_date)
      cr.restaurant_id,
      r_local.slot_start_minute,
      r_local.report_date,
      cr.created_at
    from public.crowd_reports cr
    join public.users u on u.id = cr.user_id
    cross join lateral (
      select
        (extract(dow from timezone('Asia/Seoul', cr.created_at))::int) as dow,
        (timezone('Asia/Seoul', cr.created_at))::date as report_date,
        (extract(hour from timezone('Asia/Seoul', cr.created_at))::int * 60
          + extract(minute from timezone('Asia/Seoul', cr.created_at))::int
          / 15 * 15) as slot_start_minute
    ) r_local
    where r_local.dow between 1 and 5
      and r_local.slot_start_minute in (720, 735, 750, 765)
      and r_local.report_date >= (timezone('Asia/Seoul', now()))::date - (greatest(1, p_days) - 1)
      and coalesce(nullif(trim(cr.metadata->>'status'), ''), '') <> '영업안함'
      and (
        not public.is_stats_excluded(cr.user_id)
        or lower(u.email) = 'campuslunch2026@gmail.com'
      )
    order by cr.restaurant_id, r_local.slot_start_minute, cr.user_id, r_local.report_date, cr.created_at desc
  )
  select lr.report_date, count(*)::int as valid_report_count
  from local_reports lr
  group by lr.report_date
  order by lr.report_date;
end;
$$;

revoke all on function public.admin_crowd_prediction_daily_counts(int) from public;
grant execute on function public.admin_crowd_prediction_daily_counts(int) to authenticated;

comment on function public.admin_crowd_prediction_daily_counts(int) is
  '최근 N일(기본 7일) 평일 점심(12~13시) 유효 제보 수를 날짜별로 집계. admin_crowd_prediction_lunch()와 동일 필터. 표본 추적(증가 속도 추정)용.';

select 'crowd_prediction.sql ok' as status;
