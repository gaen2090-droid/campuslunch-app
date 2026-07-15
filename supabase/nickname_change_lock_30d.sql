-- 닉네임 30일 변경 제한 (Dashboard → SQL Editor → Run)
--
-- 기존엔 클라이언트가 users.nickname을 직접 update만 했고 서버측 제한이 없어서
-- 앱이 30일 안내 문구만 보여줘도 실제로는 언제든 변경 가능했다. 트리거로
-- 마지막 닉네임 변경 후 30일 이내 재변경을 서버에서 막는다(클라이언트 우회 방지).

alter table public.users
  add column if not exists nickname_changed_at timestamptz;

create or replace function public.enforce_nickname_change_lock()
returns trigger
language plpgsql
as $$
begin
  if new.nickname is distinct from old.nickname then
    if old.nickname_changed_at is not null
       and now() < old.nickname_changed_at + interval '30 days' then
      raise exception '닉네임은 변경 후 30일이 지나야 다시 바꿀 수 있어요.';
    end if;
    new.nickname_changed_at := now();
  end if;
  return new;
end;
$$;

drop trigger if exists trg_enforce_nickname_change_lock on public.users;
create trigger trg_enforce_nickname_change_lock
  before update on public.users
  for each row
  execute function public.enforce_nickname_change_lock();

select 'nickname_change_lock_30d.sql ok' as status;
