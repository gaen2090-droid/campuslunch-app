-- 매장 제보대상 O/X 종속 테이블 (Dashboard → SQL Editor → Run 또는 supabase db query --linked -f)
-- restaurants는 그대로 두고, 멤버십 테이블이 정본 → crowd_enabled는 트리거로 동기화.
--
-- 제보 대상 O: public.restaurant_report_targets
-- 제보 대상 X (맛집컬렉션 전용): public.restaurant_collection_venues
--
-- 동시에 이 파일은 admin_db_direct_edit.sql 의 RPC/정책을 롤백한다.

-- ── 0) DB 직접 편집 롤백 ──
drop function if exists public.admin_set_restaurant_active(uuid, boolean);
drop function if exists public.admin_patch_restaurant(
  uuid, text, text, text, text, double precision, double precision,
  boolean, boolean, uuid, boolean, text
);
drop function if exists public.admin_update_user(uuid, text, text, text, integer);

drop policy if exists "users_select_admin" on public.users;
drop policy if exists "users_update_admin" on public.users;

-- ── 1) 종속 테이블 ──
create table if not exists public.restaurant_report_targets (
  restaurant_id uuid primary key
    references public.restaurants (id) on delete cascade,
  created_at timestamptz not null default now(),
  notes text
);

create table if not exists public.restaurant_collection_venues (
  restaurant_id uuid primary key
    references public.restaurants (id) on delete cascade,
  created_at timestamptz not null default now(),
  notes text
);

create index if not exists restaurant_report_targets_created_at_idx
  on public.restaurant_report_targets (created_at desc);

create index if not exists restaurant_collection_venues_created_at_idx
  on public.restaurant_collection_venues (created_at desc);

comment on table public.restaurant_report_targets is
  '제보 대상 O. 멤버십이 정본이며 restaurants.crowd_enabled=true 와 동기화.';
comment on table public.restaurant_collection_venues is
  '제보 대상 X(맛집컬렉션 전용). 멤버십이 정본이며 restaurants.crowd_enabled=false 와 동기화.';

-- ── 2) 동기화 트리거 (자식 테이블 → crowd_enabled, 상호 배타) ──
create or replace function public.trg_report_target_sync()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if tg_op = 'INSERT' then
    delete from public.restaurant_collection_venues
    where restaurant_id = new.restaurant_id;
    update public.restaurants
    set crowd_enabled = true
    where id = new.restaurant_id
      and crowd_enabled is distinct from true;
    return new;
  end if;

  -- DELETE: 컬렉션 쪽에 없으면 컬렉션으로 내려 둔다 (고아 방지)
  if not exists (
    select 1 from public.restaurant_collection_venues
    where restaurant_id = old.restaurant_id
  ) then
    insert into public.restaurant_collection_venues (restaurant_id)
    values (old.restaurant_id)
    on conflict (restaurant_id) do nothing;
  end if;
  update public.restaurants
  set crowd_enabled = false
  where id = old.restaurant_id
    and crowd_enabled is distinct from false;
  return old;
end;
$$;

create or replace function public.trg_collection_venue_sync()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if tg_op = 'INSERT' then
    delete from public.restaurant_report_targets
    where restaurant_id = new.restaurant_id;
    update public.restaurants
    set crowd_enabled = false
    where id = new.restaurant_id
      and crowd_enabled is distinct from false;
    return new;
  end if;

  -- DELETE: 제보 쪽에 없으면 제보 대상으로 올린다
  if not exists (
    select 1 from public.restaurant_report_targets
    where restaurant_id = old.restaurant_id
  ) then
    insert into public.restaurant_report_targets (restaurant_id)
    values (old.restaurant_id)
    on conflict (restaurant_id) do nothing;
  end if;
  update public.restaurants
  set crowd_enabled = true
  where id = old.restaurant_id
    and crowd_enabled is distinct from true;
  return old;
end;
$$;

drop trigger if exists restaurant_report_targets_sync on public.restaurant_report_targets;
create trigger restaurant_report_targets_sync
  after insert or delete on public.restaurant_report_targets
  for each row execute function public.trg_report_target_sync();

drop trigger if exists restaurant_collection_venues_sync on public.restaurant_collection_venues;
create trigger restaurant_collection_venues_sync
  after insert or delete on public.restaurant_collection_venues
  for each row execute function public.trg_collection_venue_sync();

