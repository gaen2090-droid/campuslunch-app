-- FCM 서버 배선 (시크릿 값은 이 파일에 넣지 말 것)
-- 1) create extension pg_net / pg_cron
-- 2) push_edge_runtime_config 에 URL + EDGE_PUSH_SECRET upsert
-- 3) notify_* 트리거 함수가 테이블을 읽도록 재정의
-- 4) community/peak FCM 플래그 ON
-- 5) cron: campuslunch-peak-push (* * * * *)
--
-- 적용: 원격에는 이미 적용됨. 새 환경에서는 시크릿을 준비한 뒤
--   supabase secrets set EDGE_PUSH_SECRET=...
--   후 /tmp 스크립트 패턴으로 upsert.

create extension if not exists pg_net with schema extensions;
create extension if not exists pg_cron with schema pg_catalog;

create table if not exists public.push_edge_runtime_config (
  id int primary key default 1 check (id = 1),
  community_url text not null,
  reward_url text not null,
  push_secret text not null,
  updated_at timestamptz not null default now()
);

alter table public.push_edge_runtime_config enable row level security;
revoke all on public.push_edge_runtime_config from public;
revoke all on public.push_edge_runtime_config from anon;
revoke all on public.push_edge_runtime_config from authenticated;
grant select on public.push_edge_runtime_config to service_role;

-- 예시 upsert (값을 채운 뒤 실행)
-- insert into public.push_edge_runtime_config (id, community_url, reward_url, push_secret)
-- values (
--   1,
--   'https://YOUR_REF.supabase.co/functions/v1/send-community-push',
--   'https://YOUR_REF.supabase.co/functions/v1/send-reward-push',
--   'YOUR_EDGE_PUSH_SECRET'
-- )
-- on conflict (id) do update set
--   community_url = excluded.community_url,
--   reward_url = excluded.reward_url,
--   push_secret = excluded.push_secret,
--   updated_at = now();

update public.push_notification_config
set
  community_fcm_enabled = true,
  peak_fcm_enabled = true,
  peak_local_schedule_enabled = true,
  updated_at = now()
where id = 1;

select 'fcm_push_wiring.sql template ok' as status;
