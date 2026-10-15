-- 점메추 요정 / 식당 룰렛 운영 지표 (카톡 공유 버튼 CTR 포함)
-- analytics_events.sql, stats_excluded_users.sql 실행 후 Dashboard → SQL Editor → Run
--
-- 이벤트는 event_type='feature_event' 한 종류만 추가하고,
-- 어떤 기능의 어떤 동작인지는 metadata(feature, action)로 구분한다.
--
--   feature = 'fairy'    : open, result_shown, share_click, reroll, detail_click
--   feature = 'roulette' : open, preset_open, spin, result_shown,
--                          result_share_click, candidates_share_click, detail_click
--
-- ⚠️ push_analytics.sql 주석의 2026-09 사고(제약 재생성 시 기존 행 위반)를 피하려고
--    기존 이벤트 타입을 전부 포함하고, NOT VALID 로 기존 행은 재검사하지 않는다.
alter table public.analytics_events
  drop constraint if exists analytics_events_event_type_check;

alter table public.analytics_events
  add constraint analytics_events_event_type_check
  check (
    event_type in (
      'app_session',
      'banner_impression',
      'banner_click',
      'push_delivered',
      'push_click',
      'map_marker_click',
      'search_result_click',
      'detail_view',
      'screen_dwell',
      'feature_event'
    )
  ) not valid;

create index if not exists analytics_events_feature_created_idx
  on public.analytics_events (created_at desc)
  where event_type = 'feature_event';

