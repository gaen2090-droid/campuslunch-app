-- 사장님 통계: 매장 상세페이지 방문(조회) 수 — 오늘/누적
-- (Dashboard → SQL Editor → Run, owner_search_click_stats.sql 이후)

-- ── 1. event_type에 상세페이지 조회 추가 ──
alter table public.analytics_events drop constraint if exists analytics_events_event_type_check;
alter table public.analytics_events
  add constraint analytics_events_event_type_check
  check (event_type in (
    'app_session', 'banner_impression', 'banner_click',
    'push_delivered', 'push_click',
    'map_marker_click', 'search_result_click', 'detail_view'
  ));

-- ── 2. 지도 마커 클릭 / 검색결과 클릭 기록 RPC (이전 파일에서 이미 만들었다면 재실행 안전) ──
create or replace function public.record_map_marker_click(p_restaurant_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  uid uuid := auth.uid();
begin
  if uid is null or p_restaurant_id is null then
    return;
  end if;

  insert into public.analytics_events (user_id, event_type, restaurant_id)
  values (uid, 'map_marker_click', p_restaurant_id);
end;
$$;

revoke all on function public.record_map_marker_click(uuid) from public;
grant execute on function public.record_map_marker_click(uuid) to authenticated;

create or replace function public.record_search_result_click(p_restaurant_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  uid uuid := auth.uid();
begin
  if uid is null or p_restaurant_id is null then
    return;
  end if;

  insert into public.analytics_events (user_id, event_type, restaurant_id)
  values (uid, 'search_result_click', p_restaurant_id);
end;
$$;

revoke all on function public.record_search_result_click(uuid) from public;
grant execute on function public.record_search_result_click(uuid) to authenticated;

-- ── 3. 매장 상세페이지 진입 시 기록 (사장님 본인 매장 미리보기는 클라이언트에서 제외하고 호출) ──
create or replace function public.record_detail_view(p_restaurant_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  uid uuid := auth.uid();
begin
  if uid is null or p_restaurant_id is null then
    return;
  end if;

  insert into public.analytics_events (user_id, event_type, restaurant_id)
  values (uid, 'detail_view', p_restaurant_id);
end;
$$;

revoke all on function public.record_detail_view(uuid) from public;
grant execute on function public.record_detail_view(uuid) to authenticated;

-- ── 4. 사장님 통계 RPC에 오늘/누적 상세페이지 방문수 추가 ──
-- 반환 컬럼 구성이 바뀌어 CREATE OR REPLACE로는 안 되므로 먼저 DROP.
drop function if exists public.owner_restaurant_engagement_stats(uuid);

create or replace function public.owner_restaurant_engagement_stats(p_restaurant_id uuid)
returns table (
  today_map_clicks int,
  total_map_clicks int,
  today_reports int,
  total_search_clicks int,
  today_detail_views int,
  total_detail_views int
)
language sql
stable
security definer
set search_path = public
as $$
  select
    (
      select count(*)::int from public.analytics_events e
      where e.restaurant_id = p_restaurant_id
        and e.event_type = 'map_marker_click'
        and e.created_at >= (date_trunc('day', now() at time zone 'Asia/Seoul') at time zone 'Asia/Seoul')
    ) as today_map_clicks,
    (
      select count(*)::int from public.analytics_events e
      where e.restaurant_id = p_restaurant_id
        and e.event_type = 'map_marker_click'
    ) as total_map_clicks,
    (
      select count(*)::int from public.crowd_reports cr
      where cr.restaurant_id = p_restaurant_id
        and cr.source = 'user'::public.crowd_source
        and cr.created_at >= (date_trunc('day', now() at time zone 'Asia/Seoul') at time zone 'Asia/Seoul')
    ) as today_reports,
    (
      select count(*)::int from public.analytics_events e
      where e.restaurant_id = p_restaurant_id
        and e.event_type = 'search_result_click'
    ) as total_search_clicks,
    (
      select count(*)::int from public.analytics_events e
      where e.restaurant_id = p_restaurant_id
        and e.event_type = 'detail_view'
        and e.created_at >= (date_trunc('day', now() at time zone 'Asia/Seoul') at time zone 'Asia/Seoul')
    ) as today_detail_views,
    (
      select count(*)::int from public.analytics_events e
      where e.restaurant_id = p_restaurant_id
        and e.event_type = 'detail_view'
    ) as total_detail_views
  where exists (
    select 1 from public.restaurants r
    where r.id = p_restaurant_id and r.owner_id = auth.uid()
  );
$$;

grant execute on function public.owner_restaurant_engagement_stats(uuid) to authenticated;

select 'owner_detail_view_stats.sql ok' as status;
