-- 마케팅 정보 수신 동의 최신 상태 조회 RPC (설정 화면 토글 초기값용)
-- Dashboard → SQL Editor → Run (user_legal_consents.sql 이후)

create or replace function public.fetch_marketing_consent()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select agreed
  from public.user_legal_consents
  where user_id = auth.uid()
    and term_id = 'marketing_consent'
  order by agreed_at desc
  limit 1;
$$;

revoke all on function public.fetch_marketing_consent() from public;
grant execute on function public.fetch_marketing_consent() to authenticated;
