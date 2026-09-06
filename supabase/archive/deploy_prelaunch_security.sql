-- ═══════════════════════════════════════════════════════════════════════════
-- 배포 전 보안·RLS 점검 패치 (Dashboard → SQL Editor → Run)
-- 기존 DB에 한 번 실행. 신규 설치는 schema.sql 15번으로 참조.
-- ═══════════════════════════════════════════════════════════════════════════

-- ── 1. is_admin: JWT user_metadata 신뢰 제거 (자가 admin 승격 방지) ──
create or replace function public.is_admin()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.users u
    where u.id = auth.uid()
      and u.role = 'admin'::public.user_role
  );
$$;

-- ── 2. 가입 트리거: metadata의 role 무시, 항상 user ──
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
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
    coalesce(new.raw_user_meta_data ->> 'nickname', '사용자'),
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
    nickname = coalesce(excluded.nickname, users.nickname),
    provider = coalesce(excluded.provider, users.provider),
    kakao_user_id = coalesce(excluded.kakao_user_id, users.kakao_user_id),
    avatar_url = coalesce(excluded.avatar_url, users.avatar_url),
    last_login_at = now(),
    updated_at = now();
  return new;
end;
$$;

-- ── 3. users.role 자가 변경 차단 ──
create or replace function public.users_guard_role()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if tg_op = 'UPDATE' and new.role is distinct from old.role then
    if not public.is_admin() then
      new.role := old.role;
    end if;
  end if;
  return new;
end;
$$;

drop trigger if exists trg_users_guard_role on public.users;
create trigger trg_users_guard_role
  before update on public.users
  for each row execute function public.users_guard_role();

-- ── 4. user_rewards: 직접 INSERT/UPDATE 차단 (스탬프는 RPC만) ──
drop policy if exists "user_rewards_update_own" on public.user_rewards;
drop policy if exists "user_rewards_insert_own" on public.user_rewards;

-- ── 5. grant_stamp: 일반 유저 직접 호출 금지 ──
revoke all on function public.grant_stamp(uuid, int) from public;
revoke all on function public.grant_stamp(uuid, int) from anon;
revoke all on function public.grant_stamp(uuid, int) from authenticated;

-- ── 6. 일일 스탬프 상한 999개 (디버깅·테스트용) ──
create or replace function public.grant_stamp(p_user_id uuid, p_count int default 1)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_today        date := (now() at time zone 'Asia/Seoul')::date;
  v_today_stamps int;
  v_total_stamps int;
  v_granted      int := 0;
  v_row          public.user_rewards;
  v_daily_room   int;
  v_intended     int;
  v_to_add       int;
  v_overflow     int;
  v_auto_redeem  jsonb := jsonb_build_object('status', 'none');
begin
  insert into public.user_rewards (user_id)
  values (p_user_id)
  on conflict (user_id) do nothing;

  select * into v_row
  from public.user_rewards
  where user_id = p_user_id
  for update;

  if v_row.last_stamp_date is distinct from v_today then
    v_today_stamps := 0;
  else
    v_today_stamps := v_row.today_stamps;
  end if;

  v_total_stamps := v_row.total_stamps;

  if v_total_stamps >= 20 then
    v_auto_redeem := public._perform_gifticon_redeem(p_user_id);
    if (v_auto_redeem ->> 'status') = 'ok' then
      v_total_stamps := coalesce((v_auto_redeem ->> 'total_stamps')::int, 0);
    end if;
  else
    v_daily_room := 999 - v_today_stamps;
    v_intended := least(p_count, greatest(v_daily_room, 0));

    if v_intended > 0 then
      v_to_add := least(v_intended, 20 - v_total_stamps);
      v_overflow := v_intended - v_to_add;

      v_today_stamps := v_today_stamps + v_intended;
      v_total_stamps := v_total_stamps + v_to_add;
      v_granted := v_intended;

      update public.user_rewards
      set today_stamps    = v_today_stamps,
          total_stamps    = v_total_stamps,
          last_stamp_date = v_today
      where user_id = p_user_id;

      if v_total_stamps >= 20 then
        v_auto_redeem := public._perform_gifticon_redeem(p_user_id);
        if (v_auto_redeem ->> 'status') = 'ok' then
          v_total_stamps :=
            coalesce((v_auto_redeem ->> 'total_stamps')::int, 0) + v_overflow;

          update public.user_rewards
          set total_stamps = v_total_stamps
          where user_id = p_user_id;

          v_auto_redeem := v_auto_redeem
            || jsonb_build_object('total_stamps', v_total_stamps);
        end if;
      end if;
    end if;
  end if;

  return jsonb_build_object(
    'granted',       v_granted > 0,
    'granted_count', v_granted,
    'today_stamps',  v_today_stamps,
    'total_stamps',  v_total_stamps,
    'auto_redeem',   v_auto_redeem
  );
end;
$$;

-- ── 7. admin_dashboard_metrics: 로그인+admin만 ──
-- 함수 본문(푸시 오픈율 포함)은 push_analytics.sql 66~312행 CREATE OR REPLACE 를
-- 이 파일과 같은 SQL Editor 세션에서 먼저 실행하세요. (admin guard + push 필드 동기화)

revoke all on function public.admin_dashboard_metrics() from public;
revoke all on function public.admin_dashboard_metrics() from anon;
grant execute on function public.admin_dashboard_metrics() to authenticated;

-- ── 8. RPC grant 정리 ──
revoke all on function public.claim_owner_by_code(text) from anon;
grant execute on function public.claim_owner_by_code(text) to authenticated;

-- ── 9. app_feedback (앱 피드백) ──
create table if not exists public.app_feedback (
  id         uuid primary key default gen_random_uuid(),
  user_id    uuid references public.users(id) on delete set null,
  category   text not null,
  content    text not null,
  created_at timestamptz not null default now()
);

alter table public.app_feedback enable row level security;

drop policy if exists "app_feedback_insert_auth" on public.app_feedback;
create policy "app_feedback_insert_auth" on public.app_feedback
  for insert to authenticated
  with check (user_id = auth.uid());

drop policy if exists "app_feedback_select_admin" on public.app_feedback;
create policy "app_feedback_select_admin" on public.app_feedback
  for select to authenticated
  using (public.is_admin());
