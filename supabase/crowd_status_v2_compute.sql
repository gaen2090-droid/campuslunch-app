-- 혼잡도 계산 — 대표 status는 항상 "가장 최신 제보"를 그대로 반영한다.
-- 다수결/일치도는 confidence 산정에만 쓰이고, status 결정에는 쓰이지 않는다.
-- crowd_status.sql 실행 직후 Run

-- 옛 버전(댐핑·클램프) 함수 제거 — 더 이상 사용하지 않음
drop function if exists public.crowd_move_one_step(int, int);
drop function if exists public.crowd_clamp_step(int, int, boolean);

-- crowd_status에 범용 "updated_at 자동 now() 갱신" 트리거가 걸려있으면 안 됨.
-- recalculate_crowd_status가 "실제로 상태가 바뀐 시점만" updated_at을 갱신하도록 직접 관리하므로,
-- 그런 트리거가 있으면 제보 없는 매장도 재계산할 때마다 updated_at이 무조건 now()로 덮어써져서
-- "모든 매장의 업데이트 시간이 동일하게 표시"되는 버그가 발생한다. (실제로 한 번 발생했음)
drop trigger if exists trg_crowd_status_updated_at on public.crowd_status;

create or replace function public.crowd_dominant_stats(p_levels int[])
returns table(dominant_level int, dominant_cnt int, dominant_ratio numeric, total_cnt int)
language sql
immutable
as $$
  with counts as (
    select u.level, count(*)::int as cnt
    from unnest(p_levels) as u(level)
    group by u.level
  ),
  top as (
    select level, cnt
    from counts
    order by cnt desc, level desc
    limit 1
  )
  select
    t.level,
    t.cnt,
    t.cnt::numeric / greatest((select sum(cnt) from counts), 1),
    (select sum(cnt) from counts)
  from top t;
$$;

create or replace function public.crowd_is_split(p_levels int[])
returns boolean
language sql
immutable
as $$
  with counts as (
    select count(*)::int as cnt
    from unnest(p_levels) as u(level)
    group by level
  ),
  mx as (select max(cnt) as m from counts)
  select count(*) > 1
  from counts c, mx
  where c.cnt = mx.m;
$$;

-- 이전 버전 제거 — 이름 충돌 방지
drop function if exists public.compute_crowd_status_core(
  int, int[], int[], int, int, timestamptz, timestamptz, boolean
);
drop function if exists public.compute_crowd_status_core(
  int, int[], int, timestamptz, timestamptz, boolean
);
drop function if exists public.compute_crowd_status_core(
  int, timestamptz, int[], timestamptz[], int
);

-- p_owner_level / p_owner_at: 사장님 최신 제보의 레벨·시각 (없으면 둘 다 null)
-- p_user_levels / p_user_ats: 유저 제보(유저당 1건)의 레벨·시각 — 인덱스로 1:1 대응, 순서 무관
-- p_now: 현재 시각 — 사장님 5분 우선권 판단용
create or replace function public.compute_crowd_status_core(
  p_owner_level int,
  p_owner_at timestamptz,
  p_user_levels int[],
  p_user_ats timestamptz[],
  p_current_display int,
  p_now timestamptz,
  out display_level int,
  out base_source text,
  out confidence text,
  out report_count int,
  out refresh_updated_at boolean
)
language plpgsql
immutable
as $$
declare
  v_owner_priority_window interval := interval '5 minutes';
  v_owner_within_priority boolean := false;
  v_user_levels int[] := coalesce(p_user_levels, array[]::int[]);
  v_user_ats timestamptz[] := coalesce(p_user_ats, array[]::timestamptz[]);
  v_n int := coalesce(array_length(v_user_levels, 1), 0);
  v_all_levels int[] := v_user_levels;
  v_latest_level int;
  v_latest_at timestamptz;
  v_latest_is_owner boolean := false;
  v_user_latest_level int;
  v_user_latest_at timestamptz;
  v_dom_level int;
  v_dom_cnt int;
  v_dom_ratio numeric;
  v_dom_total int;
  i int;
