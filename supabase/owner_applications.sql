-- 사장님 인증 전면 개편: 6자리 코드 폐지 → 가게 선택 + 사업자등록증/연락처 제출 → 관리자 승인
-- Dashboard → SQL Editor → Run
--
-- 새 플로우: 앱에서 매장 선택 → 사업자등록증(최대 3장) + 전화번호 + 이메일 제출
-- → owner_applications 에 status='pending'으로 저장 → 관리자(admin-web)가 승인/반려
-- → 승인 시 restaurants.owner_id 세팅. 6자리 코드(owner_code)는 더 이상 쓰지 않는다.
--
-- 이 파일 실행 후 owner_code_cleanup.sql 을 실행해 구 코드 흔적을 정리할 것.

-- ── 1. owner_applications 테이블 ──
create table if not exists public.owner_applications (
  id             uuid primary key default gen_random_uuid(),
  user_id        uuid not null references public.users (id) on delete cascade,
  restaurant_id  uuid not null references public.restaurants (id) on delete cascade,
  phone          text not null,
  email          text not null,
  license_paths  jsonb not null default '[]'::jsonb, -- storage path 배열 (최대 3장)
  status         text not null default 'pending' check (status in ('pending', 'approved', 'rejected')),
  reject_reason  text,
  reviewed_by    uuid references public.users (id) on delete set null,
  reviewed_at    timestamptz,
  created_at     timestamptz not null default now()
);

create index if not exists owner_applications_user_idx on public.owner_applications (user_id);
create index if not exists owner_applications_restaurant_idx on public.owner_applications (restaurant_id);
create index if not exists owner_applications_status_idx on public.owner_applications (status);

-- 매장당 대기 중인 신청은 하나만 (동일 매장에 여러 명이 동시에 pending 신청 불가)
create unique index if not exists owner_applications_one_pending_per_restaurant
  on public.owner_applications (restaurant_id)
  where status = 'pending';

-- 한 유저가 동시에 여러 매장에 pending 신청을 내는 것도 막는다 (한 번에 매장 하나씩)
create unique index if not exists owner_applications_one_pending_per_user
  on public.owner_applications (user_id)
  where status = 'pending';

alter table public.owner_applications enable row level security;

drop policy if exists "owner_applications_select_own_or_admin" on public.owner_applications;
create policy "owner_applications_select_own_or_admin" on public.owner_applications
  for select
  to authenticated
  using (user_id = auth.uid() or public.is_admin());

-- insert/update는 RPC(security definer)로만 수행 — 직접 테이블 조작 금지
revoke all on public.owner_applications from anon, authenticated;
grant select on public.owner_applications to authenticated;

-- ── 2. 신청 제출 RPC ──
create or replace function public.submit_owner_application(
  p_restaurant_id uuid,
  p_phone         text,
  p_email         text,
  p_license_paths jsonb
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
    user_id, restaurant_id, phone, email, license_paths
  ) values (
    v_uid, p_restaurant_id, trim(p_phone), trim(p_email), p_license_paths
  )
  returning id into v_id;

  return v_id;
end;
$$;

revoke all on function public.submit_owner_application(uuid, text, text, jsonb) from public;
grant execute on function public.submit_owner_application(uuid, text, text, jsonb) to authenticated;

-- ── 3. 내 최신 신청 상태 조회 (앱에서 심사중/반려 안내에 사용) ──
create or replace function public.get_my_owner_application()
returns table (
  id             uuid,
  restaurant_id  uuid,
  status         text,
  reject_reason  text,
  created_at     timestamptz,
  reviewed_at    timestamptz
)
language sql
stable
security definer
set search_path = public
as $$
  select oa.id, oa.restaurant_id, oa.status, oa.reject_reason, oa.created_at, oa.reviewed_at
  from public.owner_applications oa
  where oa.user_id = auth.uid()
  order by oa.created_at desc
  limit 1;
$$;

grant execute on function public.get_my_owner_application() to authenticated;

-- ── 4. 관리자 심사 RPC ──
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

-- ── 5. 관리자 목록 조회 RPC (매장명 조인) ──
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

-- ── 6. Storage: 사업자등록증 (private, 본인만 업로드, 관리자만 조회) ──
insert into storage.buckets (id, name, public)
values ('owner-licenses', 'owner-licenses', false)
on conflict (id) do nothing;

drop policy if exists "owner licenses own upload" on storage.objects;
create policy "owner licenses own upload" on storage.objects
  for insert to authenticated
  with check (
    bucket_id = 'owner-licenses'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

drop policy if exists "owner licenses select own or admin" on storage.objects;
create policy "owner licenses select own or admin" on storage.objects
  for select to authenticated
  using (
    bucket_id = 'owner-licenses'
    and (
      (storage.foldername(name))[1] = auth.uid()::text
      or public.is_admin()
    )
  );

drop policy if exists "owner licenses delete own" on storage.objects;
create policy "owner licenses delete own" on storage.objects
  for delete to authenticated
  using (
    bucket_id = 'owner-licenses'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

comment on table public.owner_applications is
  '사장님 인증 신청. 매장 선택 + 사업자등록증/연락처 제출 → 관리자 승인 시 restaurants.owner_id 세팅.';

select 'owner_applications.sql ok' as status;
