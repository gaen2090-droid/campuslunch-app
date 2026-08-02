-- 사장님 인증 승인 알림: 신청 시 수신 방법(앱 푸시/문자, 복수 선택) 선택 →
-- 승인되는 즉시 앱 푸시 자동 발송. 문자는 자동화 없이 관리자가 전화번호로 수동 발송.
-- Dashboard → SQL Editor → Run (owner_applications.sql 이후)

-- ── 1. 컬럼 추가 ──
alter table public.owner_applications
  add column if not exists notify_push boolean not null default false,
  add column if not exists notify_sms  boolean not null default false;

-- ── 2. submit_owner_application: 파라미터 추가는 오버로드가 아닌 시그니처 교체 ──
-- (기존 (uuid, text, text, jsonb) 시그니처를 완전히 대체한다. 남겨두면 revoke/grant가
--  안 걸린 옛 오버로드가 남아 혼란을 준다.)
drop function if exists public.submit_owner_application(uuid, text, text, jsonb);

create or replace function public.submit_owner_application(
  p_restaurant_id uuid,
  p_phone         text,
  p_email         text,
  p_license_paths jsonb,
  p_notify_push   boolean default false,
  p_notify_sms    boolean default false
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_id  uuid;
begin
  if v_uid is null then
    raise exception '로그인이 필요해요.';
  end if;

  if p_phone is null or length(trim(p_phone)) = 0 then
    raise exception '전화번호를 입력해주세요.';
  end if;

  if p_email is null or length(trim(p_email)) = 0 then
    raise exception '이메일을 입력해주세요.';
  end if;

  if p_license_paths is null or jsonb_array_length(p_license_paths) = 0 then
    raise exception '사업자등록증을 첨부해주세요.';
  end if;

  if jsonb_array_length(p_license_paths) > 3 then
    raise exception '사업자등록증은 최대 3장까지 첨부할 수 있어요.';
  end if;

  if not exists (
    select 1 from public.restaurants r
    where r.id = p_restaurant_id and r.is_active = true
  ) then
    raise exception '존재하지 않는 매장이에요.';
  end if;

  if exists (
    select 1 from public.restaurants r
    where r.id = p_restaurant_id and r.owner_id is not null
  ) then
    raise exception '이미 사장님이 등록된 매장이에요.';
  end if;

  if exists (
    select 1 from public.owner_applications oa
    where oa.restaurant_id = p_restaurant_id and oa.status = 'pending'
  ) then
    raise exception '이미 심사 중인 신청이 있는 매장이에요.';
  end if;

  if exists (
    select 1 from public.owner_applications oa
    where oa.user_id = v_uid and oa.status = 'pending'
  ) then
    raise exception '이미 심사 중인 신청이 있어요. 심사 완료 후 다시 시도해주세요.';
  end if;

  insert into public.owner_applications (
    user_id, restaurant_id, phone, email, license_paths, notify_push, notify_sms
  ) values (
    v_uid, p_restaurant_id, trim(p_phone), trim(p_email), p_license_paths,
    coalesce(p_notify_push, false), coalesce(p_notify_sms, false)
  )
  returning id into v_id;

  return v_id;
end;
$$;

revoke all on function public.submit_owner_application(uuid, text, text, jsonb, boolean, boolean) from public;
grant execute on function public.submit_owner_application(uuid, text, text, jsonb, boolean, boolean) to authenticated;

-- ── 3. 승인 시 앱 푸시 발송 트리거용 webhook 호출 ──
-- notify_community_comment_push와 동일한 패턴: push_edge_runtime_config 테이블에서
-- URL/시크릿을 읽어 net.http_post로 Edge Function을 호출하고, 실패해도 승인 자체는
-- 롤백되지 않도록 예외를 삼킨다. (app.settings.* GUC는 실제 운영에 설정돼 있지 않음)
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
    set owner_id = v_app.user_id
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
  end if;
end;
$$;

revoke all on function public.admin_review_owner_application(uuid, boolean, text) from public;
grant execute on function public.admin_review_owner_application(uuid, boolean, text) to authenticated;

-- ── 4. 승인 알림 수신자(푸시 토큰) 조회 — prefs와 무관하게 신청서의 notify_push만 본다 ──
create or replace function public.list_owner_approval_push_tokens(p_user_id uuid)
returns table (token text)
language sql
stable
security definer
set search_path = public
as $$
  select t.token
  from public.user_push_tokens t
  where t.user_id = p_user_id;
$$;

revoke all on function public.list_owner_approval_push_tokens(uuid) from public;
grant execute on function public.list_owner_approval_push_tokens(uuid) to service_role;

-- ── 5. 관리자 목록 조회 RPC에 notify_push/notify_sms 노출 (문자는 관리자가 수동 발송) ──
drop function if exists public.admin_list_owner_applications();

create or replace function public.admin_list_owner_applications()
returns table (
  id             uuid,
  user_id        uuid,
  user_nickname  text,
  restaurant_id  uuid,
  restaurant_name text,
  phone          text,
  email          text,
  license_paths  jsonb,
  status         text,
  reject_reason  text,
  notify_push    boolean,
  notify_sms     boolean,
  created_at     timestamptz,
  reviewed_at    timestamptz
)
language sql
stable
security definer
set search_path = public
as $$
  select
    oa.id, oa.user_id, u.nickname, oa.restaurant_id, r.name,
    oa.phone, oa.email, oa.license_paths, oa.status, oa.reject_reason,
    oa.notify_push, oa.notify_sms,
    oa.created_at, oa.reviewed_at
  from public.owner_applications oa
  join public.restaurants r on r.id = oa.restaurant_id
  join public.users u on u.id = oa.user_id
  where public.is_admin()
  order by
    case oa.status when 'pending' then 0 else 1 end,
    oa.created_at desc;
$$;

grant execute on function public.admin_list_owner_applications() to authenticated;

select 'owner_application_notify_method.sql ok' as status;