begin
  report_count := v_n;

  if p_owner_level is not null and p_owner_at is not null then
    v_all_levels := v_all_levels || p_owner_level;
  end if;

  -- 유저 제보 중 최신
  if v_n > 0 then
    v_user_latest_level := v_user_levels[1];
    v_user_latest_at := v_user_ats[1];
    for i in 2..v_n loop
      if v_user_ats[i] > v_user_latest_at then
        v_user_latest_level := v_user_levels[i];
        v_user_latest_at := v_user_ats[i];
      end if;
    end loop;
  end if;

  -- 사장님 제보가 5분 이내면, 그보다 늦은 유저 제보가 있어도 사장님 값을 우선한다.
  if p_owner_level is not null and p_owner_at is not null and p_now is not null then
    v_owner_within_priority := (p_now - p_owner_at) <= v_owner_priority_window;
  end if;

  -- 전체(사장님+유저) 중 최신 — 그게 곧 display_level (사장님 5분 우선권 적용)
  if p_owner_level is not null and p_owner_at is not null then
    if v_owner_within_priority or v_n = 0 or p_owner_at >= v_user_latest_at then
      v_latest_level := p_owner_level;
      v_latest_at := p_owner_at;
      v_latest_is_owner := true;
    else
      v_latest_level := v_user_latest_level;
      v_latest_at := v_user_latest_at;
    end if;
  elsif v_n > 0 then
    v_latest_level := v_user_latest_level;
    v_latest_at := v_user_latest_at;
  else
    -- 계산 대상 제보가 전혀 없음 — 직전 표시값 유지(없으면 기본 여유로움)
    display_level := coalesce(p_current_display, 1);
    base_source := 'user';
    confidence := 'low';
    refresh_updated_at := false;
    return;
  end if;

  display_level := v_latest_level;
  base_source := case when v_latest_is_owner then 'owner' else 'user' end;
  refresh_updated_at := p_current_display is distinct from display_level;

  -- confidence: status 결정과 무관, 다수결/최근 일치도로만 산정
  -- 1) 사장님 최신과 유저 최신이 일치 → high
  if p_owner_level is not null and v_n > 0 and p_owner_level = v_user_latest_level then
    confidence := 'high';
    return;
  end if;

  -- 2) 의견이 완전히 갈림(동률) → low
  if public.crowd_is_split(v_all_levels) then
    confidence := 'low';
    return;
  end if;

  -- 3) 최신 제보와 그 직전 제보 비교 (시각순 정렬해서 상위 2개)
  if array_length(v_all_levels, 1) >= 2 then
    declare
      v_sorted_levels int[];
      v_sorted_ats timestamptz[];
      v_tmp_level int;
      v_tmp_at timestamptz;
      j int;
      k int;
    begin
      v_sorted_levels := v_user_levels;
      v_sorted_ats := v_user_ats;
      if p_owner_level is not null and p_owner_at is not null then
        v_sorted_levels := v_sorted_levels || p_owner_level;
        v_sorted_ats := v_sorted_ats || p_owner_at;
      end if;
      -- 시각 내림차순 정렬 (단순 삽입 정렬 — 입력 규모가 작음)
      for j in 2..array_length(v_sorted_ats, 1) loop
        v_tmp_at := v_sorted_ats[j];
        v_tmp_level := v_sorted_levels[j];
        k := j;
        while k > 1 and v_sorted_ats[k-1] < v_tmp_at loop
          v_sorted_ats[k] := v_sorted_ats[k-1];
          v_sorted_levels[k] := v_sorted_levels[k-1];
          k := k - 1;
        end loop;
        v_sorted_ats[k] := v_tmp_at;
        v_sorted_levels[k] := v_tmp_level;
      end loop;

      if abs(v_sorted_levels[1] - v_sorted_levels[2]) >= 2 then
        confidence := 'low';
        return;
      end if;

      if v_sorted_levels[1] = v_sorted_levels[2] then
        confidence := 'high';
        return;
      end if;
    end;
  end if;

  -- 4) 제보가 1건뿐 → low
  if array_length(v_all_levels, 1) = 1 then
    confidence := 'low';
    return;
  end if;

  -- 5) 다수결 비율로 판단
  select dominant_level, dominant_cnt, dominant_ratio, total_cnt
  into v_dom_level, v_dom_cnt, v_dom_ratio, v_dom_total
  from public.crowd_dominant_stats(v_all_levels);

  if v_dom_total >= 5 and v_dom_ratio >= 0.8 then
    confidence := 'high';
  elsif v_dom_ratio >= 0.6 then
    confidence := 'medium';
  else
    confidence := 'medium';
  end if;
end;
$$;

