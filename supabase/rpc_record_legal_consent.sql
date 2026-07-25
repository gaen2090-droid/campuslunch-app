-- 약관 동의 이력 기록 RPC
-- Dashboard → SQL Editor → Run (user_legal_consents.sql 이후)

create or replace function public.record_legal_consent(
  p_term_id text,
  p_term_label text,
  p_agreed boolean
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  uid uuid := auth.uid();
begin
  if uid is null then
    raise exception 'NOT_AUTHENTICATED';
  end if;

  insert into public.user_legal_consents (user_id, term_id, term_label, agreed)
  values (uid, p_term_id, p_term_label, p_agreed);
end;
$$;

revoke all on function public.record_legal_consent(text, text, boolean) from public;
grant execute on function public.record_legal_consent(text, text, boolean) to authenticated;
