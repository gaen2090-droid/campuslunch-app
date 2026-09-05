-- 제보 RPC 정본 (Dashboard → SQL Editor → Run)
-- 스탬프 + user/owner 공통 50m + 5분 쿨다운 + advisory lock + 제보 정지 체크
--
-- ⚠️ 2026-09 확인: 이 파일의 "이 파일만 CREATE OR REPLACE 한다" 주장은 더 이상 사실이
-- 아니다. crowd_enabled_two_tier.sql이 이후 배포 순서상 이 함수를 다시 재정의하며
-- crowd_enabled 체크를 추가한 진짜 최신 정본이다. submit_crowd_report 로직을 바꿀 때는
-- 반드시 crowd_enabled_two_tier.sql도 동일하게 갱신할 것 (이 파일은 여전히 남겨두되
-- 두 파일을 항상 같이 고칠 것 — 실제로 2026-08-25 이 둘이 갈라져 사고가 난 적 있음).
--
-- 이 파일만 submit_crowd_report 를 CREATE OR REPLACE 한다.
-- crowd_status.sql / rewards.sql 을 다시 돌려도 이 함수는 덮이지 않는다.
-- 이후 제보 규칙을 바꿀 때도 여기만 수정할 것.
--
-- user_suspension.sql을 먼저 실행해 is_report_suspended()가 있어야 한다.
-- stats_excluded_users.sql을 먼저 실행해 is_stats_excluded()가 있어야 한다.
-- trust_abuse: metadata에 device_install_id / app_session_id (선택).
--
-- 통계 제외 계정(is_stats_excluded)은 제보 정지·5분 쿨다운·GPS(위치) 체크를
-- 전부 건너뛰고 스탬프도 지급하지 않는다. crowd_reports insert는 정상 수행되어
-- 다른 사용자 화면(혼잡도)에는 그대로 실시간 반영된다.

-- 오버로드 충돌 방지 (인자 개수가 다른 옛 정의 제거)
drop function if exists public.submit_crowd_report(uuid, text, text, double precision, double precision);
drop function if exists public.submit_crowd_report(uuid, text, text, double precision, double precision, text, text);

create or replace function public.submit_crowd_report(
  p_restaurant_id uuid,
  p_status        text,
  p_source        text default 'user',
  p_lat           double precision default null,
  p_lng           double precision default null,
  p_device_install_id text default null,
  p_app_session_id    text default null
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
  v_meta jsonb;
  v_stats_excluded boolean;
begin
  if v_uid is null then
    raise exception '로그인이 필요해요.';
  end if;

  v_stats_excluded := public.is_stats_excluded(v_uid);

  if not v_stats_excluded and p_source = 'user' and public.is_report_suspended(v_uid) then
    raise exception '제보 기능 이용이 일시적으로 제한됐어요.';
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

  if not v_stats_excluded and p_source = 'user' then
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

  if not v_stats_excluded and (p_lat is null or p_lng is null) then
    raise exception '현재 위치를 확인할 수 없어요. 위치 권한을 확인해주세요.';
  end if;

  select r.latitude, r.longitude
  into v_lat, v_lng
  from public.restaurants r
  where r.id = p_restaurant_id;

  if not v_stats_excluded and (v_lat is null or v_lng is null) then
    raise exception '식당 위치 정보가 없어요.';
  end if;

  if not v_stats_excluded then
    v_distance := public.haversine_meters(p_lat, p_lng, v_lat, v_lng);
    if v_distance > 50 then
      raise exception '식당 근처에서만 혼잡도를 제보할 수 있어요.';
    end if;
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

  v_meta := jsonb_build_object(
    'status', p_status,
    'user_id', v_uid::text,
    'lat', p_lat,
    'lng', p_lng
  );
  if nullif(trim(coalesce(p_device_install_id, '')), '') is not null then
    v_meta := v_meta || jsonb_build_object(
      'device_install_id', trim(p_device_install_id)
    );
  end if;
  if nullif(trim(coalesce(p_app_session_id, '')), '') is not null then
    v_meta := v_meta || jsonb_build_object(
      'app_session_id', trim(p_app_session_id)
    );
  end if;

  insert into public.crowd_reports (
    restaurant_id, level, source, user_id, metadata
  ) values (
    p_restaurant_id,
    v_level,
    v_source,
    v_uid,
    v_meta
  );

  if v_stats_excluded then
    v_stamp_result := jsonb_build_object(
      'granted', false,
      'today_stamps', 0,
      'total_stamps', 0
    );
  elsif p_source = 'user' then
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

grant execute on function public.submit_crowd_report(
  uuid, text, text, double precision, double precision, text, text
) to authenticated;

comment on function public.submit_crowd_report is
  '제보 정본. 스탬프 + 50m(user/owner) + user 5분 쿨다운. metadata에 device_install_id·app_session_id 선택. is_stats_excluded 계정은 제한 전부 면제(스탬프 미지급).';

select 'submit_crowd_report.sql ok' as status;
