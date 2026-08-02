-- 소셜 로그인 신규가입 실패 수정: "Database error saving new user" (Dashboard → SQL Editor → Run)
--
-- 증상: 카카오/구글로 신규가입 시 항상 "Database error saving new user" 발생.
--       (기존 계정 로그인은 정상 — 트리거를 안 타기 때문)
-- 원인: handle_new_user() 트리거가 소셜 로그인 신규가입자의 닉네임을 항상 고정값
--       '사용자'로 insert함. public.users에는 닉네임 대소문자 무시 UNIQUE 인덱스
--       (users_nickname_lower_unique_idx)가 걸려있어서, '사용자' 닉네임을 가진 계정이
--       하나라도 이미 존재하면 그 다음 모든 신규 소셜 가입이 UNIQUE 위반으로 실패함.
--       (실측: 2026-07-30 12:02 카카오 가입 계정이 '사용자' 닉네임을 선점 중이었음)
--
-- 수정: raw_user_meta_data에 닉네임이 없으면(대부분의 소셜 로그인 신규가입 케이스)
--       처음부터 최종 랜덤 닉네임(앙대+과일+숫자, nickname_generator.dart의
--       generateNickname()과 동일 포맷)을 생성해 insert한다. 충돌 시 재시도.
--       클라이언트의 isPlaceholderNickname 교체 로직은 건드리지 않음 —
--       레거시로 남아있는 '사용자' 계정은 다음 로그인 때 기존 로직대로 자연 치유됨.

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path to 'public'
as $$
declare
  fruits text[] := array['딸기', '사고', '포도', '수박', '레몬', '망고', '복숭아', '바나나'];
  v_nickname text;
  v_from_meta text := new.raw_user_meta_data ->> 'nickname';
begin
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
    coalesce(
      new.raw_user_meta_data ->> 'auth_provider',
      new.raw_app_meta_data ->> 'provider',
      'email'
    ),
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
