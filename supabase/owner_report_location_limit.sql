-- 사장님 제보에도 위치 제한(50m) 적용 (Dashboard → SQL Editor → Run)
--
-- 기존 submit_crowd_report는 p_source = 'user'일 때만 위치(80m) 검증을 했고,
-- p_source = 'owner'는 소유권(owner_id) 검증만 하고 위치 검증이 아예 없었다.
-- 사장님 제보도 매장 근처(50m)에서만 가능하도록 위치 검증을 추가하고,
-- 클라이언트(app_provider.dart)와 동일하게 임계값을 50m로 통일한다.
-- 5분 쿨다운은 기존대로 사장님 예외 유지(변경 없음).

drop function if exists public.submit_crowd_report(uuid, text, text, double precision, double precision);

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

  if p_status not in ('여유로움', '약간혼잡', '자리없음', '웨이팅많음') then
    raise exception '유효하지 않은 혼잡도예요.';
  end if;

  v_ui_level := public.ui_status_to_level(p_status);

  if p_source not in ('user', 'owner') then
    raise exception '유효하지 않은 제보 유형이에요.';
  end if;

  v_level := public.ui_level_to_crowd_level(v_ui_level);
  v_source := public.text_to_crowd_source(p_source);

  if p_source = 'owner' then
    if not exists (
      select 1
      from public.restaurants r
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

  -- 위치 제한(50m)은 user/owner 공통 적용.
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
      'status', p_status,
      'user_id', v_uid::text,
      'lat', p_lat,
      'lng', p_lng
    )
  );
end;
$$;

grant execute on function public.submit_crowd_report(uuid, text, text, double precision, double precision)
  to authenticated;

-- 확인 (Success 나오면 OK)
select 'ok' as result;
