-- 닉네임 예약어(완전 일치) 관리 (Dashboard → SQL Editor → Run)
--
-- is_reserved_nickname()은 시스템이 쓰는 고정 닉네임(자동 부여 기본값,
-- 탈퇴 익명화 값)과 완전히 같은 이름을 사용자가 직접 설정하지 못하게 막는
-- 함수다. is_nickname_available·is_nickname_taken 두 RPC에서만 호출되며,
-- delete_own_account()는 이 RPC를 거치지 않고 직접 UPDATE하므로 예약어
-- 목록에 '탈퇴한 회원'이 있어도 탈퇴(익명화) 자체는 깨지지 않는다.
-- 이 특성을 유지하기 위해 이 파일은 트리거를 추가하지 않는다 —
-- nickname_banned_words.sql(부분 일치 + 저장 시점 트리거)과는 별도 메커니즘.

create table if not exists public.nickname_reserved_words (
  id         uuid primary key default gen_random_uuid(),
  word       text not null unique,
  created_at timestamptz not null default now()
);

alter table public.nickname_reserved_words enable row level security;

drop policy if exists "nickname reserved words select all" on public.nickname_reserved_words;
create policy "nickname reserved words select all" on public.nickname_reserved_words
  for select to authenticated using (true);

drop policy if exists "nickname reserved words admin insert" on public.nickname_reserved_words;
create policy "nickname reserved words admin insert" on public.nickname_reserved_words
  for insert to authenticated with check (public.is_admin());

drop policy if exists "nickname reserved words admin delete" on public.nickname_reserved_words;
create policy "nickname reserved words admin delete" on public.nickname_reserved_words
  for delete to authenticated using (public.is_admin());

-- 기존 하드코딩 예약어를 시드로 반영
insert into public.nickname_reserved_words (word) values
  ('사용자'),
  ('카카오 사용자'),
  ('구글 사용자'),
  ('애플 사용자'),
  ('탈퇴한 회원'),
  ('탈퇴한 사용자')
on conflict (word) do nothing;

-- is_reserved_nickname()을 테이블 조회로 교체 (완전 일치, 대소문자·양끝 공백 무시).
-- immutable이 아니라 stable이어야 한다 — 테이블을 읽으므로 인자만으로 결과가
-- 고정되지 않는다(어드민이 단어를 추가/삭제하면 결과가 바뀐다).
create or replace function public.is_reserved_nickname(p_nickname text)
returns boolean
language sql
stable
as $$
  select exists (
    select 1
    from public.nickname_reserved_words w
    where lower(w.word) = lower(trim(p_nickname))
  );
$$;

select 'nickname_reserved_words.sql ok' as status;
