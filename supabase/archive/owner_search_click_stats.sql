-- ⚠️ 구버전 — owner_detail_view_stats.sql 이 이 파일의 내용을 전부 포함해서 대체함.
-- 이 파일은 실행하지 말고 owner_detail_view_stats.sql 하나만 실행할 것.
--
-- 사장님 통계: 홈/지도 검색 결과에서 이 매장을 선택(클릭)한 누적 수
-- (Dashboard → SQL Editor → Run, owner_map_click_stats.sql 이후)

-- ── 1. event_type에 검색 결과 클릭 추가 ──
alter table public.analytics_events drop constraint if exists analytics_events_event_type_check;
alter table public.analytics_events
  add constraint analytics_events_event_type_check
  check (event_type in (
    'app_session', 'banner_impression', 'banner_click',
    'push_delivered', 'push_click',
    'map_marker_click', 'search_result_click'
  ));

-- ── 2. 홈/지도 검색 결과에서 매장 선택 시 기록 ──
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

-- ── 3. 사장님 통계 RPC에 누적 검색수 추가 ──
create or replace function public.owner_restaurant_engagement_stats(p_restaurant_id uuid)
returns table (
  today_map_clicks int,
  total_map_clicks int,
  today_reports int,
  total_search_clicks int
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
    ) as total_search_clicks
  where exists (
    select 1 from public.restaurants r
    where r.id = p_restaurant_id and r.owner_id = auth.uid()
  );
$$;

grant execute on function public.owner_restaurant_engagement_stats(uuid) to authenticated;

select 'owner_search_click_stats.sql ok' as status;
