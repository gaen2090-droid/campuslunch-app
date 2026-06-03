-- 디버깅: 이메일로 회원 완전 삭제 (public.users + auth.users)
-- Table Editor에서 public.users 만 지우면 가입이 막힐 수 있음 → 이 스크립트 사용
--
-- Dashboard → SQL Editor → 아래 이메일만 바꾸고 Run

do $$
declare
  target_email text := 'your@email.com';  -- ← 테스트 이메일로 변경
  uid uuid;
begin
  select id into uid
  from auth.users
  where lower(email) = lower(trim(target_email));

  if uid is null then
    raise notice 'auth.users 에 해당 이메일 없음: %', target_email;
    return;
  end if;

  delete from public.bookmarks where user_id = uid;
  delete from public.notification_settings where user_id = uid;
  delete from public.user_devices where user_id = uid;
  delete from public.crowd_reports where user_id = uid;
  delete from public.analytics_events where user_id = uid;
  update public.restaurants set owner_id = null where owner_id = uid;

  delete from public.users where id = uid;
  delete from auth.users where id = uid;

  raise notice '삭제 완료: % (id=%)', target_email, uid;
end;
$$;
