-- 혼잡도 예측: "여유로울 확률" (바로입장 1.0 · 약간혼잡 0.5 · 자리없음 0 가중)
-- crowd_prediction.sql 실행 후 Dashboard → SQL Editor → Run
--
-- 예전 "자리 있을 확률"은 바로입장과 약간혼잡을 같은 1점으로 합산해서
-- (항상 여유로운 곳) = (늘 약간 붐비는 곳) 이 되는 문제가 있었다.
-- 약간혼잡은 반쯤 여유로운 것으로 보고 0.5점을 준다.
--
--   확률(%) = round( (바로입장 + 0.5 × 약간혼잡 + 1) ÷ (전체 + 2) × 100 )
--   (+1 / +2 는 표본이 적을 때 3/3 → 100% 같은 극단값을 막는 라플라스 보정)
--
-- 앱/어드민이 같은 식을 쓰도록 계산은 이 함수 한 곳에만 둔다.
create or replace function public.crowd_relax_probability(
  p_level_1 int,
  p_level_2 int,
  p_level_3 int
)
returns int
language sql
immutable
as $$
  select case
    when coalesce(p_level_1, 0) + coalesce(p_level_2, 0) + coalesce(p_level_3, 0) <= 0
      then null
    else round(
      (coalesce(p_level_1, 0) + 0.5 * coalesce(p_level_2, 0) + 1)::numeric
      / (coalesce(p_level_1, 0) + coalesce(p_level_2, 0) + coalesce(p_level_3, 0) + 2)
      * 100
    )::int
  end;
$$;

grant execute on function public.crowd_relax_probability(int, int, int) to authenticated;

-- admin_crowd_prediction_lunch() 결과에 relax_probability 를 덧붙인 어드민용 RPC.
-- 원본 함수 본문을 복사하지 않고 그대로 감싸므로 집계 기준(구간·제외 규칙)은 원본을 따른다.
create or replace function public.admin_crowd_prediction_lunch_v2()
returns table (
  restaurant_id uuid,
  restaurant_name varchar,
  slot_start_minute int,
  sample_size int,
  predicted_level int,
  predicted_status text,
  level_1_count int,
  level_2_count int,
  level_3_count int,
  relax_probability int
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
  select
    p.restaurant_id,
    p.restaurant_name,
    p.slot_start_minute,
    p.sample_size,
    p.predicted_level,
    p.predicted_status,
    p.level_1_count,
    p.level_2_count,
    p.level_3_count,
    public.crowd_relax_probability(p.level_1_count, p.level_2_count, p.level_3_count)
  from public.admin_crowd_prediction_lunch() p;
end;
$$;

revoke all on function public.admin_crowd_prediction_lunch_v2() from public;
grant execute on function public.admin_crowd_prediction_lunch_v2() to authenticated;

select 'crowd_prediction_relax_probability.sql ok' as status;
