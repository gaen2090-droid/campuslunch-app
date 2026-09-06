-- 6자리 사장님 코드 방식 폐지: RPC 삭제 + description에서 owner_code/owner_registered 제거
-- owner_applications.sql 실행(및 앱/어드민 배포) 이후에 실행할 것.
-- Dashboard → SQL Editor → Run

drop function if exists public.claim_owner_by_code(text);

-- description JSONB에서 owner_code, owner_registered 키 제거 (owner_id가 유일한 소유 판단 기준)
update public.restaurants
set description = (description::jsonb - 'owner_code' - 'owner_registered')::text
where description is not null
  and (description::jsonb ? 'owner_code' or description::jsonb ? 'owner_registered');

-- is_restaurant_owner: JWT restaurant_ids 폴백 제거, owner_id 단일 기준으로 단순화
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
        and r.owner_id = auth.uid()
    );
$$;

grant execute on function public.is_restaurant_owner(uuid) to authenticated;

-- release_owner_restaurant: owner_registered 필드 갱신 로직 제거, owner_id만 초기화
create or replace function public.release_owner_restaurant(p_restaurant_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  uid uuid := auth.uid();
begin
  if uid is null then
    raise exception 'LOGIN_REQUIRED';
  end if;

  if not exists (
    select 1 from public.restaurants r
    where r.id = p_restaurant_id
      and r.is_active = true
      and r.owner_id = uid
  ) then
    raise exception 'NOT_OWNER';
  end if;

  update public.restaurants
  set owner_id = null
  where id = p_restaurant_id;
end;
$$;

revoke all on function public.release_owner_restaurant(uuid) from public;
grant execute on function public.release_owner_restaurant(uuid) to authenticated;

select 'owner_code_cleanup.sql ok' as status;
