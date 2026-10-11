-- 어드민이 hours만 바꾸고 hours_periods(구글 요일별 캐시)를 남긴 매장 정리
-- Dashboard → SQL Editor → Run (1회)
--
-- 앱은 hours_periods가 있으면 화면 문구(hours)가 아니라 그 캐시로 영업 여부를 판단한다.
-- 그래서 어드민에서 고친 시간은 보이는데 상태는 계속 영업안함으로 남는다.
--
-- 요일마다 다른 구글 영업시간(hours가 그중 하루와 같음)은 유지한다.
-- hours가 어떤 요일 구간과도 다르면 수동 수정으로 보고 periods를 지우고
-- hours_display를 hours로 맞춘다. 24시간(close 없는 period)은 00:00 - 24:00과 같은 값으로 본다.

create or replace function pg_temp.normalize_canonical_hours(p_hours text)
returns text
language plpgsql
immutable
as $$
declare
  v_parts text[];
begin
  if p_hours is null or btrim(p_hours) = '' then
    return '';
  end if;

  select coalesce(array_agg(
    lpad(m[1], 2, '0') || ':' || m[2] || ' - ' || lpad(m[3], 2, '0') || ':' || m[4]
    order by (m[1]::int * 60 + m[2]::int)
  ), '{}')
  into v_parts
  from regexp_matches(
    p_hours,
    '(\d{1,2}):(\d{2})\s*[-~–—]\s*(\d{1,2}):(\d{2})',
    'g'
  ) as m;

  return array_to_string(v_parts, ', ');
end;
$$;

create or replace function pg_temp.period_day_signatures(p_periods jsonb)
returns text[]
language plpgsql
immutable
as $$
declare
  v_elem jsonb;
  v_open jsonb;
  v_close jsonb;
  v_day int;
  v_start text;
  v_end text;
  v_by_day jsonb := '{}'::jsonb;
  v_ranges jsonb;
  v_sigs text[] := '{}';
  v_sig text;
  v_always boolean := false;
begin
  if p_periods is null or jsonb_typeof(p_periods) <> 'array' then
    return v_sigs;
  end if;

  if jsonb_array_length(p_periods) = 1
     and p_periods->0->'open' is not null
     and (p_periods->0->'close' is null or p_periods->0->'close' = 'null'::jsonb) then
    return array['00:00 - 24:00'];
  end if;

  for v_elem in select value from jsonb_array_elements(p_periods)
  loop
    v_open := v_elem->'open';
    v_close := v_elem->'close';
    if v_open is null or v_open = 'null'::jsonb then
      continue;
    end if;
    if v_close is null or v_close = 'null'::jsonb then
      v_always := true;
      continue;
    end if;

    v_day := (v_open->>'day')::int;
    v_start := lpad(((v_open->>'time')::int / 100)::text, 2, '0')
      || ':' || lpad(((v_open->>'time')::int % 100)::text, 2, '0');
    v_end := lpad(((v_close->>'time')::int / 100)::text, 2, '0')
      || ':' || lpad(((v_close->>'time')::int % 100)::text, 2, '0');
    v_ranges := coalesce(v_by_day->v_day::text, '[]'::jsonb)
      || jsonb_build_array(jsonb_build_object('s', v_start, 'e', v_end, 'ord', (v_open->>'time')::int));
    v_by_day := jsonb_set(v_by_day, array[v_day::text], v_ranges);
  end loop;

  if v_always and v_by_day = '{}'::jsonb then
    return array['00:00 - 24:00'];
  end if;

  for v_day, v_ranges in
    select key::int, value
    from jsonb_each(v_by_day)
  loop
    v_sig := null;
    for v_elem in
      select e
      from jsonb_array_elements(v_ranges) as t(e)
      order by (t.e->>'ord')::int
    loop
      v_sig := concat_ws(
        ', ',
        v_sig,
        (v_elem->>'s') || ' - ' || (v_elem->>'e')
      );
    end loop;
    if v_sig is not null then
      v_sigs := v_sigs || v_sig;
    end if;
  end loop;

  return v_sigs;
end;
$$;

drop table if exists pg_temp.stale_hours_cleared;
create temp table stale_hours_cleared (
  id uuid,
  name text,
  hours text
);

do $$
declare
  r record;
  v_desc jsonb;
  v_hours text;
  v_norm text;
  v_sigs text[];
begin
  for r in
    select id, name, description
    from public.restaurants
    where coalesce(description, '') ~ '^\{'
  loop
    v_desc := r.description::jsonb;
    if coalesce(jsonb_typeof(v_desc->'hours_periods'), '') <> 'array'
       or coalesce(jsonb_array_length(v_desc->'hours_periods'), 0) = 0 then
      continue;
    end if;

    v_hours := btrim(coalesce(v_desc->>'hours', ''));
    v_norm := pg_temp.normalize_canonical_hours(v_hours);
    if v_norm = '' then
      continue;
    end if;

    v_sigs := pg_temp.period_day_signatures(v_desc->'hours_periods');
    if v_norm = any (v_sigs) then
      continue;
    end if;

    v_desc := jsonb_set(v_desc, '{hours_display}', to_jsonb(v_hours));
    v_desc := v_desc - 'hours_periods';

    update public.restaurants
    set description = v_desc::text
    where id = r.id;

    insert into stale_hours_cleared (id, name, hours)
    values (r.id, r.name, v_hours);
  end loop;
end;
$$;

select id, name, hours from stale_hours_cleared order by name;
