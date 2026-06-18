-- PDF 「혼잡도 계산 로직 개편 2」 — compute / recalculate / trigger
-- crowd_status.sql 실행 직후 Run

create or replace function public.crowd_move_one_step(p_base int, p_target int)
returns int
language sql
immutable
as $$
  select case
    when p_target > p_base then least(p_base + 1, 3)
    when p_target < p_base then greatest(p_base - 1, 1)
    else p_base
  end;
$$;

create or replace function public.crowd_clamp_step(
  p_current int,
  p_target int,
  p_allow_full boolean
)
returns int
language plpgsql
immutable
as $$
begin
  if p_current is null then return p_target; end if;
  if p_current = p_target then return p_current; end if;
  if abs(p_target - p_current) >= 2 and not p_allow_full then
    return public.crowd_move_one_step(p_current, p_target);
  end if;
  return p_target;
end;
$$;

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

-- v1 compute (7-arg) 제거 — 이름 충돌 방지
drop function if exists public.compute_crowd_status_core(
  int, int[], int[], int, int, timestamptz, timestamptz, boolean
);

create or replace function public.compute_crowd_status_core(
  p_owner_level int,
  p_user_levels_20 int[],
  p_current_display int,
  p_status_started_at timestamptz,
  p_now timestamptz,
  p_owner_just_reported boolean,
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
  v_users int[] := coalesce(p_user_levels_20, array[]::int[]);
  v_n int := coalesce(array_length(v_users, 1), 0);
  v_current int := p_current_display;
  v_owner int := p_owner_level;
  v_candidate int;
  v_dom_level int;
  v_dom_cnt int;
  v_dom_ratio numeric;
  v_dom_total int;
  v_display_base int;
begin
  report_count := v_n;
  refresh_updated_at := false;

  if coalesce(p_owner_just_reported, false) and v_owner is not null then
    display_level := v_owner;
    base_source := 'owner';
    confidence := 'high';
    refresh_updated_at := true;
    return;
  end if;

  if v_n = 0 then
    if v_current is not null then
      display_level := v_current;
      base_source := case when v_owner is null then 'user' else 'owner' end;
      confidence := case
        when v_current = 1 and v_owner is null then 'low'
        when v_owner is null then 'medium'
        else 'high'
      end;
      refresh_updated_at := v_current = 1 and v_owner is null;
      return;
    end if;
    if v_owner is not null then
      display_level := v_owner;
      base_source := 'owner';
      confidence := 'high';
      refresh_updated_at := true;
      return;
    end if;
    display_level := 1;
    base_source := 'user';
    confidence := 'low';
    return;
  end if;

  v_display_base := coalesce(v_current, v_owner, 1);

  if v_owner is null then
    if v_n = 1 then
      if v_current is null then
        v_candidate := v_users[1];
        confidence := 'low';
        refresh_updated_at := true;
      elsif v_users[1] = v_current then
        v_candidate := v_current;
        confidence := 'medium';
        refresh_updated_at := true;
      else
        v_candidate := public.crowd_move_one_step(v_current, v_users[1]);
        refresh_updated_at := v_candidate is distinct from v_current;
        confidence := 'medium';
      end if;
      base_source := 'user';
    elsif v_n = 2 then
      if v_users[1] = v_users[2] then
        v_candidate := public.crowd_clamp_step(v_current, v_users[1], false);
        refresh_updated_at := v_candidate is distinct from v_current or v_users[1] = v_current;
        confidence := 'medium';
      elsif v_current is null then
        v_candidate := 2;
        refresh_updated_at := true;
        confidence := 'low';
      else
        v_candidate := v_current;
        confidence := 'medium';
      end if;
      base_source := 'user';
    else
      select dominant_level, dominant_cnt, dominant_ratio, total_cnt
      into v_dom_level, v_dom_cnt, v_dom_ratio, v_dom_total
      from public.crowd_dominant_stats(v_users);
      if public.crowd_is_split(v_users) then
        v_candidate := coalesce(v_current, 2);
        refresh_updated_at := v_current is null;
        confidence := case when v_current is null then 'low' else 'medium' end;
      elsif v_dom_ratio >= 0.8 and v_dom_total >= 5 then
        v_candidate := v_dom_level;
        refresh_updated_at := true;
        confidence := 'high';
      elsif v_dom_ratio >= 0.6 then
        v_candidate := public.crowd_clamp_step(
          v_current,
          v_dom_level,
          v_dom_total >= 5 and v_dom_ratio >= 0.8
        );
        refresh_updated_at := v_candidate is distinct from v_current;
        confidence := 'medium';
      else
        v_candidate := coalesce(v_current, 2);
        refresh_updated_at := v_current is null;
        confidence := 'low';
      end if;
      base_source := 'user';
    end if;
  else
    if v_n >= 1 and (select bool_and(u = v_owner) from unnest(v_users) u) then
      v_candidate := v_owner;
      base_source := 'owner';
      confidence := 'high';
      refresh_updated_at := true;
    elsif v_n <= 2 then
      v_candidate := v_display_base;
      base_source := 'owner';
      confidence := 'high';
    else
      select dominant_level, dominant_cnt, dominant_ratio, total_cnt
      into v_dom_level, v_dom_cnt, v_dom_ratio, v_dom_total
      from public.crowd_dominant_stats(v_users);
      if public.crowd_is_split(v_users) then
        v_candidate := v_display_base;
        base_source := 'owner';
        confidence := 'medium';
      elsif v_dom_total >= 5 and v_dom_ratio >= 0.8 then
        v_candidate := v_dom_level;
        base_source := 'user';
        confidence := 'high';
        refresh_updated_at := v_dom_level is distinct from v_display_base;
      elsif v_dom_total >= 3 and v_dom_ratio >= 0.7 then
        v_candidate := public.crowd_move_one_step(v_owner, v_dom_level);
        base_source := 'mixed';
        confidence := 'medium';
        refresh_updated_at := v_candidate is distinct from v_display_base;
      else
        v_candidate := v_display_base;
        base_source := 'owner';
        confidence := 'medium';
      end if;
    end if;
  end if;

  display_level := v_candidate;

  if v_current is not null
     and p_status_started_at is not null
     and display_level is distinct from v_current
     and not coalesce(p_owner_just_reported, false) then
    if not (
      v_n >= 5
      and coalesce(
        (select dominant_ratio from public.crowd_dominant_stats(v_users)),
        0
      ) >= 0.8
    ) then
      if p_now - p_status_started_at < interval '10 minutes' then
        display_level := v_current;
        refresh_updated_at := false;
      end if;
    end if;
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
  v_user_20 int[];
  v_current_display int;
  v_started timestamptz;
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

  select public.report_row_level(cr.metadata, cr.level::text)
  into v_owner_level
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
    coalesce(array_agg(lvl order by created_at desc), array[]::int[]),
    max(created_at)
  into v_user_20, v_last_report_at
  from deduped;

  select
    public.ui_status_to_level(cs.display_level::text),
    cs.status_started_at
  into v_current_display, v_started
  from public.crowd_status cs
  where cs.restaurant_id = p_restaurant_id;

  -- 이번 영업 세션의 첫 제보 전에는 v_current_display를 null로 둬서
  -- compute_crowd_status_core가 "이전 상태 없음" 분기(제보값 그대로 반영)를 타게 한다.
  -- (1로 두면 1단계 댐핑에 걸려 첫 제보가 한 단계만 반영되는 버그가 있었음)
  if v_session_start is not null
     and (v_started is null or v_started < v_session_start) then
    v_current_display := null;
    v_started := v_session_start;
  end if;

  select *
  into v_core
  from public.compute_crowd_status_core(
    v_owner_level,
    v_user_20,
    v_current_display,
    v_started,
    v_now,
    p_owner_just_reported
  );

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
    v_core.display_level,
    v_core.display_level,
    v_core.base_source,
    v_core.confidence,
    v_core.report_count,
    coalesce(v_started, v_now),
    v_now,
    v_last_report_at
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
      when v_core.refresh_updated_at then v_now
      else public.crowd_status.updated_at
    end,
    last_applied_report_at = case
      when v_core.refresh_updated_at then coalesce(v_last_report_at, v_now)
      else public.crowd_status.last_applied_report_at
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
