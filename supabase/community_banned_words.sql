-- 커뮤니티 금칙어 관리 (Dashboard → SQL Editor → Run)
-- 관리자가 웹어드민에서 추가/삭제, 앱은 부팅 시 조회해 클라이언트 필터에 반영.

create table if not exists public.community_banned_words (
  id         uuid primary key default gen_random_uuid(),
  word       text not null unique,
  created_at timestamptz not null default now()
);

alter table public.community_banned_words enable row level security;

drop policy if exists "banned words select all" on public.community_banned_words;
create policy "banned words select all" on public.community_banned_words
  for select to authenticated using (true);

drop policy if exists "banned words admin insert" on public.community_banned_words;
create policy "banned words admin insert" on public.community_banned_words
  for insert to authenticated with check (public.is_admin());

drop policy if exists "banned words admin delete" on public.community_banned_words;
create policy "banned words admin delete" on public.community_banned_words
  for delete to authenticated using (public.is_admin());

-- 기존 클라이언트 하드코딩 목록을 시드로 반영 (필터가 빈 상태로 시작하지 않도록)
insert into public.community_banned_words (word) values
  ('씨발'), ('시발'), ('병신'), ('개새끼'), ('새끼'), ('지랄'), ('좆'),
  ('창녀'), ('걸레'), ('느금'), ('니미'), ('엠창'), ('보지'), ('자지'),
  ('ㅅㅂ'), ('ㅂㅅ'), ('ㅈㄹ')
on conflict (word) do nothing;
