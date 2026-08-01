-- 사장님 본인 매장 등록 해제 (owner_id·owner_registered 초기화)
-- 마지막 매장 삭제 시 users.role도 owner→user로 되돌림 (커뮤니티 사장님 배지가 users.role 기준이라 안 돌리면 배지가 안 빠짐).
-- Dashboard → SQL Editor (rpc_claim_owner.sql 이후)
-- 기존에 이미 이 버그를 겪은 계정은 rpc_claim_owner.sql 하단의 일회성 UPDATE로 복구.

create or replace function public.release_owner_restaurant(p_restaurant_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  uid uuid := auth.uid();
  desc_json jsonb;
begin
  if uid is null then
    raise exception 'LOGIN_REQUIRED';
  end if;

  select r.description::jsonb
  into desc_json
  from public.restaurants r
  where r.id = p_restaurant_id
    and r.is_active = true
    and r.owner_id = uid;

  if not found then
    raise exception 'NOT_OWNER';
  end if;

  if desc_json is not null then
    desc_json := jsonb_set(desc_json, '{owner_registered}', 'false'::jsonb, true);
  end if;

  update public.restaurants
  set
    owner_id = null,
    description = coalesce(desc_json::text, description)
  where id = p_restaurant_id;

  -- 더 이상 소유한 매장이 없으면 role을 user로 되돌린다 (커뮤니티 사장님 배지 등에 사용됨).
  update public.users
  set role = 'user'::public.user_role,
      updated_at = now()
  where id = uid
    and role = 'owner'::public.user_role
    and not exists (
      select 1 from public.restaurants r
      where r.owner_id = uid and r.is_active = true
    );
end;
$$;

revoke all on function public.release_owner_restaurant(uuid) from public;
grant execute on function public.release_owner_restaurant(uuid) to authenticated;
