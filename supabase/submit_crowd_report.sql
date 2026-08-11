-- 제보 RPC 정본 (Dashboard → SQL Editor → Run)
-- 스탬프 + user/owner 공통 50m + 5분 쿨다운 + advisory lock
--
-- 이 파일만 submit_crowd_report 를 CREATE OR REPLACE 한다.
-- crowd_status.sql / rewards.sql 을 다시 돌려도 이 함수는 덮이지 않는다.
-- 이후 제보 규칙을 바꿀 때도 여기만 수정할 것.

create or replace function public.submit_crowd_report(
  p_restaurant_id uuid,
  p_status        text,
  p_source        text default 'user',
  p_lat           double precision default null,
  p_lng           double precision default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid        uuid := auth.uid();
  v_lat        double precision;
  v_lng        double precision;
  v_distance   double precision;
  v_level      public.crowd_level;
  v_source     public.crowd_source;
  v_ui_level   int;
  v_stamp_result jsonb;
  v_description jsonb;
  v_session_start timestamptz;
  v_had_report_this_session boolean;
  v_stamp_count int;
begin
  if v_uid is null then
    raise exception '로그인이 필요해요.';
  end if;

  perform pg_advisory_xact_lock(
    hashtextextended(v_uid::text || ':' || p_restaurant_id::text, 0)
  );

  if p_status not in ('여유로움', '약간혼잡', '자리없음') then
    raise exception '유효하지 않은 혼잡도예요.';
  end if;

  v_ui_level := public.ui_status_to_level(p_status);

  if p_source not in ('user', 'owner') then
    raise exception '유효하지 않은 제보 유형이에요.';
  end if;

  v_level  := public.ui_level_to_crowd_level(v_ui_level);
  v_source := public.text_to_crowd_source(p_source);

  if p_source = 'owner' then
    if not exists (
      select 1 from public.restaurants r
      where r.id = p_restaurant_id
        and r.is_active = true
        and r.owner_id = v_uid
    ) then
      raise exception '본인 매장만 변경할 수 있어요.';
    end if;
  end if;

  if p_source = 'user' then
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
  end if;

  if p_lat is null or p_lng is null then
    raise exception '현재 위치를 확인할 수 없어요. 위치 권한을 확인해주세요.';
  end if;

  select r.latitude, r.longitude
  into v_lat, v_lng
  from public.restaurants r
  where r.id = p_restaurant_id;

  if v_lat is null or v_lng is null then
    raise exception '식당 위치 정보가 없어요.';
  end if;

  v_distance := public.haversine_meters(p_lat, p_lng, v_lat, v_lng);
  if v_distance > 50 then
    raise exception '식당 근처에서만 혼잡도를 제보할 수 있어요.';
  end if;

  if p_source = 'user' then
    select r.description into v_description
    from public.restaurants r
    where r.id = p_restaurant_id;

    v_session_start := public.restaurant_current_session_start(v_description, now());

    select exists (
      select 1 from public.crowd_reports cr
      where cr.restaurant_id = p_restaurant_id
        and cr.created_at >= coalesce(v_session_start, '-infinity'::timestamptz)
    ) into v_had_report_this_session;
  end if;

  insert into public.crowd_reports (
    restaurant_id, level, source, user_id, metadata
  ) values (
    p_restaurant_id,
    v_level,
    v_source,
    v_uid,
    jsonb_build_object(
      'status', p_status,
      'user_id', v_uid::text,
      'lat', p_lat,
      'lng', p_lng
    )
  );

  if p_source = 'user' then
    v_stamp_count := case when v_had_report_this_session then 1 else 2 end;
    v_stamp_result := public.grant_stamp(v_uid, v_stamp_count);
  else
    v_stamp_result := jsonb_build_object(
      'granted', false,
      'today_stamps', 0,
      'total_stamps', 0
    );
  end if;

  return v_stamp_result;
end;
$$;

grant execute on function public.submit_crowd_report(uuid, text, text, double precision, double precision)
  to authenticated;

comment on function public.submit_crowd_report is
  '제보 정본. 스탬프 + 50m(user/owner) + user 5분 쿨다운. 디버그 빌드는 클라이언트가 매장 좌표를 보내 거리 0m.';

select 'submit_crowd_report.sql ok' as status;