-- ── 앱에서 기록 ──
create or replace function public.record_feature_event(
  p_feature text,
  p_action text,
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
  if p_feature not in ('fairy', 'roulette') then
    raise exception 'invalid feature';
  end if;
  if p_action not in (
    'open', 'preset_open', 'spin', 'result_shown',
    'share_click', 'result_share_click', 'candidates_share_click',
    'reroll', 'detail_click'
  ) then
    raise exception 'invalid feature action';
  end if;
  if public.is_stats_excluded(uid) then
    return;
  end if;

  meta := coalesce(p_metadata, '{}'::jsonb)
    || jsonb_build_object('feature', p_feature, 'action', p_action);

  insert into public.analytics_events (user_id, event_type, metadata)
  values (uid, 'feature_event', meta);
end;
$$;

revoke all on function public.record_feature_event(text, text, jsonb) from public;
grant execute on function public.record_feature_event(text, text, jsonb) to authenticated;

-- ── 어드민: 기능별 최근 7일 지표 ──
-- 반환: { "fairy": {...}, "roulette": {...} }
--   actions_7d / actions_prev_7d / actions_today : { action: 횟수 }
--   users_7d                                     : 7일간 사용(open) 사용자 수
--   share_users_7d                               : 공유 버튼을 누른 사용자 수
--   share_ctr_7d / share_ctr_prev_7d             : 결과 공유 클릭 ÷ 결과 노출 (%)
--   daily_7d                                     : [{result_shown, share_clicks}] 오래된 순
-- 결과 공유 클릭 = fairy 는 share_click, roulette 는 result_share_click.
create or replace function public.admin_feature_metrics()
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  tz constant text := 'Asia/Seoul';
  today_start timestamptz := date_trunc('day', now() at time zone tz) at time zone tz;
  week_start timestamptz := today_start - interval '6 days';
  prev_start timestamptz := today_start - interval '13 days';
  feat text;
  share_action text;
  result jsonb := '{}'::jsonb;
  a_7d jsonb;
  a_prev jsonb;
  a_today jsonb;
  daily jsonb;
  users_7d int;
  share_users int;
  shown_7d int;
  shared_7d int;
  shown_prev int;
  shared_prev int;
  ctr_7d numeric;
  ctr_prev numeric;
  i int;
  d_start timestamptz;
  d_end timestamptz;
  d_shown int;
  d_shared int;
begin
  if auth.uid() is null then
    raise exception 'login required';
  end if;
  if not public.is_admin() then
    raise exception 'admin only';
  end if;

  foreach feat in array array['fairy', 'roulette'] loop
    share_action := case feat when 'fairy' then 'share_click' else 'result_share_click' end;

    select coalesce(jsonb_object_agg(action, cnt), '{}'::jsonb) into a_7d
    from (
      select e.metadata->>'action' as action, count(*)::int as cnt
      from public.analytics_events e
      where e.event_type = 'feature_event'
        and e.metadata->>'feature' = feat
        and e.created_at >= week_start
        and e.created_at < today_start + interval '1 day'
      group by 1
    ) t;

    select coalesce(jsonb_object_agg(action, cnt), '{}'::jsonb) into a_prev
    from (
      select e.metadata->>'action' as action, count(*)::int as cnt
      from public.analytics_events e
      where e.event_type = 'feature_event'
        and e.metadata->>'feature' = feat
        and e.created_at >= prev_start
        and e.created_at < week_start
      group by 1
    ) t;

    select coalesce(jsonb_object_agg(action, cnt), '{}'::jsonb) into a_today
    from (
      select e.metadata->>'action' as action, count(*)::int as cnt
      from public.analytics_events e
      where e.event_type = 'feature_event'
        and e.metadata->>'feature' = feat
        and e.created_at >= today_start
        and e.created_at < today_start + interval '1 day'
      group by 1
    ) t;

    select count(distinct e.user_id)::int into users_7d
    from public.analytics_events e
    where e.event_type = 'feature_event'
      and e.metadata->>'feature' = feat
      and e.metadata->>'action' in ('open', 'preset_open')
      and e.created_at >= week_start
      and e.created_at < today_start + interval '1 day';

    select count(distinct e.user_id)::int into share_users
    from public.analytics_events e
    where e.event_type = 'feature_event'
      and e.metadata->>'feature' = feat
      and e.metadata->>'action' in (share_action, 'candidates_share_click')
      and e.created_at >= week_start
      and e.created_at < today_start + interval '1 day';

    shown_7d := coalesce((a_7d->>'result_shown')::int, 0);
    shared_7d := coalesce((a_7d->>share_action)::int, 0);
    shown_prev := coalesce((a_prev->>'result_shown')::int, 0);
    shared_prev := coalesce((a_prev->>share_action)::int, 0);
    ctr_7d := case when shown_7d > 0
      then round((shared_7d::numeric / shown_7d) * 1000) / 10 else 0 end;
    ctr_prev := case when shown_prev > 0
      then round((shared_prev::numeric / shown_prev) * 1000) / 10 else 0 end;

    daily := '[]'::jsonb;
    for i in 0..6 loop
      d_start := today_start - ((6 - i) * interval '1 day');
      d_end := d_start + interval '1 day';
      select
        count(*) filter (where e.metadata->>'action' = 'result_shown')::int,
        count(*) filter (where e.metadata->>'action' = share_action)::int
      into d_shown, d_shared
      from public.analytics_events e
      where e.event_type = 'feature_event'
        and e.metadata->>'feature' = feat
        and e.created_at >= d_start
        and e.created_at < d_end;
      daily := daily || jsonb_build_array(jsonb_build_object(
        'result_shown', coalesce(d_shown, 0),
        'share_clicks', coalesce(d_shared, 0)
      ));
    end loop;

    result := result || jsonb_build_object(feat, jsonb_build_object(
      'actions_7d', a_7d,
      'actions_prev_7d', a_prev,
      'actions_today', a_today,
      'users_7d', coalesce(users_7d, 0),
      'share_users_7d', coalesce(share_users, 0),
      'share_ctr_7d', ctr_7d,
      'share_ctr_prev_7d', ctr_prev,
      'daily_7d', daily
    ));
  end loop;

  return result;
end;
$$;

revoke all on function public.admin_feature_metrics() from public;
revoke all on function public.admin_feature_metrics() from anon;
grant execute on function public.admin_feature_metrics() to authenticated;
