-- 닉네임 금칙어(욕설 + 사칭/브랜드 도용) 관리 (Dashboard → SQL Editor → Run)
--
-- community_banned_words.sql과 동일 패턴: 관리자가 웹어드민에서 추가/삭제,
-- 앱은 부팅 시 조회해 클라이언트 필터에 반영. 서버 트리거로 실제 저장 시점에도
-- 막아서 클라이언트(또는 API 직접 호출) 우회를 방지한다.

create table if not exists public.nickname_banned_words (
  id         uuid primary key default gen_random_uuid(),
  word       text not null unique,
  created_at timestamptz not null default now()
);

alter table public.nickname_banned_words enable row level security;

drop policy if exists "nickname banned words select all" on public.nickname_banned_words;
create policy "nickname banned words select all" on public.nickname_banned_words
  for select to authenticated using (true);

drop policy if exists "nickname banned words admin insert" on public.nickname_banned_words;
create policy "nickname banned words admin insert" on public.nickname_banned_words
  for insert to authenticated with check (public.is_admin());

drop policy if exists "nickname banned words admin delete" on public.nickname_banned_words;
create policy "nickname banned words admin delete" on public.nickname_banned_words
  for delete to authenticated using (public.is_admin());

-- 기존 클라이언트 하드코딩 목록(욕설 + 사칭성 예약어)을 시드로 반영
insert into public.nickname_banned_words (word) values
  ('씨발'), ('시발'), ('병신'), ('개새끼'), ('새끼'), ('지랄'), ('좆'),
  ('창녀'), ('걸레'), ('느금'), ('니미'), ('엠창'), ('보지'), ('자지'),
  ('ㅅㅂ'), ('ㅂㅅ'), ('ㅈㄹ'),
  ('캠퍼스런치'), ('캠런'), ('운영자'), ('관리자'),
  ('캠런관리자'), ('캠런운영자'), ('캠퍼스런치관리자'), ('캠퍼스런치운영자'),
  ('admin'), ('administrator'), ('operator')
on conflict (word) do nothing;

-- 저장 시점에 부분 포함(substring) 검사. nickname_banned_words 테이블을 참조하므로
-- 어드민에서 단어를 추가/삭제하면 바로 반영된다.
create or replace function public.contains_banned_nickname_word(p_nickname text)
returns boolean
language sql
stable
as $$
  select exists (
    select 1
    from public.nickname_banned_words b
    where lower(replace(p_nickname, ' ', '')) like '%' || lower(b.word) || '%'
  );
$$;

create or replace function public.enforce_nickname_banned_words()
returns trigger
language plpgsql
as $$
begin
  -- INSERT는 OLD가 없으므로(TG_OP 분기 없이 old.nickname을 참조하면
  -- "record old is not assigned yet" 에러) INSERT는 항상 검사, UPDATE는
  -- 닉네임이 실제로 바뀔 때만 검사한다.
  if TG_OP = 'INSERT' or new.nickname is distinct from old.nickname then
    -- delete_own_account() 등 시스템이 강제로 닉네임을 익명화(예: '탈퇴한 회원')할 때는
    -- 이 세션 변수를 켜서 검사를 우회한다 (nickname_change_lock_30d.sql과 동일 패턴).
    if coalesce(current_setting('app.bypass_nickname_lock', true), '') <> '1' then
      if public.contains_banned_nickname_word(new.nickname) then
        raise exception '사용할 수 없는 닉네임이에요.';
      end if;
    end if;
  end if;
  return new;
end;
$$;

drop trigger if exists trg_enforce_nickname_banned_words on public.users;
create trigger trg_enforce_nickname_banned_words
  before insert or update on public.users
  for each row
  execute function public.enforce_nickname_banned_words();

select 'nickname_banned_words.sql ok' as status;
