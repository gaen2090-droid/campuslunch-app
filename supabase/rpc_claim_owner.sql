-- 사장님 6자리 코드 인증 (Secret 키 없이 안전하게)
-- Dashboard → SQL Editor 에서 실행

create or replace function public.claim_owner_by_code(p_code text)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  rid uuid;
  desc_json jsonb;
  uid uuid := auth.uid();
begin
  if uid is null then
    raise exception 'LOGIN_REQUIRED';
  end if;

  if p_code is null or length(trim(p_code)) <> 6 then
    raise exception 'INVALID_CODE';
  end if;

  select id, description::jsonb
  into rid, desc_json
  from restaurants
  where is_active = true
    and description is not null
    and description::jsonb ->> 'owner_code' = trim(p_code)
  limit 1;

  if rid is null then
    raise exception 'INVALID_CODE';
  end if;

  if (desc_json ->> 'owner_registered')::boolean = true then
    if exists (
      select 1
      from public.restaurants r
      where r.id = rid
        and r.owner_id is not null
        and r.owner_id <> uid
    ) then
      raise exception 'ALREADY_USED';
    end if;
  else
    desc_json := jsonb_set(desc_json, '{owner_registered}', 'true'::jsonb, true);
  end if;

  update restaurants
  set
    description = desc_json::text,
    owner_id = uid
  where id = rid;

  return rid;
end;
$$;

-- role=owner 이지만 소유 매장 없는 계정 → user 로 복구 (선택 실행)
update public.users u
set
  role = 'user'::public.user_role,
  updated_at = now()
where u.role = 'owner'::public.user_role
  and not exists (
    select 1 from public.restaurants r where r.owner_id = u.id
  );

revoke all on function public.claim_owner_by_code(text) from public;
grant execute on function public.claim_owner_by_code(text) to anon, authenticated;
