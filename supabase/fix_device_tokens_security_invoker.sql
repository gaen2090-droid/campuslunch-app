-- Fix: public.device_tokens SECURITY DEFINER → SECURITY INVOKER
-- Advisor: "View public.device_tokens is defined with the SECURITY DEFINER property"
--
-- 원인: Postgres 뷰 기본이 생성자 권한(SECURITY DEFINER)이라,
--       호출자 RLS가 아니라 뷰 소유자(보통 postgres) 권한으로 실행됨.
--       → authenticated가 API로 뷰를 치면 user_push_tokens RLS를 우회해
--         타 유저 FCM 토큰까지 보일 수 있음.
--
-- 조치: security_invoker=on → 조회하는 유저의 RLS를 따름.
-- Dashboard → SQL Editor → Run (또는 supabase db query --linked -f …)

drop view if exists public.device_tokens;

create view public.device_tokens
with (security_invoker = on)
as
select id, user_id, token, platform, updated_at
from public.user_push_tokens;

-- 뷰 권한: 테이블과 동일하게 authenticated만 (anon 노출 금지)
revoke all on public.device_tokens from public;
revoke all on public.device_tokens from anon;
grant select on public.device_tokens to authenticated;
grant select on public.device_tokens to service_role;

select
  c.relname as view_name,
  c.reloptions as options
from pg_class c
join pg_namespace n on n.oid = c.relnamespace
where n.nspname = 'public'
  and c.relname = 'device_tokens';
