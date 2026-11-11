-- 앱용 매장별 "시간대별 예측" 조회 (상세화면 요약/그래프용)
-- 실행 순서: crowd_prediction.sql → crowd_prediction_relax_probability.sql → app_crowd_prediction.sql → 이 파일
--
-- app_crowd_prediction 은 평일 11:30~13:00 에 "지금 구간"만 내려준다.
-- 이 함수는 시간과 무관하게 한 매장의 11:30~12:45 6개 구간 예측을 모두 내려준다.
-- 점심시간 밖에 상세화면을 연 사용자도 "이 매장은 이 시간대에 이런 예측을 제공하는구나" 를 볼 수 있게 한다.
--   - 구간 표본 3건 미만이면 그 구간은 내려주지 않는다(앱은 빈 칸으로 표시).
--   - 확률/등급 계산은 app_crowd_prediction 과 동일(70%+ → 1, 40~69% → 2, 40% 미만 → 3).
--   - 매장 이름, 유저 정보는 내려주지 않는다. 구간 합계와 확률만.

create or replace function public.app_crowd_prediction_profile(p_restaurant_id uuid)
returns table (
  slot_start_minute int,   -- 690=11:30 … 765=12:45 (자정 기준 분)
  sample_size int,
  relax_probability int,   -- 여유로울 확률(%)
  prob_level int           -- 1=여유로움(70%+, 앱 표기 바로입장), 2=약간혼잡(40~69%), 3=자리없음(40% 미만)
)
language plpgsql
stable
security definer
set search_path = public
as $$
begin
  return query
  select
    c.slot_start_minute,
    c.sample_size,
    pr.prob,
    b.lvl
  from public.crowd_prediction_lunch_core() c
  cross join lateral (
    select public.crowd_relax_probability(c.level_1_count, c.level_2_count, c.level_3_count) as prob
  ) pr
  cross join lateral (
    select case when pr.prob >= 70 then 1 when pr.prob >= 40 then 2 else 3 end as lvl
  ) b
  where c.restaurant_id = p_restaurant_id
    and c.sample_size >= 3
    and pr.prob is not null
  order by c.slot_start_minute;
end;
$$;

revoke all on function public.app_crowd_prediction_profile(uuid) from public, anon;
grant execute on function public.app_crowd_prediction_profile(uuid) to authenticated;

comment on function public.app_crowd_prediction_profile(uuid) is
  '앱용 매장별 시간대별 혼잡도 예측: 11:30~12:45 15분 구간 6개 중 표본 3건 이상인 구간의 여유로울 확률. 시간 제한 없음. 개인정보 없음. 집계 기준은 crowd_prediction_lunch_core() 한 곳.';

select 'app_crowd_prediction_profile.sql ok' as status;
