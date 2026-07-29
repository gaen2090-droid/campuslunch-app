-- 피크 푸시: 슬롯당 하루 1회 → (날짜+슬롯+시+분)당 1회
-- 같은 lunch라도 시각을 바꾸면 그날 다시 발송 가능.
-- 커스텀 스케줄 id(lunch/dinner 외)도 클레임 가능.
-- Dashboard SQL Editor 또는 supabase db query --linked -f …

-- 1) 스키마 확장
alter table public.peak_push_sent_log
  drop constraint if exists peak_push_sent_log_slot_check;

alter table public.peak_push_sent_log
  add column if not exists hour int;

alter table public.peak_push_sent_log
  add column if not exists minute int;

-- 기존 행: 시각 없으면 0,0으로 채움 (레거시)
update public.peak_push_sent_log
set hour = coalesce(hour, 0),
    minute = coalesce(minute, 0)
where hour is null or minute is null;

alter table public.peak_push_sent_log
  alter column hour set default 0,
  alter column minute set default 0;

alter table public.peak_push_sent_log
  alter column hour set not null,
  alter column minute set not null;

alter table public.peak_push_sent_log
  drop constraint if exists peak_push_sent_log_pkey;

alter table public.peak_push_sent_log
  add constraint peak_push_sent_log_pkey
  primary key (sent_date, slot, hour, minute);

alter table public.peak_push_sent_log
  drop constraint if exists peak_push_sent_log_hour_check;
alter table public.peak_push_sent_log
  add constraint peak_push_sent_log_hour_check
  check (hour >= 0 and hour <= 23);

alter table public.peak_push_sent_log
  drop constraint if exists peak_push_sent_log_minute_check;
alter table public.peak_push_sent_log
  add constraint peak_push_sent_log_minute_check
  check (minute >= 0 and minute <= 59);

-- 2) 클레임 RPC: 같은 날짜·슬롯·시·분만 중복 방지 (cron 같은 분 두 번 방지)
drop function if exists public.try_claim_peak_push(text, date);
drop function if exists public.try_claim_peak_push(text, date, int, int);

create or replace function public.try_claim_peak_push(
  p_slot text,
  p_date date default (timezone('Asia/Seoul', now()))::date,
  p_hour int default null,
  p_minute int default null
)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
declare
  inserted int;
  v_hour int;
  v_minute int;
  v_slot text;
begin
  v_slot := nullif(trim(coalesce(p_slot, '')), '');
  if v_slot is null then
    return false;
  end if;

  v_hour := coalesce(p_hour, extract(hour from timezone('Asia/Seoul', now()))::int);
  v_minute := coalesce(p_minute, extract(minute from timezone('Asia/Seoul', now()))::int);

  if v_hour < 0 or v_hour > 23 or v_minute < 0 or v_minute > 59 then
    return false;
  end if;

  insert into public.peak_push_sent_log (sent_date, slot, hour, minute)
  values (p_date, v_slot, v_hour, v_minute)
  on conflict do nothing;

  get diagnostics inserted = row_count;
  return inserted > 0;
end;
$$;

revoke all on function public.try_claim_peak_push(text, date, int, int) from public;
grant execute on function public.try_claim_peak_push(text, date, int, int) to service_role;

select 'peak_push_claim_by_time ok' as status;
