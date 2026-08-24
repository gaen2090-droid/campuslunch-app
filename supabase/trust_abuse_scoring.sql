-- 신뢰·어뷰징용 원본 지표 수집 (점수/임계 boolean 없음)
-- Dashboard → SQL Editor → Run (submit_crowd_report.sql 이후)
--
-- 수집
--   crowd_reports.metadata: lat, lng, device_install_id, app_session_id
--   report_attempts: 성공/실패 시도
--   analytics_events.screen_dwell: 탭 체류
--
-- 어드민 RPC
--   admin_trust_signals_report(p_days) — 유저별 수치 요약
--   admin_trust_signals_user(p_user_id, p_days) — 유저 상세(간격 배열 등)

-- ── 1. 제보 시도 로그 ──────────────────────────────────────────────
create table if not exists public.report_attempts (
  id bigint generated always as identity primary key,
  user_id uuid references auth.users (id) on delete set null,
  restaurant_id uuid references public.restaurants (id) on delete set null,
  outcome text not null check (outcome in ('success', 'fail')),
  fail_reason text,
  device_install_id text,
  app_session_id text,
  latitude double precision,
  longitude double precision,
  source text,
  status_attempted text,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create index if not exists report_attempts_user_created_idx
  on public.report_attempts (user_id, created_at desc)
  where user_id is not null;

create index if not exists report_attempts_device_created_idx
  on public.report_attempts (device_install_id, created_at desc)
  where device_install_id is not null;

create index if not exists report_attempts_outcome_created_idx
  on public.report_attempts (outcome, created_at desc);

alter table public.report_attempts enable row level security;

drop policy if exists "report_attempts_insert_own" on public.report_attempts;
create policy "report_attempts_insert_own" on public.report_attempts
  for insert to authenticated
  with check (user_id is null or user_id = auth.uid());

create or replace function public.record_report_attempt(
  p_restaurant_id uuid,
  p_outcome text,
  p_fail_reason text default null,
  p_device_install_id text default null,
  p_app_session_id text default null,
  p_lat double precision default null,
  p_lng double precision default null,
  p_source text default 'user',
  p_status text default null,
  p_metadata jsonb default '{}'::jsonb
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  uid uuid := auth.uid();
begin
  if uid is null then
    return;
  end if;
  if p_outcome not in ('success', 'fail') then
    return;
  end if;

  insert into public.report_attempts (
    user_id, restaurant_id, outcome, fail_reason,
    device_install_id, app_session_id,
    latitude, longitude, source, status_attempted, metadata
  ) values (
    uid,
    p_restaurant_id,
    p_outcome,
    left(coalesce(p_fail_reason, ''), 500),
    nullif(trim(coalesce(p_device_install_id, '')), ''),
    nullif(trim(coalesce(p_app_session_id, '')), ''),
    p_lat,
    p_lng,
    coalesce(nullif(trim(p_source), ''), 'user'),
    p_status,
    coalesce(p_metadata, '{}'::jsonb)
  );
end;
$$;

revoke all on function public.record_report_attempt(
  uuid, text, text, text, text, double precision, double precision, text, text, jsonb
) from public;
grant execute on function public.record_report_attempt(
  uuid, text, text, text, text, double precision, double precision, text, text, jsonb
) to authenticated;

-- ── 2. 화면 체류 ─────────────────────────────────────────────────
do $$
declare
  conname text;
begin
  for conname in
    select c.conname
    from pg_constraint c
    join pg_class t on t.oid = c.conrelid
    join pg_namespace n on n.oid = t.relnamespace
    where n.nspname = 'public'
      and t.relname = 'analytics_events'
      and c.contype = 'c'
      and pg_get_constraintdef(c.oid) ilike '%event_type%'
  loop
    execute format('alter table public.analytics_events drop constraint %I', conname);
  end loop;
end $$;

alter table public.analytics_events
  drop constraint if exists analytics_events_event_type_check;

alter table public.analytics_events
  add constraint analytics_events_event_type_check
  check (event_type in (
    'app_session',
    'banner_impression',
    'banner_click',
    'push_delivered',
    'push_click',
    'map_marker_click',
    'search_result_click',
    'detail_view',
    'screen_dwell'
  ));

create or replace function public.record_screen_dwell(
  p_screen text,
  p_dwell_ms int,
  p_app_session_id text default null,
  p_metadata jsonb default '{}'::jsonb
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  uid uuid := auth.uid();
  meta jsonb;
begin
  if uid is null then
    return;
  end if;
  if p_dwell_ms is null or p_dwell_ms < 2000 then
    return;
  end if;
  if nullif(trim(coalesce(p_screen, '')), '') is null then
    return;
  end if;

  meta := coalesce(p_metadata, '{}'::jsonb)
    || jsonb_build_object(
      'screen', left(trim(p_screen), 64),
      'dwell_ms', least(p_dwell_ms, 3600000)
    );
  if nullif(trim(coalesce(p_app_session_id, '')), '') is not null then
    meta := meta || jsonb_build_object('app_session_id', trim(p_app_session_id));
  end if;

  insert into public.analytics_events (user_id, event_type, restaurant_id, metadata)
  values (uid, 'screen_dwell', null, meta);
end;
$$;

revoke all on function public.record_screen_dwell(text, int, text, jsonb) from public;
grant execute on function public.record_screen_dwell(text, int, text, jsonb) to authenticated;

-- 구 점수 RPC 제거
drop function if exists public.admin_trust_abuse_report(int);

-- ── 3. 유저별 원본 지표 요약 ─────────────────────────────────────
create or replace function public.admin_trust_signals_report(p_days int default 30)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_days int := greatest(1, least(coalesce(p_days, 30), 90));
  v_since timestamptz := now() - make_interval(days => greatest(1, least(coalesce(p_days, 30), 90)));
  v_rows jsonb;
begin
  if not exists (
    select 1 from public.users u
    where u.id = v_uid and u.role = 'admin'
  ) then
    raise exception '관리자만 조회할 수 있어요.';
  end if;

  with user_reports as (
    select
      cr.user_id,
      cr.restaurant_id,
      cr.created_at,
      public.report_row_level(cr.metadata, cr.level::text) as lvl,
      case
        when (cr.metadata->>'lat') ~ '^-?[0-9]+(\\.[0-9]+)?$'
        then (cr.metadata->>'lat')::double precision
      end as lat,
      case
        when (cr.metadata->>'lng') ~ '^-?[0-9]+(\\.[0-9]+)?$'
        then (cr.metadata->>'lng')::double precision
      end as lng,
      nullif(trim(coalesce(cr.metadata->>'device_install_id', '')), '') as device_install_id,
      r.area as restaurant_area,
      r.name as restaurant_name
    from public.crowd_reports cr
    join public.restaurants r on r.id = cr.restaurant_id
    where cr.source = 'user'::public.crowd_source
      and cr.user_id is not null
      and cr.created_at >= v_since
  ),
  ranked as (
    select
      ur.*,
      lag(ur.created_at) over (partition by ur.user_id order by ur.created_at) as prev_at,
      lag(ur.restaurant_id) over (partition by ur.user_id order by ur.created_at) as prev_rid,
      lag(ur.lat) over (partition by ur.user_id order by ur.created_at) as prev_lat,
      lag(ur.lng) over (partition by ur.user_id order by ur.created_at) as prev_lng,
      lag(ur.restaurant_area) over (partition by ur.user_id order by ur.created_at) as prev_area
    from user_reports ur
  ),
  same_store_gaps as (
    select
      user_id,
      round((extract(epoch from (created_at - prev_at)) / 60.0)::numeric, 2) as gap_min
    from ranked
    where prev_rid = restaurant_id
      and prev_at is not null
  ),
  all_gaps as (
    select
      user_id,
      round((extract(epoch from (created_at - prev_at)) / 60.0)::numeric, 2) as gap_min
    from ranked
    where prev_at is not null
  ),
  move_gaps as (
    select
      user_id,
      round(public.haversine_meters(prev_lat, prev_lng, lat, lng)::numeric, 1) as meters,
      round((extract(epoch from (created_at - prev_at)) / 60.0)::numeric, 2) as gap_min,
      prev_area,
      restaurant_area as next_area
    from ranked
    where prev_lat is not null and lat is not null
      and prev_lng is not null and lng is not null
      and prev_at is not null
  ),
  area_trans as (
    select
      user_id,
      prev_area as from_area,
      restaurant_area as to_area,
      round((extract(epoch from (created_at - prev_at)) / 60.0)::numeric, 2) as gap_min
    from ranked
    where prev_area is not null
      and restaurant_area is distinct from prev_area
      and prev_at is not null
  ),
  peer as (
    select
      a.user_id,
      count(*) filter (where a.lvl = b.lvl)::int as agree_count,
      count(*)::int as overlap_count
    from user_reports a
    join user_reports b
      on a.restaurant_id = b.restaurant_id
     and a.user_id <> b.user_id
     and abs(extract(epoch from (a.created_at - b.created_at))) <= 600
     and a.created_at <= b.created_at
    group by a.user_id
  ),
  per_user_reports as (
    select
      user_id,
      count(*)::int as report_count,
      count(*) filter (
        where extract(hour from (created_at at time zone 'Asia/Seoul')) >= 10
          and extract(hour from (created_at at time zone 'Asia/Seoul')) < 19
      )::int as reports_in_stamp_hours,
      count(*) filter (
        where extract(hour from (created_at at time zone 'Asia/Seoul')) < 10
           or extract(hour from (created_at at time zone 'Asia/Seoul')) >= 19
      )::int as reports_out_stamp_hours,
      array_agg(distinct device_install_id) filter (where device_install_id is not null) as device_ids
    from user_reports
    group by user_id
  ),
  same_stats as (
    select
      user_id,
      coalesce(jsonb_agg(gap_min order by gap_min), '[]'::jsonb) as intervals_min,
      round(avg(gap_min)::numeric, 2) as avg_min,
      round((percentile_cont(0.5) within group (order by gap_min))::numeric, 2) as median_min,
      round(min(gap_min)::numeric, 2) as min_min,
      round(max(gap_min)::numeric, 2) as max_min,
      count(*)::int as pair_count
    from same_store_gaps
    group by user_id
  ),
  all_stats as (
    select
      user_id,
      coalesce(jsonb_agg(gap_min order by gap_min), '[]'::jsonb) as intervals_min,
      round(avg(gap_min)::numeric, 2) as avg_min,
      round((percentile_cont(0.5) within group (order by gap_min))::numeric, 2) as median_min,
      count(*)::int as pair_count
    from all_gaps
    group by user_id
  ),
  move_stats as (
    select
      user_id,
      coalesce(jsonb_agg(meters order by meters), '[]'::jsonb) as meters_list,
      round(avg(meters)::numeric, 1) as avg_m,
      round((percentile_cont(0.5) within group (order by meters))::numeric, 1) as median_m,
      round(min(meters)::numeric, 1) as min_m,
      round(max(meters)::numeric, 1) as max_m,
      count(*)::int as pair_count
    from move_gaps
    group by user_id
  ),
  area_stats as (
    select
      user_id,
      count(*)::int as transition_count,
      coalesce(
        jsonb_agg(
          jsonb_build_object(
            'from_area', from_area,
            'to_area', to_area,
            'gap_min', gap_min
          )
          order by gap_min
        ),
        '[]'::jsonb
      ) as transitions
    from area_trans
    group by user_id
  ),
  attempts as (
    select
      user_id,
      count(*) filter (where outcome = 'success')::int as success_n,
      count(*) filter (where outcome = 'fail')::int as fail_n,
      coalesce(
        (
          select jsonb_object_agg(coalesce(nullif(trim(x.fail_reason), ''), '(empty)'), x.cnt)
          from (
            select fail_reason, count(*)::int as cnt
            from public.report_attempts ra2
            where ra2.user_id = ra.user_id
              and ra2.created_at >= v_since
              and ra2.outcome = 'fail'
            group by fail_reason
          ) x
        ),
        '{}'::jsonb
      ) as fail_reasons
    from public.report_attempts ra
    where created_at >= v_since
      and user_id is not null
    group by user_id
  ),
  dwell2 as (
    select
      user_id,
      coalesce(sum((metadata->>'dwell_ms')::bigint), 0)::bigint as dwell_ms_total,
      coalesce(
        (
          select jsonb_object_agg(s.screen, s.sum_ms)
          from (
            select
              coalesce(e2.metadata->>'screen', 'unknown') as screen,
              sum((e2.metadata->>'dwell_ms')::bigint) as sum_ms
            from public.analytics_events e2
            where e2.user_id = e.user_id
              and e2.event_type = 'screen_dwell'
              and e2.created_at >= v_since
            group by coalesce(e2.metadata->>'screen', 'unknown')
          ) s
        ),
        '{}'::jsonb
      ) as dwell_ms_by_screen
    from public.analytics_events e
    where e.event_type = 'screen_dwell'
      and e.created_at >= v_since
      and e.user_id is not null
    group by e.user_id
  ),
  engagement as (
    select
      user_id,
      count(*) filter (where event_type = 'detail_view')::int as detail_view_n,
      count(*) filter (where event_type = 'map_marker_click')::int as map_click_n,
      count(*) filter (where event_type = 'search_result_click')::int as search_click_n,
      count(*) filter (where event_type = 'banner_click')::int as banner_click_n,
      count(*) filter (where event_type = 'app_session')::int as app_session_n,
      count(*) filter (
        where event_type in (
          'detail_view', 'map_marker_click', 'search_result_click',
          'banner_click', 'app_session'
        )
      )::int as non_report_event_n
    from public.analytics_events
    where created_at >= v_since
      and user_id is not null
    group by user_id
  ),
  device_map as (
    select
      device_install_id,
      array_agg(distinct user_id) as user_ids,
      count(distinct user_id)::int as user_count
    from (
      select user_id, unnest(device_ids) as device_install_id
      from per_user_reports
      where device_ids is not null
      union
      select user_id, device_install_id
      from public.report_attempts
      where created_at >= v_since
        and user_id is not null
        and nullif(trim(coalesce(device_install_id, '')), '') is not null
    ) x
    where device_install_id is not null
    group by device_install_id
  ),
  device_siblings as (
    select
      u.uid as user_id,
      max(d.user_count) as max_device_user_count,
      (
        select coalesce(jsonb_agg(distinct sib), '[]'::jsonb)
        from device_map d2
        cross join lateral unnest(d2.user_ids) as sib
        where u.uid = any (d2.user_ids)
          and sib <> u.uid
      ) as sibling_user_ids
    from (
      select distinct unnest(user_ids) as uid from device_map
    ) u
    join device_map d on u.uid = any (d.user_ids)
    group by u.uid
  )
  select coalesce(jsonb_agg(
    jsonb_build_object(
      'user_id', u.id,
      'nickname', coalesce(u.nickname, ''),
      'email', coalesce(u.email, ''),
      'report_count', coalesce(pr.report_count, 0),
      'same_store_interval_pair_count', coalesce(ss.pair_count, 0),
      'same_store_interval_avg_min', ss.avg_min,
      'same_store_interval_median_min', ss.median_min,
      'same_store_interval_min_min', ss.min_min,
      'same_store_interval_max_min', ss.max_min,
      'same_store_intervals_min', coalesce(ss.intervals_min, '[]'::jsonb),
      'all_report_interval_pair_count', coalesce(ag.pair_count, 0),
      'all_report_interval_avg_min', ag.avg_min,
      'all_report_interval_median_min', ag.median_min,
      'all_report_intervals_min', coalesce(ag.intervals_min, '[]'::jsonb),
      'move_pair_count', coalesce(mv.pair_count, 0),
      'move_avg_m', mv.avg_m,
      'move_median_m', mv.median_m,
      'move_min_m', mv.min_m,
      'move_max_m', mv.max_m,
      'move_meters', coalesce(mv.meters_list, '[]'::jsonb),
      'area_transition_count', coalesce(ar.transition_count, 0),
      'area_transitions', coalesce(ar.transitions, '[]'::jsonb),
      'peer_agree_count', coalesce(pe.agree_count, 0),
      'peer_overlap_count', coalesce(pe.overlap_count, 0),
      'device_ids', to_jsonb(coalesce(pr.device_ids, array[]::text[])),
      'device_sibling_user_count', coalesce(jsonb_array_length(ds.sibling_user_ids), 0),
      'device_sibling_user_ids', coalesce(ds.sibling_user_ids, '[]'::jsonb),
      'device_max_accounts_on_shared', coalesce(ds.max_device_user_count, 1),
      'attempt_success', coalesce(at.success_n, 0),
      'attempt_fail', coalesce(at.fail_n, 0),
      'fail_reasons', coalesce(at.fail_reasons, '{}'::jsonb),
      'dwell_ms_total', coalesce(dw.dwell_ms_total, 0),
      'dwell_ms_by_screen', coalesce(dw.dwell_ms_by_screen, '{}'::jsonb),
      'detail_view_n', coalesce(eg.detail_view_n, 0),
      'map_click_n', coalesce(eg.map_click_n, 0),
      'search_click_n', coalesce(eg.search_click_n, 0),
      'banner_click_n', coalesce(eg.banner_click_n, 0),
      'app_session_n', coalesce(eg.app_session_n, 0),
      'non_report_event_n', coalesce(eg.non_report_event_n, 0),
      'reports_in_stamp_hours', coalesce(pr.reports_in_stamp_hours, 0),
      'reports_out_stamp_hours', coalesce(pr.reports_out_stamp_hours, 0)
    )
    order by coalesce(pr.report_count, 0) desc, coalesce(u.nickname, '')
  ), '[]'::jsonb)
  into v_rows
  from public.users u
  left join per_user_reports pr on pr.user_id = u.id
  left join same_stats ss on ss.user_id = u.id
  left join all_stats ag on ag.user_id = u.id
  left join move_stats mv on mv.user_id = u.id
  left join area_stats ar on ar.user_id = u.id
  left join peer pe on pe.user_id = u.id
  left join attempts at on at.user_id = u.id
  left join dwell2 dw on dw.user_id = u.id
  left join engagement eg on eg.user_id = u.id
  left join device_siblings ds on ds.user_id = u.id
  where u.role = 'user'
    and (
      coalesce(pr.report_count, 0) > 0
      or coalesce(at.fail_n, 0) > 0
      or coalesce(at.success_n, 0) > 0
      or coalesce(dw.dwell_ms_total, 0) > 0
    );

  return jsonb_build_object(
    'days', v_days,
    'since', v_since,
    'users', coalesce(v_rows, '[]'::jsonb),
    'fields', jsonb_build_array(
      'same_store_intervals_min: 같은 매장 연속 제보 간격(분) 배열',
      'move_meters: 연속 제보 간 이동 거리(m) 배열',
      'area_transitions: 구역 변경 + 간격(분)',
      'peer_agree_count / peer_overlap_count: 10분 내 타유저 동시점·일치',
      'device_*: 동일 기기 계정',
      'attempt_* / fail_reasons: 제보 시도·실패',
      'dwell_ms_*: 화면 체류',
      'reports_in/out_stamp_hours: 스탬프 시간대(10–19 KST) 안/밖 제보 수'
    )
  );
end;
$$;

revoke all on function public.admin_trust_signals_report(int) from public;
grant execute on function public.admin_trust_signals_report(int) to authenticated;

-- ── 4. 유저 상세 (간격 샘플·최근 제보) ───────────────────────────
create or replace function public.admin_trust_signals_user(
  p_user_id uuid,
  p_days int default 30
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_admin uuid := auth.uid();
  v_days int := greatest(1, least(coalesce(p_days, 30), 90));
  v_since timestamptz := now() - make_interval(days => greatest(1, least(coalesce(p_days, 30), 90)));
  v_summary jsonb;
  v_reports jsonb;
  v_attempts jsonb;
begin
  if not exists (
    select 1 from public.users u
    where u.id = v_admin and u.role = 'admin'
  ) then
    raise exception '관리자만 조회할 수 있어요.';
  end if;

  if p_user_id is null then
    raise exception 'user_id가 필요해요.';
  end if;

  select u
  into v_summary
  from jsonb_array_elements(
    (public.admin_trust_signals_report(v_days))->'users'
  ) u
  where u->>'user_id' = p_user_id::text
  limit 1;

  select coalesce(jsonb_agg(
    jsonb_build_object(
      'id', cr.id,
      'restaurant_id', cr.restaurant_id,
      'restaurant_name', r.name,
      'area', r.area,
      'level', public.report_row_level(cr.metadata, cr.level::text),
      'lat', case
        when (cr.metadata->>'lat') ~ '^-?[0-9]+(\\.[0-9]+)?$'
        then (cr.metadata->>'lat')::double precision
      end,
      'lng', case
        when (cr.metadata->>'lng') ~ '^-?[0-9]+(\\.[0-9]+)?$'
        then (cr.metadata->>'lng')::double precision
      end,
      'device_install_id', cr.metadata->>'device_install_id',
      'app_session_id', cr.metadata->>'app_session_id',
      'created_at', cr.created_at
    )
    order by cr.created_at desc
  ), '[]'::jsonb)
  into v_reports
  from public.crowd_reports cr
  join public.restaurants r on r.id = cr.restaurant_id
  where cr.user_id = p_user_id
    and cr.source = 'user'::public.crowd_source
    and cr.created_at >= v_since;

  select coalesce(jsonb_agg(
    jsonb_build_object(
      'outcome', ra.outcome,
      'fail_reason', ra.fail_reason,
      'restaurant_id', ra.restaurant_id,
      'device_install_id', ra.device_install_id,
      'created_at', ra.created_at
    )
    order by ra.created_at desc
  ), '[]'::jsonb)
  into v_attempts
  from public.report_attempts ra
  where ra.user_id = p_user_id
    and ra.created_at >= v_since;

  return jsonb_build_object(
    'days', v_days,
    'since', v_since,
    'summary', coalesce(v_summary, jsonb_build_object('user_id', p_user_id)),
    'recent_reports', coalesce(v_reports, '[]'::jsonb),
    'recent_attempts', coalesce(v_attempts, '[]'::jsonb)
  );
end;
$$;

revoke all on function public.admin_trust_signals_user(uuid, int) from public;
grant execute on function public.admin_trust_signals_user(uuid, int) to authenticated;

comment on function public.admin_trust_signals_report(int) is
  '어드민: 신뢰·어뷰징용 원본 수치 지표 (점수 없음)';
comment on function public.admin_trust_signals_user(uuid, int) is
  '어드민: 유저별 신뢰·어뷰징 원본 지표 상세';

select 'trust_abuse_scoring.sql ok (signals only)' as status;
