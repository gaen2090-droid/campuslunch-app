-- 출시용 RLS 정책 (Dashboard → SQL Editor → Run)
-- Publishable(anon) 키만 앱에 넣고, Secret 키는 서버/로컬 시드 전용.

-- ── 헬퍼: JWT metadata 또는 public.users.role ──
create or replace function public.is_admin()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select
    coalesce(
      auth.jwt() -> 'app_metadata' ->> 'role',
      auth.jwt() -> 'user_metadata' ->> 'role'
    ) = 'admin'
    or exists (
      select 1
      from public.users u
      where u.id = auth.uid()
        and u.role = 'admin'::public.user_role
    );
$$;

alter table public.restaurants enable row level security;
alter table public.crowd_reports enable row level security;

-- 기존 느슨한 정책 제거
drop policy if exists "restaurants_select_public" on public.restaurants;
drop policy if exists "crowd_reports_select_public" on public.crowd_reports;
drop policy if exists "crowd_reports_insert_public" on public.crowd_reports;
drop policy if exists "restaurants_insert_public" on public.restaurants;
drop policy if exists "restaurants_update_public" on public.restaurants;

-- 매장: 활성 매장만 조회
drop policy if exists "restaurants_select_active" on public.restaurants;
create policy "restaurants_select_active" on public.restaurants
  for select
  using (is_active = true);

-- 혼잡도 제보: 로그인 사용자만 (user / owner)
drop policy if exists "crowd_reports_select_all" on public.crowd_reports;
create policy "crowd_reports_select_all" on public.crowd_reports
  for select
  using (true);

drop policy if exists "crowd_reports_insert_auth" on public.crowd_reports;
create policy "crowd_reports_insert_auth" on public.crowd_reports
  for insert
  to authenticated
  with check (
    source in (
      'user'::public.crowd_source,
      'owner'::public.crowd_source
    )
  );

-- 매장 등록·수정: Supabase Auth 관리자만
drop policy if exists "restaurants_insert_admin" on public.restaurants;
create policy "restaurants_insert_admin" on public.restaurants
  for insert
  to authenticated
  with check (public.is_admin());

drop policy if exists "restaurants_update_admin" on public.restaurants;
create policy "restaurants_update_admin" on public.restaurants
  for update
  to authenticated
  using (public.is_admin())
  with check (public.is_admin());

-- 사장님 인증번호 등록 완료 (RPC에서 security definer로 처리 — policies.sql 하단)
