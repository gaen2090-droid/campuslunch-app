-- DEPRECATED / ROLLED BACK
-- 이 파일의 RPC·정책은 restaurant_tier_tables.sql 에서 drop 한다.
-- 제보대상 O/X는 restaurant_report_targets / restaurant_collection_venues 로 관리.
--
-- (이하 본문은 히스토리용으로만 유지. 새로 실행하지 말 것.)

-- 어드민: 매장·유저 DB 직접 편집용 RPC
-- Dashboard → SQL Editor에서 실행

-- ── 매장 활성/비활성 (앱 노출 on/off) ──
create or replace function public.admin_set_restaurant_active(
  p_restaurant_id uuid,
  p_is_active boolean
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

  update public.restaurants
  set is_active = p_is_active
  where id = p_restaurant_id;

  if not found then
    raise exception '매장을 찾을 수 없어요.';
  end if;
end;
$$;

revoke all on function public.admin_set_restaurant_active(uuid, boolean) from public;
grant execute on function public.admin_set_restaurant_active(uuid, boolean) to authenticated;

-- ── 매장 핵심 컬럼 직접 패치 (어드민 DB 편집 표용) ──
create or replace function public.admin_patch_restaurant(
  p_restaurant_id uuid,
  p_name text default null,
  p_category text default null,
  p_area text default null,
  p_address text default null,
  p_latitude double precision default null,
  p_longitude double precision default null,
  p_is_active boolean default null,
  p_crowd_enabled boolean default null,
  p_owner_id uuid default null,
  p_clear_owner boolean default false,
  p_image_url text default null
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

  update public.restaurants r
  set
    name = coalesce(nullif(trim(p_name), ''), r.name),
    category = coalesce(nullif(trim(p_category), ''), r.category),
    area = coalesce(nullif(trim(p_area), ''), r.area),
    address = coalesce(p_address, r.address),
    latitude = coalesce(p_latitude, r.latitude),
    longitude = coalesce(p_longitude, r.longitude),
    is_active = coalesce(p_is_active, r.is_active),
    crowd_enabled = coalesce(p_crowd_enabled, r.crowd_enabled),
    owner_id = case
      when p_clear_owner then null
      when p_owner_id is not null then p_owner_id
      else r.owner_id
    end,
    image_url = coalesce(p_image_url, r.image_url)
  where r.id = p_restaurant_id;

  if not found then
    raise exception '매장을 찾을 수 없어요.';
  end if;
end;
$$;

revoke all on function public.admin_patch_restaurant(
  uuid, text, text, text, text, double precision, double precision,
  boolean, boolean, uuid, boolean, text
) from public;
grant execute on function public.admin_patch_restaurant(
  uuid, text, text, text, text, double precision, double precision,
  boolean, boolean, uuid, boolean, text
) to authenticated;

-- ── 유저 직접 편집 (닉네임·역할·이메일·스탬프) ──
create or replace function public.admin_update_user(
  p_user_id uuid,
  p_nickname text default null,
  p_role text default null,
  p_email text default null,
  p_total_stamps int default null
)
returns jsonb
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  v_role public.user_role;
  v_self uuid := auth.uid();
begin
  if not public.is_admin() then
    raise exception '관리자만 변경할 수 있어요.';
  end if;

  if not exists (select 1 from public.users u where u.id = p_user_id) then
    raise exception '회원을 찾을 수 없어요.';
  end if;

  -- 자기 자신의 admin 역할 해제는 막음
  if p_role is not null then
    if p_role not in ('user', 'owner', 'admin') then
      raise exception 'role은 user|owner|admin 만 가능해요.';
    end if;
    v_role := p_role::public.user_role;
    if p_user_id = v_self and v_role is distinct from 'admin'::public.user_role then
      raise exception '본인 관리자 권한은 해제할 수 없어요.';
    end if;
  end if;

  update public.users u
  set
    nickname = case
      when p_nickname is null then u.nickname
      when trim(p_nickname) = '' then u.nickname
      else trim(p_nickname)
    end,
    role = coalesce(v_role, u.role),
    email = case
      when p_email is null then u.email
      when trim(p_email) = '' then u.email
      else trim(p_email)
    end
  where u.id = p_user_id;

  if p_total_stamps is not null then
    if p_total_stamps < 0 then
      raise exception '스탬프는 0 이상이어야 해요.';
    end if;
    insert into public.user_rewards (user_id, total_stamps, updated_at)
    values (p_user_id, p_total_stamps, now())
    on conflict (user_id) do update
      set total_stamps = excluded.total_stamps,
          updated_at = now();
  end if;

  return jsonb_build_object('ok', true, 'user_id', p_user_id);
end;
$$;

revoke all on function public.admin_update_user(uuid, text, text, text, int) from public;
grant execute on function public.admin_update_user(uuid, text, text, text, int) to authenticated;

-- 어드민이 users 행을 직접 select/update 할 수 있게 (표 편집·진단용)
drop policy if exists "users_select_admin" on public.users;
create policy "users_select_admin" on public.users
  for select to authenticated
  using (public.is_admin());

drop policy if exists "users_update_admin" on public.users;
create policy "users_update_admin" on public.users
  for update to authenticated
  using (public.is_admin())
  with check (public.is_admin());
