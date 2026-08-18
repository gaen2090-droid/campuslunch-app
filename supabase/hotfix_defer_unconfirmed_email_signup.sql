-- 이메일/비밀번호 가입은 이메일 인증(email_confirmed_at) 전까지
-- public.users에 등록하지 않는다.
--
-- 배경: signInWithOtp(shouldCreateUser: true)는 OTP 발송 시점에 곧바로
-- auth.users 행을 만든다(이메일 인증 완료 여부와 무관). handle_new_user()
-- 트리거는 auth.users INSERT에 반응하므로, 종전에는 인증번호만 받고
-- 실제로 입력하지 않은 사람도 정상 가입자처럼 public.users에 남았다.
--
-- 소셜 로그인(구글/카카오/애플)은 provider가 OAuth 토큰 검증 시점에
-- 이미 신원이 확인된 것이므로 email_confirmed_at 여부와 무관하게
-- 즉시 등록한다(대부분 email_confirmed_at이 null로 들어오는 provider도 있음).
-- 보류 여부는 auth.users.raw_app_meta_data ->> 'provider'가 정확히 'email'인
-- 경우만 판단한다(GoTrue가 가입 provider에 따라 채워주는 필드). 이 값이
-- 비어있거나 예상 밖이면 무조건 등록한다(fail-open) — 소셜 유저를 잘못
-- 걸러서 public.users 없는 유령 계정을 만드는 사고를 막기 위함.
--
-- Dashboard → SQL Editor → Run (users_auth.sql 이후)

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  fruits text[] := array['딸기', '사고', '포도', '수박', '레몬', '망고', '복숭아', '바나나'];
  v_nickname text;
  v_from_meta text := new.raw_user_meta_data ->> 'nickname';
  v_provider text := coalesce(
    new.raw_user_meta_data ->> 'auth_provider',
    new.raw_app_meta_data ->> 'provider',
    'email'
  );
begin
  -- 이메일/비밀번호 가입인데 아직 이메일 인증 전이면 public.users를 만들지 않는다.
  -- (OTP 검증 성공 시 auth.users.email_confirmed_at이 채워지고, Supabase가
  -- 그 UPDATE에도 트리거를 다시 태우므로 이 함수가 그때 다시 호출된다.)
  --
  -- 주의: raw_app_meta_data ->> 'provider'가 명시적으로 'email'일 때만 보류한다
  -- (fail-open). provider가 비어있거나 예상 밖 값이면 정지하지 말고 그냥 등록한다 —
  -- 소셜 로그인 신규가입자가 조용히 public.users 없이 유령 계정이 되는 쪽이
  -- 미인증 이메일 유저가 잠깐 더 보이는 것보다 훨씬 나쁘다.
  if coalesce(new.raw_app_meta_data ->> 'provider', '') = 'email'
     and new.email_confirmed_at is null then
    return new;
  end if;

  if v_from_meta is not null and trim(v_from_meta) <> '' then
    v_nickname := v_from_meta;
  else
    loop
      v_nickname := '앙대' || fruits[1 + floor(random() * array_length(fruits, 1))::int]
        || (1000 + floor(random() * 9000))::int;
      exit when not exists (
        select 1 from public.users
        where lower(trim(nickname)) = lower(trim(v_nickname))
      );
    end loop;
  end if;

  insert into public.users (
    id,
    email,
    nickname,
    role,
    provider,
    kakao_user_id,
    avatar_url,
    last_login_at
  )
  values (
    new.id,
    new.email,
    v_nickname,
    'user'::public.user_role,
    v_provider,
    new.raw_user_meta_data ->> 'kakao_user_id',
    new.raw_user_meta_data ->> 'avatar_url',
    now()
  )
  on conflict (id) do update set
    email = coalesce(excluded.email, users.email),
    provider = coalesce(excluded.provider, users.provider),
    kakao_user_id = coalesce(excluded.kakao_user_id, users.kakao_user_id),
    avatar_url = coalesce(excluded.avatar_url, users.avatar_url),
    last_login_at = now(),
    updated_at = now();
  return new;
end;
$$;

-- INSERT뿐 아니라 UPDATE(이메일 인증 완료로 email_confirmed_at이 채워지는 시점)에도
-- 같은 함수가 실행되도록 트리거를 확장한다.
drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert or update of email_confirmed_at on auth.users
  for each row execute function public.handle_new_user();

select 'hotfix_defer_unconfirmed_email_signup.sql ok' as status;

-- ⚠️ 기존에 잘못 등록된 유저 정리는 별도 파일
-- (hotfix_cleanup_unconfirmed_email_users.sql)에 있습니다.
-- 이 파일을 먼저 실행한 뒤, 그 파일 맨 위 SELECT로 대상 목록을
-- 눈으로 확인하고 나서 DELETE를 실행하세요.
