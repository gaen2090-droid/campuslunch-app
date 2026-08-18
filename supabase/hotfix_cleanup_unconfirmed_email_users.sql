-- 이메일 미인증 상태로 잘못 public.users에 등록된 계정을 정리한다.
-- hotfix_defer_unconfirmed_email_signup.sql을 먼저 실행해서 앞으로의
-- 신규가입을 막은 뒤, 과거에 이미 들어간 레코드를 여기서 청소한다.
--
-- 반드시 순서대로:
--   1) 아래 SELECT만 먼저 실행해서 대상 목록을 눈으로 확인한다.
--      (예: adfdf@adfsd.com 같은, provider='email'이고 이메일 인증 안 한 계정만 나와야 함)
--   2) 목록이 예상과 다르면(소셜 로그인 유저가 섞여 보이면) 절대 DELETE를
--      실행하지 말고 문의할 것.
--   3) 목록이 맞으면 DELETE 블록을 실행한다.
--
-- Dashboard → SQL Editor → Run (hotfix_defer_unconfirmed_email_signup.sql 이후)

-- 1) 확인용 SELECT — 먼저 이것만 실행해서 결과를 확인하세요.
select
  u.id,
  u.email,
  u.provider,
  u.created_at,
  au.email_confirmed_at
from public.users u
join auth.users au on au.id = u.id
where u.provider = 'email'
  and au.email_confirmed_at is null
order by u.created_at desc;

-- 2) 위 목록을 확인한 뒤에만 아래 DELETE를 실행하세요.
-- delete from public.users u
-- where u.provider = 'email'
--   and exists (
--     select 1 from auth.users au
--     where au.id = u.id and au.email_confirmed_at is null
--   );

-- select 'hotfix_cleanup_unconfirmed_email_users.sql ok' as status;
