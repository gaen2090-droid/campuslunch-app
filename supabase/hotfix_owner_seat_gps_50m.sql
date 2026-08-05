-- 사장님 입장 가능 인원 입력에도 혼잡도 제보와 동일하게 50m GPS 검증
-- Dashboard → SQL Editor → Run

drop function if exists public.submit_owner_seat_update(uuid, integer);

create or replace function public.submit_owner_seat_update(
  p_restaurant_id uuid,
  p_available_seats integer,
  p_lat double precision default null,
  p_lng double precision default null
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_id uuid;
  v_lat double precision;
  v_lng double precision;
  v_distance double precision;
begin
  if v_uid is null then
    raise exception '로그인이 필요해요.';
  end if;

  if p_available_seats is null or p_available_seats < 0 then
    raise exception '0 이상의 정수만 입력할 수 있어요.';
  end if;

  if not public.is_restaurant_owner(p_restaurant_id) then
    raise exception '본인 매장만 입력할 수 있어요.';
  end if;

  if p_lat is null or p_lng is null then
    raise exception '현재 위치를 확인할 수 없어요. 위치 권한을 확인해주세요.';
  end if;

  select r.latitude, r.longitude
    into v_lat, v_lng
  from public.restaurants r
  where r.id = p_restaurant_id
    and r.is_active = true;

  if v_lat is null or v_lng is null then
    raise exception '식당 위치 정보가 없어요.';
  end if;

  v_distance := public.haversine_meters(p_lat, p_lng, v_lat, v_lng);
  if v_distance > 50 then
    raise exception '매장 근처에서만 입장 가능 인원을 입력할 수 있어요.';
  end if;

  insert into public.owner_seat_updates (
    restaurant_id,
    owner_id,
    available_seats
  )
  values (
    p_restaurant_id,
    v_uid,
    p_available_seats
  )
  returning id into v_id;

  return v_id;
end;
$$;

grant execute on function public.submit_owner_seat_update(uuid, integer, double precision, double precision)
  to authenticated;

comment on function public.submit_owner_seat_update(uuid, integer, double precision, double precision) is
  '사장님 입장 가능 인원 반영. 혼잡도 제보와 동일하게 매장 반경 50m GPS 검증.';
