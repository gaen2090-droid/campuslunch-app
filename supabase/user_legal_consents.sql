-- 약관 동의 이력 (법정 증빙용, 서버 DB 기록)
-- Dashboard → SQL Editor → Run (users_auth.sql 이후)

create table if not exists public.user_legal_consents (
  id           uuid primary key default gen_random_uuid(),
  user_id      uuid not null references public.users(id) on delete cascade,
  term_id      text not null,       -- legal_terms.dart / app_permissions.dart의 id (privacy, terms, operation, reward, location, notification 등)
  term_label   text not null,       -- 동의 시점의 약관 명칭(표시용 스냅샷)
  agreed       boolean not null,    -- true=동의, false=거부(선택 항목 미동의 기록용)
  agreed_at    timestamptz not null default now()
);

create index if not exists idx_user_legal_consents_user
  on public.user_legal_consents(user_id, agreed_at desc);

alter table public.user_legal_consents enable row level security;

drop policy if exists "user_legal_consents_select_own" on public.user_legal_consents;
create policy "user_legal_consents_select_own" on public.user_legal_consents
  for select using (user_id = auth.uid());

-- INSERT는 record_legal_consent RPC(security definer)만 허용

comment on table public.user_legal_consents is '약관/권한 동의 이력. 회원 탈퇴 시에도 법정 증빙 목적으로 보존(user_id FK만 cascade 대상에서 제외하려면 delete_own_account.sql에서 이 테이블 delete 구문을 제거할 것).';
