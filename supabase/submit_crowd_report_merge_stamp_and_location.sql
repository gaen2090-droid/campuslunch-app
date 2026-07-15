-- submit_crowd_report 최종 통합본: 위치검증(50m) + 스탬프 지급 (Dashboard → SQL Editor → Run)
--
-- 문제: owner_report_location_limit.sql 실행 시 동일 시그니처의 submit_crowd_report를
-- drop 후 재정의하면서, rewards.sql이 정의했던 스탬프 지급 로직(grant_stamp 호출,
-- returns jsonb)이 통째로 사라지고 위치검증만 하는 returns void 버전으로 교체됐다.
-- 그 결과 제보는 성공하지만 스탬프가 전혀 지급되지 않았다.
--
-- 이 파일은 두 버전을 하나로 병합한 최종본이다. 이후 submit_crowd_report를 다시 수정할 때는
-- crowd_status.sql / hotfix_crowd_report_types.sql / owner_report_location_limit.sql /
-- rewards.sql 이 아니라 반드시 이 파일을 갱신해서 실행할 것.
--
-- 위치(50m)는 user/owner 공통 적용. 디버그 빌드는 클라이언트가 매장 좌표를 그대로
-- 전송하므로(app_provider.dart) 거리 0m로 항상 통과한다.

drop function if exists public.submit_crowd_report(uuid, text, text, double precision, double precision);

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

  if p_status not in ('여유로움', '약간혼잡', '자리없음', '웨이팅많음') then
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

  -- 쿨다운(같은 매장 5분 재제보 금지) — user 제보만 적용, 서버가 최종 방어선.
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

  -- 위치 제한(50m) — user/owner 공통 적용. 디버그 빌드는 클라이언트가 매장 좌표를
  -- 그대로 보내므로 거리 0m로 항상 통과한다.
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

  -- 영업 시작(이번 세션) 이후 기존 제보가 있었는지 확인 (최초 제보 보너스 판단)
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

  -- 사용자 제보에만 스탬프 지급. 영업 시작 후 최초 제보면 2개, 그 외엔 1개.
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

select 'submit_crowd_report_merge_stamp_and_location.sql ok' as status;
