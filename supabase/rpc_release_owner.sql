-- 사장님 본인 매장 등록 해제 (owner_id·owner_registered 초기화)
-- Dashboard → SQL Editor (rpc_claim_owner.sql 이후)

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
end;
$$;

revoke all on function public.release_owner_restaurant(uuid) from public;
grant execute on function public.release_owner_restaurant(uuid) to authenticated;
