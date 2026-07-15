-- ── 친구 초대(리퍼럴) 스탬프 프로그램 ──
-- 실행 순서: rewards.sql 이후

-- 1. users에 추천인 코드 컬럼 추가
alter table public.users add column if not exists referral_code text unique;

-- 6자리 영숫자(대문자+숫자, 혼동되는 문자 제외: O/0, I/1) 코드 생성기
create or replace function public._generate_referral_code()
returns text
language plpgsql
as $$
declare
  chars text := 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  v_code text;
  v_exists boolean;
begin
  loop
    v_code := '';
    for i in 1..6 loop
      v_code := v_code || substr(chars, floor(random() * length(chars) + 1)::int, 1);
    end loop;
    select exists(select 1 from public.users where referral_code = v_code) into v_exists;
    exit when not v_exists;
  end loop;
  return v_code;
end;
$$;

-- 기존 유저 소급 채움
do $$
declare
  v_user record;
begin
  for v_user in select id from public.users where referral_code is null loop
    update public.users
    set referral_code = public._generate_referral_code()
    where id = v_user.id;
  end loop;
end $$;

-- 신규 유저 가입 시 자동 채움
create or replace function public._assign_referral_code()
returns trigger
language plpgsql
as $$
begin
  if new.referral_code is null then
    new.referral_code := public._generate_referral_code();
  end if;
  return new;
end;
$$;

drop trigger if exists trg_users_assign_referral_code on public.users;
create trigger trg_users_assign_referral_code
  before insert on public.users
  for each row execute function public._assign_referral_code();

-- 2. 추천 관계 테이블
create table if not exists public.referrals (
  id                uuid primary key default gen_random_uuid(),
  referrer_user_id  uuid not null references public.users(id) on delete cascade,
  referred_user_id  uuid not null unique references public.users(id) on delete cascade,
  created_at        timestamptz not null default now()
);

create index if not exists idx_referrals_referrer on public.referrals(referrer_user_id);

alter table public.referrals enable row level security;

drop policy if exists "referrals_select_own" on public.referrals;
create policy "referrals_select_own" on public.referrals
  for select using (
    referrer_user_id = auth.uid() or referred_user_id = auth.uid()
  );

-- INSERT는 apply_referral_code RPC(security definer)만 허용

-- 3. 리퍼럴 전용 스탬프 지급 (today_stamps 미반영, total_stamps만 증가)
--    grant_stamp와 동일하게 20개 도달 시 기프티콘 자동 배정
drop function if exists public.grant_referral_stamp(uuid, int);
create or replace function public.grant_referral_stamp(p_user_id uuid, p_count int default 3)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_total_stamps int;
  v_redeem       jsonb;
begin
  insert into public.user_rewards (user_id)
  values (p_user_id)
  on conflict (user_id) do nothing;

  update public.user_rewards
  set total_stamps = total_stamps + p_count
  where user_id = p_user_id
  returning total_stamps into v_total_stamps;

  while v_total_stamps >= 20 loop
    v_redeem := public._perform_gifticon_redeem(p_user_id);
    if v_redeem->>'status' != 'ok' then
      exit;
    end if;
    v_total_stamps := (v_redeem->>'total_stamps')::int;
  end loop;

  return jsonb_build_object(
    'granted_count', p_count,
    'total_stamps',  v_total_stamps
  );
end;
$$;

revoke all on function public.grant_referral_stamp(uuid, int) from public;
revoke all on function public.grant_referral_stamp(uuid, int) from anon;
revoke all on function public.grant_referral_stamp(uuid, int) from authenticated;

-- 4. 추천인 코드 적용 RPC (가입 완료 후 홈 진입 직전, 선택 입력)
drop function if exists public.apply_referral_code(text);
create or replace function public.apply_referral_code(p_code text)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid       uuid := auth.uid();
  v_code      text := upper(trim(p_code));
  v_referrer  uuid;
begin
  if v_uid is null then
    raise exception '로그인이 필요해요.';
  end if;

  if v_code = '' then
    return jsonb_build_object('status', 'invalid_code');
  end if;

  if exists (select 1 from public.referrals where referred_user_id = v_uid) then
    return jsonb_build_object('status', 'already_used');
  end if;

  select id into v_referrer
  from public.users
  where referral_code = v_code;

  if v_referrer is null then
    return jsonb_build_object('status', 'invalid_code');
  end if;

  if v_referrer = v_uid then
    return jsonb_build_object('status', 'self_referral');
  end if;

  -- 같은 추천인은 하루(KST) 최대 1건만 성사 가능
  if exists (
    select 1 from public.referrals
    where referrer_user_id = v_referrer
      and (created_at at time zone 'Asia/Seoul')::date
        = (now() at time zone 'Asia/Seoul')::date
  ) then
    return jsonb_build_object('status', 'referrer_daily_limit');
  end if;

  insert into public.referrals (referrer_user_id, referred_user_id)
  values (v_referrer, v_uid);

  perform public.grant_referral_stamp(v_referrer, 3);
  perform public.grant_referral_stamp(v_uid, 3);

  return jsonb_build_object('status', 'ok');
exception
  when unique_violation then
    return jsonb_build_object('status', 'already_used');
end;
$$;

grant execute on function public.apply_referral_code(text) to authenticated;

-- 5. 내 추천 히스토리 조회 (스탬프북 카드용)
drop function if exists public.get_my_referral_history();
create or replace function public.get_my_referral_history()
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
begin
  if v_uid is null then
    raise exception '로그인이 필요해요.';
  end if;

  return jsonb_build_object(
    'my_referral_code', (select referral_code from public.users where id = v_uid),
    'events', (
      select coalesce(jsonb_agg(jsonb_build_object(
        'id', r.id,
        'created_at', r.created_at,
        'role', case when r.referrer_user_id = v_uid then 'referrer' else 'referred' end
      ) order by r.created_at desc), '[]'::jsonb)
      from public.referrals r
      where r.referrer_user_id = v_uid or r.referred_user_id = v_uid
    )
  );
end;
$$;

grant execute on function public.get_my_referral_history() to authenticated;

comment on table public.referrals is '친구 초대 관계. referred_user_id는 unique — 한 유저는 평생 1회만 피추천 가능.';
comment on column public.users.referral_code is '내 추천 코드(공유용). 6자리 영숫자, 가입 시 자동 생성.';