create or replace function public.recalculate_crowd_status(
  p_restaurant_id uuid,
  p_owner_just_reported boolean default false
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_now timestamptz := now();
  v_owner_level int;
  v_owner_at timestamptz;
  v_user_levels int[];
  v_user_ats timestamptz[];
  v_current_display int;
  v_core record;
  v_last_report_at timestamptz;
  v_description jsonb;
  v_session_start timestamptz;
  v_report_since timestamptz;
begin
  select r.description
  into v_description
  from public.restaurants r
  where r.id = p_restaurant_id;

  v_session_start := public.restaurant_current_session_start(v_description, v_now);
  v_report_since := greatest(
    v_now - interval '20 minutes',
    coalesce(v_session_start, v_now - interval '20 minutes')
  );

  select public.report_row_level(cr.metadata, cr.level::text), cr.created_at
  into v_owner_level, v_owner_at
  from public.crowd_reports cr
  where cr.restaurant_id = p_restaurant_id
    and cr.source = 'owner'::public.crowd_source
    and cr.created_at >= coalesce(v_session_start, '-infinity'::timestamptz)
  order by cr.created_at desc
  limit 1;

  with deduped as (
    select distinct on (coalesce(cr.user_id::text, cr.id::text))
      public.report_row_level(cr.metadata, cr.level::text) as lvl,
      cr.created_at
    from public.crowd_reports cr
    where cr.restaurant_id = p_restaurant_id
      and cr.source = 'user'::public.crowd_source
      and cr.created_at >= v_report_since
    order by coalesce(cr.user_id::text, cr.id::text), cr.created_at desc
  )
  select
    coalesce(array_agg(lvl), array[]::int[]),
    coalesce(array_agg(created_at), array[]::timestamptz[]),
    max(created_at)
  into v_user_levels, v_user_ats, v_last_report_at
  from deduped;

  select public.ui_status_to_level(cs.display_level::text)
  into v_current_display
  from public.crowd_status cs
  where cs.restaurant_id = p_restaurant_id;

  select *
  into v_core
  from public.compute_crowd_status_core(
    v_owner_level,
    v_owner_at,
    v_user_levels,
    v_user_ats,
    v_current_display,
    v_now
  );

  -- 가장 최신 제보 시각(사장님/유저 중) — updated_at 기준
  declare
    v_latest_report_at timestamptz := greatest(
      coalesce(v_owner_at, '-infinity'::timestamptz),
      coalesce(v_last_report_at, '-infinity'::timestamptz)
    );
    v_display_level int := v_core.display_level;
    v_base_source text := v_core.base_source;
    v_confidence text := v_core.confidence;
    v_report_count int := v_core.report_count;
    v_refresh boolean := v_core.refresh_updated_at;
  begin
    if v_latest_report_at = '-infinity'::timestamptz then
      v_latest_report_at := null;
    end if;

    insert into public.crowd_status (
      restaurant_id,
      level,
      display_level,
      base_source,
      confidence,
      report_count,
      status_started_at,
      updated_at,
      last_applied_report_at
    )
    values (
      p_restaurant_id,
      v_display_level,
      v_display_level,
      v_base_source,
      v_confidence,
      v_report_count,
      coalesce(v_latest_report_at, v_now),
      v_now,
      v_latest_report_at
    )
    on conflict (restaurant_id) do update set
      level = excluded.level,
      display_level = excluded.display_level,
      base_source = excluded.base_source,
      confidence = excluded.confidence,
      report_count = excluded.report_count,
      status_started_at = case
        when public.crowd_status.display_level is distinct from excluded.display_level
          then excluded.status_started_at
        else public.crowd_status.status_started_at
      end,
      updated_at = case
        when v_refresh then v_now
        else public.crowd_status.updated_at
      end,
      last_applied_report_at = case
        when v_refresh then coalesce(v_latest_report_at, v_now)
        else public.crowd_status.last_applied_report_at
      end;
  end;
end;
$$;

create or replace function public.recalculate_all_crowd_status(
  p_owner_just_reported boolean default false
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  r record;
begin
  for r in select id from public.restaurants where is_active = true loop
    perform public.recalculate_crowd_status(r.id, p_owner_just_reported);
  end loop;
end;
$$;

create or replace function public.trg_crowd_reports_recalc()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  perform public.recalculate_crowd_status(
    new.restaurant_id,
    new.source = 'owner'::public.crowd_source
  );
  return new;
end;
$$;

drop trigger if exists crowd_reports_recalc on public.crowd_reports;
create trigger crowd_reports_recalc
  after insert on public.crowd_reports
  for each row
  execute function public.trg_crowd_reports_recalc();

-- 전 매장 백필
select public.recalculate_all_crowd_status(false);
