-- 구글 영업시간(hours_periods)에서 정기 휴무 요일을 읽어 description.closed_days 에 채워 넣는다.
-- Dashboard → SQL Editor 에서 실행. (1) 미리보기 → (2) 적용 순서로 한 단계씩.
--
-- 배경: 구글 영업시간에 "수요일: 휴무일"처럼 없는 요일은 hours_periods 에 구간이 없다.
-- 앱은 이미 이 구간으로 영업 여부를 판단하므로 영업 결과는 달라지지 않는다.
-- 다만 어드민 "정기 휴무"에 표시되고, 영업시간을 어드민에서 직접 고쳐 hours_periods 가
-- 지워져도 휴무 요일이 유지된다.
--
-- 규칙
--  * 요일 번호: 월=1 … 일=7 (구글 day 0=일 → 7)
--  * 이미 closed_days 가 있는 매장은 건드리지 않는다.
--  * 24시간 영업(구간 1개, close 없음)과 7일 모두 영업은 제외한다.
--  * 공휴일 휴무(closed_on_holidays)는 구글/카카오 데이터에 없어서 채우지 않는다.

-- ── (1) 미리보기: 어떤 매장이 어떤 요일에 쉬는 걸로 계산되는지 ──
with src as (
  select
    r.id,
    r.name,
    r.description::jsonb as j
  from public.restaurants r
  where r.is_active
    and r.description ~ '^\s*\{'
),
calc as (
  select
    s.id,
    s.name,
    (
      select array_agg(g order by g)
      from (
        select case when x = 0 then 7 else x end as g
        from generate_series(0, 6) x
        where not exists (
          select 1
          from jsonb_array_elements(s.j -> 'hours_periods') p
          where (p -> 'open' ->> 'day')::int = x
        )
      ) t
    ) as missing,
    jsonb_array_length(s.j -> 'hours_periods') as n_periods,
    jsonb_typeof(s.j -> 'hours_periods' -> 0 -> 'close') is distinct from 'object' as first_has_no_close
  from src s
  where jsonb_typeof(s.j -> 'hours_periods') = 'array'
    and jsonb_array_length(s.j -> 'hours_periods') > 0
    and not (s.j ? 'closed_days')
)
select id, name, missing
from calc
where coalesce(array_length(missing, 1), 0) between 1 and 6
  and not (n_periods = 1 and first_has_no_close)
order by name;

-- ── (2) 적용: 위 미리보기 결과와 같은 매장에 closed_days 를 채운다 ──
-- 미리보기를 확인한 뒤 아래 블록의 주석(/* */)을 풀고 실행.
/*
with src as (
  select r.id, r.description::jsonb as j
  from public.restaurants r
  where r.is_active and r.description ~ '^\s*\{'
),
calc as (
  select
    s.id,
    s.j,
    (
      select array_agg(g order by g)
      from (
        select case when x = 0 then 7 else x end as g
        from generate_series(0, 6) x
        where not exists (
          select 1
          from jsonb_array_elements(s.j -> 'hours_periods') p
          where (p -> 'open' ->> 'day')::int = x
        )
      ) t
    ) as missing,
    jsonb_array_length(s.j -> 'hours_periods') as n_periods,
    jsonb_typeof(s.j -> 'hours_periods' -> 0 -> 'close') is distinct from 'object' as first_has_no_close
  from src s
  where jsonb_typeof(s.j -> 'hours_periods') = 'array'
    and jsonb_array_length(s.j -> 'hours_periods') > 0
    and not (s.j ? 'closed_days')
)
update public.restaurants r
set description = jsonb_set(c.j, '{closed_days}', to_jsonb(c.missing))::text
from calc c
where r.id = c.id
  and coalesce(array_length(c.missing, 1), 0) between 1 and 6
  and not (c.n_periods = 1 and c.first_has_no_close);
*/
