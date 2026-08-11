-- 닉네임 중복 확인 (본인 제외, 대소문자 무시)
-- Dashboard → SQL Editor → Run

-- DB상 혼선을 주는 예약 닉네임(시스템이 자동 부여/익명화에 쓰는 고정값) — 사용자가
-- 직접 설정하지 못하게 막는다. is_nickname_available·is_nickname_taken 둘 다 이 함수를
-- 참조하므로 목록은 여기 한 곳에서만 관리한다.
-- '탈퇴한 회원'은 delete_own_account()가 익명화용으로 직접 UPDATE하므로 이 함수가
-- 아니라 users_nickname_lower_unique_idx(유니크 인덱스) 쪽에서 예외 처리한다 — 여기서
-- 막으면 회원 탈퇴 자체가 깨진다.
create or replace function public.is_reserved_nickname(p_nickname text)
returns boolean
language sql
immutable
as $$
  select lower(trim(p_nickname)) = any (array[
    '사용자',
    '카카오 사용자',
    '구글 사용자',
    '애플 사용자',
    '탈퇴한 회원',
    '탈퇴한 사용자'
  ]);
$$;

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
  if public.is_reserved_nickname(n) then
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