-- ── 3) restaurants INSERT/UPDATE(crowd_enabled) → 멤버십 동기 (레거시 API 호환) ──
create or replace function public.trg_restaurants_tier_membership()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if tg_op = 'INSERT' then
    if new.crowd_enabled then
      insert into public.restaurant_report_targets (restaurant_id)
      values (new.id)
      on conflict (restaurant_id) do nothing;
    else
      insert into public.restaurant_collection_venues (restaurant_id)
      values (new.id)
      on conflict (restaurant_id) do nothing;
    end if;
    return new;
  end if;

  -- UPDATE OF crowd_enabled
  if new.crowd_enabled is distinct from old.crowd_enabled then
    if new.crowd_enabled then
      insert into public.restaurant_report_targets (restaurant_id)
      values (new.id)
      on conflict (restaurant_id) do nothing;
      -- insert trigger가 collection 쪽을 지움
    else
      insert into public.restaurant_collection_venues (restaurant_id)
      values (new.id)
      on conflict (restaurant_id) do nothing;
    end if;
  end if;
  return new;
end;
$$;

drop trigger if exists restaurants_tier_membership on public.restaurants;
create trigger restaurants_tier_membership
  after insert or update of crowd_enabled on public.restaurants
  for each row execute function public.trg_restaurants_tier_membership();

-- ── 4) 백필 (기존 crowd_enabled 기준, 트리거 일시 비활성 후 삽입) ──
alter table public.restaurant_report_targets disable trigger restaurant_report_targets_sync;
alter table public.restaurant_collection_venues disable trigger restaurant_collection_venues_sync;

insert into public.restaurant_report_targets (restaurant_id)
select id from public.restaurants
where crowd_enabled = true
on conflict (restaurant_id) do nothing;

insert into public.restaurant_collection_venues (restaurant_id)
select id from public.restaurants
where crowd_enabled = false
on conflict (restaurant_id) do nothing;

-- 어디에도 없는 행 방어 (이론상 없음)
insert into public.restaurant_collection_venues (restaurant_id)
select r.id
from public.restaurants r
where not exists (
  select 1 from public.restaurant_report_targets t where t.restaurant_id = r.id
)
and not exists (
  select 1 from public.restaurant_collection_venues c where c.restaurant_id = r.id
)
on conflict (restaurant_id) do nothing;

alter table public.restaurant_report_targets enable trigger restaurant_report_targets_sync;
alter table public.restaurant_collection_venues enable trigger restaurant_collection_venues_sync;

-- ── 5) RLS (관리자만 쓰기, 인증 사용자는 읽기) ──
alter table public.restaurant_report_targets enable row level security;
alter table public.restaurant_collection_venues enable row level security;

drop policy if exists "report_targets_select_authenticated"
  on public.restaurant_report_targets;
create policy "report_targets_select_authenticated"
  on public.restaurant_report_targets
  for select to authenticated
  using (true);

drop policy if exists "report_targets_admin_write"
  on public.restaurant_report_targets;
create policy "report_targets_admin_write"
  on public.restaurant_report_targets
  for all to authenticated
  using (public.is_admin())
  with check (public.is_admin());

drop policy if exists "collection_venues_select_authenticated"
  on public.restaurant_collection_venues;
create policy "collection_venues_select_authenticated"
  on public.restaurant_collection_venues
  for select to authenticated
  using (true);

drop policy if exists "collection_venues_admin_write"
  on public.restaurant_collection_venues;
create policy "collection_venues_admin_write"
  on public.restaurant_collection_venues
  for all to authenticated
  using (public.is_admin())
  with check (public.is_admin());

grant select on public.restaurant_report_targets to authenticated, anon;
grant select on public.restaurant_collection_venues to authenticated, anon;
grant insert, update, delete on public.restaurant_report_targets to authenticated;
grant insert, update, delete on public.restaurant_collection_venues to authenticated;

-- ── 6) 어드민 전환 RPC (상호 배타 보장) ──
create or replace function public.admin_set_restaurant_tier(
  p_restaurant_id uuid,
  p_tier text
)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if not public.is_admin() then
    raise exception '관리자만 변경할 수 있어요.';
  end if;

  if p_tier not in ('report', 'collection') then
    raise exception 'tier는 report 또는 collection 이어야 해요.';
  end if;

  if not exists (
    select 1 from public.restaurants where id = p_restaurant_id
  ) then
    raise exception '매장을 찾을 수 없어요.';
  end if;

  if p_tier = 'report' then
    insert into public.restaurant_report_targets (restaurant_id)
    values (p_restaurant_id)
    on conflict (restaurant_id) do nothing;
  else
    insert into public.restaurant_collection_venues (restaurant_id)
    values (p_restaurant_id)
    on conflict (restaurant_id) do nothing;
  end if;
end;
$$;

revoke all on function public.admin_set_restaurant_tier(uuid, text) from public;
grant execute on function public.admin_set_restaurant_tier(uuid, text) to authenticated;
