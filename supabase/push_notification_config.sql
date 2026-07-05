-- 푸시 알림 스케줄·문구 설정 (어드민 웹 → 앱 로컬 예약 반영)
-- Dashboard → SQL Editor
--
-- ⚠️ "Failed to fetch (api.supabase.com)" 는 SQL 문법 오류가 아니라
--    Dashboard ↔ Supabase API 네트워크 문제입니다.
--    → 새로고침, 재로그인, 시크릿 창, VPN/광고차단 끄기, 프로젝트 일시중지 확인
--    → 아래 STEP 1 → 2 → 3 을 **한 블록씩** 나눠 Run

-- ═══════════════════════════════════════════════════════════════
-- STEP 1: is_admin (없으면 RLS 정책 생성 실패) + 테이블
-- ═══════════════════════════════════════════════════════════════

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

create table if not exists public.push_notification_config (
  id                  int primary key default 1 check (id = 1),
  lunch_hour          int not null default 12 check (lunch_hour between 0 and 23),
  lunch_minute        int not null default 0 check (lunch_minute between 0 and 59),
  dinner_hour         int not null default 18 check (dinner_hour between 0 and 23),
  dinner_minute       int not null default 0 check (dinner_minute between 0 and 59),
  title_template      text not null default '{gate}에서 대기 없이 식사할 수 있어요',
  body_template       text not null default '지금 바로 입장 가능한 매장을 확인해보세요' || E'\n' || '확인하러 가기 >',
  weekdays_only       boolean not null default true,
  schedule_days_ahead int not null default 14 check (schedule_days_ahead between 1 and 30),
  updated_at          timestamptz not null default now()
);

insert into public.push_notification_config (id)
values (1)
on conflict (id) do nothing;

-- ═══════════════════════════════════════════════════════════════
-- STEP 2: RLS + 조회 RPC
-- ═══════════════════════════════════════════════════════════════

alter table public.push_notification_config enable row level security;

drop policy if exists "push_config_select_all" on public.push_notification_config;
create policy "push_config_select_all" on public.push_notification_config
  for select using (true);

drop policy if exists "push_config_admin_update" on public.push_notification_config;
create policy "push_config_admin_update" on public.push_notification_config
  for update using (public.is_admin())
  with check (public.is_admin());

create or replace function public.get_push_notification_config()
returns jsonb
language sql
security definer
stable
set search_path = public
as $$
  select to_jsonb(c)
  from public.push_notification_config c
  where c.id = 1;
$$;

revoke all on function public.get_push_notification_config() from public;
grant execute on function public.get_push_notification_config() to anon, authenticated;

-- ═══════════════════════════════════════════════════════════════
-- STEP 3: 어드민 수정 RPC
-- ═══════════════════════════════════════════════════════════════

create or replace function public.admin_update_push_notification_config(
  p_lunch_hour int,
  p_lunch_minute int,
  p_dinner_hour int,
  p_dinner_minute int,
  p_title_template text,
  p_body_template text,
  p_weekdays_only boolean,
  p_schedule_days_ahead int
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  result jsonb;
begin
  if not public.is_admin() then
    raise exception '관리자만 푸시 설정을 변경할 수 있어요.';
  end if;

  if trim(coalesce(p_title_template, '')) = '' then
    raise exception '제목 템플릿을 입력해주세요.';
  end if;
  if trim(coalesce(p_body_template, '')) = '' then
    raise exception '본문 템플릿을 입력해주세요.';
  end if;
  if position('{gate}' in p_title_template) = 0 then
    raise exception '제목 템플릿에 {gate} 가 포함되어야 해요.';
  end if;

  update public.push_notification_config
  set
    lunch_hour = p_lunch_hour,
    lunch_minute = p_lunch_minute,
    dinner_hour = p_dinner_hour,
    dinner_minute = p_dinner_minute,
    title_template = trim(p_title_template),
    body_template = trim(p_body_template),
    weekdays_only = p_weekdays_only,
    schedule_days_ahead = p_schedule_days_ahead,
    updated_at = now()
  where id = 1
  returning to_jsonb(push_notification_config.*) into result;

  return result;
end;
$$;

revoke all on function public.admin_update_push_notification_config(int, int, int, int, text, text, boolean, int) from public;
grant execute on function public.admin_update_push_notification_config(int, int, int, int, text, text, boolean, int) to authenticated;

-- ═══════════════════════════════════════════════════════════════
-- 확인 (Success 나오면 OK)
-- ═══════════════════════════════════════════════════════════════

select public.get_push_notification_config();
