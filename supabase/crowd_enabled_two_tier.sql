-- 매장 2-Tier 분리: 제보 대상 매장 / 맛집컬렉션 전용 매장 (Dashboard → SQL Editor → Run)
-- docs/PLAN_two_tier_restaurants.md 반영
--
-- is_active(행이 살아있는지/앱 전체 노출 여부)와는 독립된 축.
-- crowd_enabled=false 매장은 is_active=true로 앱에 정상 노출되지만
-- 지도/홈 평소 목록에는 안 뜨고(클라이언트에서 필터), 혼잡도 제보 기능이 꺼진다.
--
-- ⚠️ 실행 순서: owner_code_cleanup.sql, owner_application_reject_push.sql 이후 실행할 것.
-- 이 파일은 admin_review_owner_application을 owner_application_reject_push.sql의 최신 본문
-- (승인/반려 푸시 발송 포함) 기반으로 재정의한다 — 더 이전 버전을 베이스로 하면 푸시 발송
-- 로직이 사라진다. submit_crowd_report도 최신 정본(trust_abuse용 7인자,
-- device_install_id/app_session_id 포함) 기반. 이 파일 이후에
-- crowd_enabled_sweep_filter.sql을 실행한다.
-- ⚠️ 2026-08-25 사고 기록: 이 파일을 구버전(5인자) submit_crowd_report 본문으로 실행해
-- trust_abuse 파라미터가 DB에서 사라진 적이 있음 → crowd_enabled_submit_report_fix.sql로
-- 복구. submit_crowd_report.sql이 나중에 다시 바뀌면 이 파일도 함께 갱신할 것.

alter table public.restaurants
  add column if not exists crowd_enabled boolean not null default true;

-- 제보 RPC 서버단 방어: crowd_enabled=false 매장은 제보 자체를 거부.
-- (버튼은 클라이언트에서 숨기지만, 우회 호출 대비 서버가 최종 방어선)
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
  v_crowd_enabled boolean;
begin
  if v_uid is null then
    raise exception '로그인이 필요해요.';
  end if;

  if p_source = 'user' and public.is_report_suspended(v_uid) then
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

  select r.crowd_enabled into v_crowd_enabled
  from public.restaurants r
  where r.id = p_restaurant_id;

  if v_crowd_enabled is null or v_crowd_enabled = false then
    raise exception '아직 혼잡도 제보를 지원하지 않는 매장이에요.';
  end if;

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

grant execute on function public.submit_crowd_report(
  uuid, text, text, double precision, double precision, text, text
) to authenticated;

comment on function public.submit_crowd_report is
  '제보 정본. 스탬프 + 50m(user/owner) + user 5분 쿨다운 + crowd_enabled 매장만 허용. metadata에 device_install_id·app_session_id 선택.';

-- 사장님 인증 승인 시 자동으로 제보 대상으로 승격 (crowd_enabled=true)
-- 주의: claim_owner_by_code는 6자리 코드 방식 폐지(owner_code_cleanup.sql)로 이미 drop됨.
-- 실제 사장님 승인 경로는 admin_review_owner_application이며, 가장 최신 정의는
-- owner_application_reject_push.sql(승인/반려 푸시 발송 포함)이므로 그 본문을 그대로
-- 베이스로 승격 로직만 추가한다 — owner_applications.sql 원본을 베이스로 하면 안 됨
-- (푸시 발송 로직이 통째로 사라짐).
create or replace function public.admin_review_owner_application(
  p_application_id uuid,
  p_approve        boolean,
  p_reject_reason  text default null
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_app public.owner_applications;
  edge_url text;
  edge_secret text;
begin
  if not public.is_admin() then
    raise exception '관리자만 처리할 수 있어요.';
  end if;

  select * into v_app
  from public.owner_applications
  where id = p_application_id
  for update;

  if not found then
    raise exception '신청 내역을 찾을 수 없어요.';
  end if;

  if v_app.status <> 'pending' then
    raise exception '이미 처리된 신청이에요.';
  end if;

  if p_approve then
    if exists (
      select 1 from public.restaurants r
      where r.id = v_app.restaurant_id and r.owner_id is not null
    ) then
      raise exception '이미 사장님이 등록된 매장이에요.';
    end if;

    update public.restaurants
    set owner_id = v_app.user_id,
        crowd_enabled = true
    where id = v_app.restaurant_id;

    update public.owner_applications
    set status = 'approved',
        reviewed_by = auth.uid(),
        reviewed_at = now()
    where id = p_application_id;

    if v_app.notify_push then
      begin
        select c.community_url, c.push_secret
          into edge_url, edge_secret
        from public.push_edge_runtime_config c
        where c.id = 1;
        if edge_url is not null and edge_secret is not null then
          perform net.http_post(
            url := edge_url,
            headers := jsonb_build_object(
              'Content-Type', 'application/json',
              'Authorization', coalesce('Bearer ' || edge_secret, '')
            ),
            body := jsonb_build_object(
              'event', 'owner_approved',
              'user_id', v_app.user_id,
              'restaurant_id', v_app.restaurant_id
            )
          );
        end if;
      exception
        when others then
          -- 푸시 실패가 승인 처리를 막지 않는다.
          raise warning 'owner approval push webhook failed: %', sqlerrm;
      end;
    end if;
  else
    update public.owner_applications
    set status = 'rejected',
        reject_reason = p_reject_reason,
        reviewed_by = auth.uid(),
        reviewed_at = now()
    where id = p_application_id;

    if v_app.notify_push then
      begin
        select c.community_url, c.push_secret
          into edge_url, edge_secret
        from public.push_edge_runtime_config c
        where c.id = 1;
        if edge_url is not null and edge_secret is not null then
          perform net.http_post(
            url := edge_url,
            headers := jsonb_build_object(
              'Content-Type', 'application/json',
              'Authorization', coalesce('Bearer ' || edge_secret, '')
            ),
            body := jsonb_build_object(
              'event', 'owner_rejected',
              'user_id', v_app.user_id
            )
          );
        end if;
      exception
        when others then
          -- 푸시 실패가 반려 처리를 막지 않는다.
          raise warning 'owner rejection push webhook failed: %', sqlerrm;
      end;
    end if;
  end if;
end;
$$;

revoke all on function public.admin_review_owner_application(uuid, boolean, text) from public;
grant execute on function public.admin_review_owner_application(uuid, boolean, text) to authenticated;

select 'crowd_enabled_two_tier.sql ok' as status;
