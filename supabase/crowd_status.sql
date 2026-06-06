-- 혼잡도 DB 스키마 + 공통 헬퍼 + 제보 RPC
-- Dashboard → SQL Editor: policies.sql 이후 실행
-- 다음: crowd_status_v2_compute.sql (계산 함수·트리거·백필)

-- ── system_settings ──
create table if not exists public.system_settings (
  key varchar primary key,
  value varchar not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

insert into public.system_settings (key, value)
values ('owner_influence', '80')
on conflict (key) do nothing;

-- ── crowd_status ──
-- display_level / level: int 1=여유로움, 2=약간혼잡, 3=자리없음 (UI 한글은 metadata.status / RPC 에만)
create table if not exists public.crowd_status (
  restaurant_id uuid primary key references public.restaurants(id) on delete cascade,
  display_level int not null default 1,
  level int not null default 1,
  base_source varchar not null default 'owner',
  confidence varchar not null default 'low',
  report_count int not null default 0,
  status_started_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  last_applied_report_at timestamptz
);

create index if not exists crowd_status_updated_at_idx
  on public.crowd_status (updated_at desc);

-- ── Supabase 실제 enum (이 DB 기준) ──
-- crowd_reports.level  → crowd_level  (closed | relaxed | normal | full)
-- crowd_reports.source → crowd_source (user | owner | system)
-- users.role           → user_role    (user | owner | admin)
-- ⚠️ report_source 타입은 없음 — crowd_source 를 사용

create or replace function public.ui_level_to_crowd_level(p_ui_level int)
returns public.crowd_level
language sql
immutable
as $$
  select case greatest(1, least(3, coalesce(p_ui_level, 1)))
    when 1 then 'normal'::public.crowd_level
    when 2 then 'full'::public.crowd_level
    else 'full'::public.crowd_level
  end;
$$;

create or replace function public.text_to_crowd_source(p_source text)
returns public.crowd_source
language sql
immutable
as $$
  select case trim(coalesce(p_source, ''))
    when 'owner' then 'owner'::public.crowd_source
    when 'system' then 'system'::public.crowd_source
    else 'user'::public.crowd_source
  end;
$$;

-- ── level helpers (모든 SQL·마이그레이션·RPC 공통) ──
create or replace function public.ui_status_to_level(p_input text)
returns int
language sql
immutable
as $$
  select case trim(coalesce(p_input, ''))
    when '1' then 1
    when '2' then 2
    when '3' then 3
    when '여유로움' then 1
    when '약간혼잡' then 2
    when '자리없음' then 3
    when 'normal' then 1
    when 'relaxed' then 1
    when 'full' then 2
    when 'moderate' then 2
    when 'closed' then 1
    else greatest(1, least(3, coalesce(
      nullif(regexp_replace(trim(coalesce(p_input, '')), '[^0-9]', '', 'g'), '')::int,
      1
    )))
  end;
$$;

create or replace function public.level_to_ui_status(p_level int)
returns text
language sql
immutable
as $$
  select case greatest(1, least(3, coalesce(p_level, 1)))
    when 1 then '여유로움'
    when 2 then '약간혼잡'
    else '자리없음'
  end;
$$;

create or replace function public.report_row_level(p_metadata jsonb, p_level text)
returns int
language sql
immutable
as $$
  select public.ui_status_to_level(
    coalesce(nullif(trim(p_metadata->>'status'), ''), p_level)
  );
$$;

create or replace function public.restaurant_current_session_start(
  p_description jsonb,
  p_now timestamptz default now()
)
returns timestamptz
language plpgsql
stable
as $$
declare
  v_hours text;
  v_local timestamp;
  v_now_min int;
  v_part text;
  m text[];
  v_sh int;
  v_sm int;
  v_eh int;
  v_em int;
  v_start_min int;
  v_end_min int;
  v_end_mod int;
begin
  v_hours := coalesce(
    nullif(trim(p_description->>'hours'), ''),
    '11:00 - 21:00'
  );
  v_local := timezone('Asia/Seoul', p_now);
  v_now_min := extract(hour from v_local)::int * 60 + extract(minute from v_local)::int;

  foreach v_part in array string_to_array(v_hours, ',') loop
    v_part := trim(v_part);
    m := regexp_match(v_part, '^(\d{1,2}):(\d{2})\s*[-~–—]\s*(\d{1,2}):(\d{2})$');
    if m is null then
      continue;
    end if;

    v_sh := m[1]::int;
    v_sm := m[2]::int;
    v_eh := m[3]::int;
    v_em := m[4]::int;
    v_start_min := v_sh * 60 + v_sm;
    v_end_min := v_eh * 60 + v_em;
    if v_end_min <= v_start_min then
      v_end_min := v_end_min + 24 * 60;
    end if;

    if v_end_min <= 24 * 60 then
      if v_now_min >= v_start_min and v_now_min < v_end_min then
        return (date_trunc('day', v_local) + make_interval(hours => v_sh, mins => v_sm))
          at time zone 'Asia/Seoul';
      end if;
    else
      v_end_mod := v_end_min % (24 * 60);
      if v_now_min >= v_start_min or v_now_min < v_end_mod then
        return (date_trunc('day', v_local) + make_interval(hours => v_sh, mins => v_sm))
          at time zone 'Asia/Seoul';
      end if;
    end if;
  end loop;

  return null;
end;
$$;

-- ── legacy schema → int 정규화 (여러 번 Run 안전) ──
alter table public.crowd_status
  add column if not exists level int,
  add column if not exists base_source varchar not null default 'owner',
  add column if not exists confidence varchar not null default 'low',
  add column if not exists report_count int not null default 0,
  add column if not exists status_started_at timestamptz not null default now(),
  add column if not exists updated_at timestamptz not null default now(),
  add column if not exists last_applied_report_at timestamptz;

update public.crowd_status
set status_started_at = coalesce(updated_at, now())
where status_started_at is null;

DO $$
DECLARE
  v_type text;
BEGIN
  SELECT c.data_type
  INTO v_type
  FROM information_schema.columns c
  WHERE c.table_schema = 'public'
    AND c.table_name = 'crowd_status'
    AND c.column_name = 'display_level';

  IF v_type IS NOT NULL AND v_type <> 'integer' THEN
    EXECUTE 'ALTER TABLE public.crowd_status ALTER COLUMN display_level DROP DEFAULT';
    EXECUTE $sql$
      ALTER TABLE public.crowd_status
      ALTER COLUMN display_level TYPE int
      USING (public.ui_status_to_level(display_level::text))
    $sql$;
    EXECUTE 'ALTER TABLE public.crowd_status ALTER COLUMN display_level SET DEFAULT 1';
    EXECUTE 'ALTER TABLE public.crowd_status ALTER COLUMN display_level SET NOT NULL';
  END IF;
END $$;

update public.crowd_status
set
  display_level = public.ui_status_to_level(display_level::text),
  level = coalesce(
    level,
    public.ui_status_to_level(display_level::text)
  )
where display_level is not null;

update public.crowd_status
set level = display_level
where level is null;

alter table public.crowd_status
  alter column display_level set default 1,
  alter column level set default 1;

alter table public.system_settings enable row level security;
alter table public.crowd_status enable row level security;

drop policy if exists "system_settings_select_all" on public.system_settings;
create policy "system_settings_select_all" on public.system_settings
  for select using (true);

drop policy if exists "system_settings_update_admin" on public.system_settings;
create policy "system_settings_update_admin" on public.system_settings
  for update to authenticated
  using (public.is_admin())
  with check (public.is_admin());

drop policy if exists "crowd_status_select_all" on public.crowd_status;
create policy "crowd_status_select_all" on public.crowd_status
  for select using (true);

create or replace function public.get_owner_influence()
returns int
language sql
stable
security definer
set search_path = public
as $$
  select coalesce(
    nullif(regexp_replace(value, '[^0-9]', '', 'g'), '')::int,
    80
  )
  from public.system_settings
  where key = 'owner_influence'
  limit 1;
$$;

create or replace function public.set_owner_influence(p_value int)
returns int
language plpgsql
security definer
set search_path = public
as $$
declare
  v int := greatest(0, least(100, p_value));
begin
  if not public.is_admin() then
    raise exception '관리자만 변경할 수 있어요.';
  end if;

  insert into public.system_settings (key, value, updated_at)
  values ('owner_influence', v::text, now())
  on conflict (key) do update
    set value = excluded.value,
        updated_at = now();

  return v;
end;
$$;

create or replace function public.haversine_meters(
  lat1 double precision,
  lon1 double precision,
  lat2 double precision,
  lon2 double precision
)
returns double precision
language sql
immutable
as $$
  select 6371000 * 2 * asin(sqrt(
    power(sin(radians(lat2 - lat1) / 2), 2) +
    cos(radians(lat1)) * cos(radians(lat2)) *
    power(sin(radians(lon2 - lon1) / 2), 2)
  ));
$$;

-- ── 제보 RPC (GPS 80m, 5분 중복 방지) ──
-- crowd_reports.level = crowd_level enum, source = crowd_source enum
create or replace function public.submit_crowd_report(
  p_restaurant_id uuid,
  p_status text,
  p_source text default 'user',
  p_lat double precision default null,
  p_lng double precision default null
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_lat double precision;
  v_lng double precision;
  v_distance double precision;
  v_level public.crowd_level;
  v_source public.crowd_source;
  v_ui_level int;
begin
  if v_uid is null then
    raise exception '로그인이 필요해요.';
  end if;

  if p_status not in ('여유로움', '약간혼잡', '자리없음') then
    raise exception '유효하지 않은 혼잡도예요.';
  end if;

  v_ui_level := public.ui_status_to_level(p_status);

  if p_source not in ('user', 'owner') then
    raise exception '유효하지 않은 제보 유형이에요.';
  end if;

  v_level := public.ui_level_to_crowd_level(v_ui_level);
  v_source := public.text_to_crowd_source(p_source);

  if p_source = 'user' then
    if p_lat is null or p_lng is null then
      raise exception '현재 위치를 확인할 수 없어요. 위치 권한을 확인해주세요.';
    end if;

    if exists (
      select 1
      from public.crowd_reports cr
      where cr.restaurant_id = p_restaurant_id
        and cr.user_id = v_uid
        and cr.source = 'user'::public.crowd_source
        and cr.created_at >= now() - interval '5 minutes'
    ) then
      raise exception E'방금 제보한 식당이에요.\n잠시 후 다시 제보해주세요.';
    end if;

    select r.latitude, r.longitude
    into v_lat, v_lng
    from public.restaurants r
    where r.id = p_restaurant_id;

    if v_lat is null or v_lng is null then
      raise exception '식당 위치 정보가 없어요.';
    end if;

    v_distance := public.haversine_meters(p_lat, p_lng, v_lat, v_lng);
    if v_distance > 80 then
      raise exception '식당 근처에서만 혼잡도를 제보할 수 있어요.';
    end if;
  end if;

  insert into public.crowd_reports (
    restaurant_id,
    level,
    source,
    user_id,
    metadata
  )
  values (
    p_restaurant_id,
    v_level,
    v_source,
    v_uid,
    jsonb_build_object(
      'status', public.level_to_ui_status(v_ui_level),
      'user_id', v_uid::text,
      'lat', p_lat,
      'lng', p_lng
    )
  );
end;
$$;

grant execute on function public.ui_level_to_crowd_level(int) to anon, authenticated;
grant execute on function public.text_to_crowd_source(text) to anon, authenticated;
grant execute on function public.ui_status_to_level(text) to anon, authenticated;
grant execute on function public.level_to_ui_status(int) to anon, authenticated;
grant execute on function public.get_owner_influence() to anon, authenticated;
grant execute on function public.set_owner_influence(int) to authenticated;
grant execute on function public.submit_crowd_report(uuid, text, text, double precision, double precision)
  to authenticated;

comment on function public.submit_crowd_report is
  '유저 제보: GPS 80m + 5분 중복 방지. 사장님 제보: GPS 생략.';
comment on column public.crowd_status.display_level is
  '1=여유로움, 2=약간혼잡, 3=자리없음. UI 한글은 level_to_ui_status()로 변환.';
comment on table public.crowd_status is
  '매장별 표시 혼잡도. 계산은 crowd_status_v2_compute.sql 의 recalculate_crowd_status.';
