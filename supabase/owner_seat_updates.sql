-- PDF 「사장님의 한 마디」 — 입장 가능 인원
-- Dashboard → SQL Editor (policies.sql, rpc_claim_owner.sql 이후)

alter table public.restaurants
  add column if not exists owner_id uuid references public.users (id) on delete set null;

create index if not exists restaurants_owner_id_idx
  on public.restaurants (owner_id);

create table if not exists public.owner_seat_updates (
  id uuid primary key default gen_random_uuid(),
  restaurant_id uuid not null references public.restaurants (id) on delete cascade,
  owner_id uuid not null references public.users (id) on delete cascade,
  available_seats integer not null check (available_seats >= 0),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists owner_seat_updates_restaurant_created_idx
  on public.owner_seat_updates (restaurant_id, created_at desc);

-- 사장님 본인 매장 소유 여부 (owner_id 우선, JWT restaurant_ids 폴백)
create or replace function public.is_restaurant_owner(p_restaurant_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select
    auth.uid() is not null
    and exists (
      select 1
      from public.restaurants r
      where r.id = p_restaurant_id
        and r.is_active = true
        and (
          r.owner_id = auth.uid()
          or (
            coalesce(r.description::jsonb ->> 'owner_registered', 'false') = 'true'
            and exists (
              select 1
              from jsonb_array_elements_text(
                coalesce(
                  auth.jwt() -> 'user_metadata' -> 'restaurant_ids',
                  '[]'::jsonb
                )
              ) as rid(value)
              where rid.value = r.id::text
            )
          )
        )
    );
$$;

alter table public.owner_seat_updates enable row level security;

drop policy if exists "owner_seat_updates_select_public" on public.owner_seat_updates;
create policy "owner_seat_updates_select_public" on public.owner_seat_updates
  for select
  using (true);

drop policy if exists "owner_seat_updates_insert_owner" on public.owner_seat_updates;
create policy "owner_seat_updates_insert_owner" on public.owner_seat_updates
  for insert
  to authenticated
  with check (
    owner_id = auth.uid()
    and public.is_restaurant_owner(restaurant_id)
  );

-- 사장님: 입장 가능 인원 반영 (매번 새 row)
create or replace function public.submit_owner_seat_update(
  p_restaurant_id uuid,
  p_available_seats integer
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_id uuid;
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

-- 유저 상세: 1시간 이내 최신 1건
create or replace function public.get_owner_seat_update(p_restaurant_id uuid)
returns table (
  available_seats integer,
  created_at timestamptz
)
language sql
stable
security definer
set search_path = public
as $$
  select osu.available_seats, osu.created_at
  from public.owner_seat_updates osu
  where osu.restaurant_id = p_restaurant_id
    and osu.created_at > now() - interval '1 hour'
  order by osu.created_at desc
  limit 1;
$$;

grant execute on function public.is_restaurant_owner(uuid) to authenticated;
grant execute on function public.submit_owner_seat_update(uuid, integer) to authenticated;
grant execute on function public.get_owner_seat_update(uuid) to anon, authenticated;

-- owner_registered=true 이지만 owner_id가 비어 있는 매장: 로그인 후 코드 재인증 필요
-- (claim_owner_by_code 가 owner_id·users.role 을 함께 설정)

comment on table public.owner_seat_updates is
  '사장님의 한 마디 — 입장 가능 인원. 1시간 표시 후 유저 화면에서 숨김.';
