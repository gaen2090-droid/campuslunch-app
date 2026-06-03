-- 닉네임 중복 확인 (본인 제외, 대소문자 무시)
-- Dashboard → SQL Editor → Run

create or replace function public.is_nickname_available(p_nickname text)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
declare
  uid uuid := auth.uid();
  n text := trim(p_nickname);
begin
  if uid is null then
    raise exception 'NOT_AUTHENTICATED';
  end if;
  if n is null or n = '' then
    return false;
  end if;

  return not exists (
    select 1
    from public.users u
    where lower(trim(u.nickname)) = lower(n)
      and u.id <> uid
  );
end;
$$;

revoke all on function public.is_nickname_available(text) from public;
grant execute on function public.is_nickname_available(text) to authenticated;
