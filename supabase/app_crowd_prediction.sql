-- 앱용 혼잡도 예측 조회 (일반 사용자)
-- Dashboard → SQL Editor 실행 순서:
--   1) crowd_prediction.sql  (집계 본체 crowd_prediction_lunch_core 분리 포함)
--   2) crowd_prediction_relax_probability.sql  (crowd_relax_probability 함수)
--   3) 이 파일
--
-- "지금 시각의 15분 구간"에 대한 매장별 여유로울 확률만 내려준다.
--   - 평일(월~금) KST 11:30 이상 13:00 미만에만 값이 있다. 그 밖에는 빈 결과.
--   - 13:02 는 늦게 올라온 제보를 세는 집계용 값일 뿐 노출 시간이 아니다.
--   - 구간 표본이 3건 미만인 매장은 내려주지 않는다("예측 없음" = 기존 화면 그대로).
--   - 매장 이름, 유저 정보는 내려주지 않는다. 구간 합계와 확률만.
--
-- 섹션 구분은 최빈값(predicted_status)이 아니라 확률 기준이다.
--   70% 이상 → 1 · 40~69% → 2 · 40% 미만 → 3
--   (DB 용어 1=여유로움, 2=약간혼잡, 3=자리없음. 앱 화면 표기 '바로입장'은 앱에서 변환)
--   예) 바로입장 2 + 자리없음 2 → 최빈값은 바로입장이지만 확률은 50% 이므로 약간혼잡.
-- 앱이 70/40 을 따로 들고 있지 않도록 구분 결과(prob_level)까지 서버가 계산한다.
--
-- p_at: 기본값은 현재 시각. 개발 중 시간대 밖에서도 확인할 수 있게 열어 둔 인자이며,
--       집계값(개인정보 없음)만 반환하므로 노출 위험은 없다.

create or replace function public.app_crowd_prediction(p_at timestamptz default now())
returns table (
  restaurant_id uuid,
  slot_start_minute int,   -- 690=11:30 … 765=12:45 (자정 기준 분)
  sample_size int,
  relax_probability int,   -- 여유로울 확률(%)
  prob_level int,          -- 1=여유로움(70%+, 앱 표기 바로입장), 2=약간혼잡(40~69%), 3=자리없음(40% 미만)
  prob_status text         -- level_to_ui_status(prob_level)
)
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_local timestamp := timezone('Asia/Seoul', p_at);
  v_dow int := extract(dow from v_local)::int;
  v_minute int := extract(hour from v_local)::int * 60 + extract(minute from v_local)::int;
  v_slot int;
begin
  -- 노출 시간: 평일 11:30 ≤ 시각 < 13:00
  if v_dow not between 1 and 5 or v_minute < 690 or v_minute >= 780 then
    return;
  end if;

  v_slot := 690 + (v_minute - 690) / 15 * 15;

  return query
  select
    c.restaurant_id,
    c.slot_start_minute,
    c.sample_size,
    pr.prob,
    b.lvl,
    public.level_to_ui_status(b.lvl)
  from public.crowd_prediction_lunch_core() c
  cross join lateral (
    select public.crowd_relax_probability(c.level_1_count, c.level_2_count, c.level_3_count) as prob
  ) pr
  cross join lateral (
    select case when pr.prob >= 70 then 1 when pr.prob >= 40 then 2 else 3 end as lvl
  ) b
  where c.slot_start_minute = v_slot
    and c.sample_size >= 3
    and pr.prob is not null;
end;
$$;

-- anon 은 쓰지 않는다(앱은 로그인 후에만 홈을 본다). Supabase 기본 부여분도 함께 회수.
revoke all on function public.app_crowd_prediction(timestamptz) from public, anon;
grant execute on function public.app_crowd_prediction(timestamptz) to authenticated;

comment on function public.app_crowd_prediction(timestamptz) is
  '앱용 혼잡도 예측: 평일 11:30~13:00(KST) 현재 15분 구간의 매장별 여유로울 확률. 구간 표본 3건 미만 매장은 제외. 개인정보 없음. 집계 기준은 crowd_prediction_lunch_core() 한 곳.';

select 'app_crowd_prediction.sql ok' as status;
