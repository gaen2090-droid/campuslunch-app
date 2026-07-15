-- 커뮤니티 인박스 알림 읽음 상태 서버 추적 (Dashboard → SQL Editor → Run)
-- 실행 순서: admin_moderation_notifications.sql, community_inbox_subscription_since.sql 이후
--
-- 두 가지를 분리해서 서버로 옮긴다:
-- 1) 레드닷(진입 뱃지) — 기존엔 로컬(SharedPreferences)의 "마지막 확인 시각" 기준.
--    이제 서버 테이블(community_inbox_last_seen)의 시각 기준으로 판단(여러 기기 동일하게).
--    관리자 알림(admin_*)도 이 시각 기준 포함 — 인박스 화면에 진입하면 그 시점까지의
--    모든 알림(관리자 포함)이 "확인됨" 처리된다. 관리자 카드는 탭이 없어 개별 읽음
--    경로가 없으므로, 레드닷은 반드시 이 화면-진입 시각 기준이어야 한다(카드별 읽음
--    테이블만으로 판단하면 관리자 알림이 있는 유저는 영원히 레드닷이 안 꺼짐).
-- 2) 카드별 읽음(초록→흰 배경) — 댓글/좋아요 카드에 한해 개별 이벤트 읽음을 기록.
--    관리자 카드는 항상 분홍 배경 유지(읽음 개념 없음).

create table if not exists public.community_inbox_last_seen (
  user_id  uuid primary key references public.users(id) on delete cascade,
  seen_at  timestamptz not null default now()
);

alter table public.community_inbox_last_seen enable row level security;

drop policy if exists "inbox last seen select own" on public.community_inbox_last_seen;
create policy "inbox last seen select own" on public.community_inbox_last_seen
  for select to authenticated using (user_id = auth.uid());

create table if not exists public.community_inbox_reads (
  user_id  uuid not null references public.users(id) on delete cascade,
  event_id text not null,
  read_at  timestamptz not null default now(),
  primary key (user_id, event_id)
);

alter table public.community_inbox_reads enable row level security;

drop policy if exists "inbox reads select own" on public.community_inbox_reads;
create policy "inbox reads select own" on public.community_inbox_reads
  for select to authenticated using (user_id = auth.uid());

-- insert/delete는 아래 security definer RPC를 통해서만.

-- ── 카드별 읽음 처리 RPC (댓글/좋아요 카드 탭 시) ──

create or replace function public.mark_community_inbox_read(p_event_id text)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
begin
  if v_uid is null then
    raise exception '로그인이 필요해요.';
  end if;

  insert into public.community_inbox_reads (user_id, event_id)
  values (v_uid, p_event_id)
  on conflict (user_id, event_id) do nothing;
end;
$$;

revoke all on function public.mark_community_inbox_read(text) from public;
grant execute on function public.mark_community_inbox_read(text) to authenticated;

-- ── 인박스 화면 진입 시각 갱신 RPC (레드닷 해제) ──

create or replace function public.mark_community_inbox_seen()
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
begin
  if v_uid is null then
    raise exception '로그인이 필요해요.';
  end if;

  insert into public.community_inbox_last_seen (user_id, seen_at)
  values (v_uid, now())
  on conflict (user_id) do update set seen_at = excluded.seen_at;
end;
$$;

revoke all on function public.mark_community_inbox_seen() from public;
grant execute on function public.mark_community_inbox_seen() to authenticated;

-- ── 인박스 RPC: 카드별 읽음 여부(is_read) 컬럼 추가 ──
-- 관리자 알림(admin_*)은 read_at 조인 없이 항상 false(분홍 배경 유지, 읽음 개념 없음).

drop function if exists public.community_inbox_notifications();
create or replace function public.community_inbox_notifications()
returns table (
  kind text,
  event_id text,
  post_id uuid,
  post_content text,
  actor_nickname text,
  body_text text,
  created_at timestamptz,
  is_read boolean
)
language sql
stable
security definer
set search_path = public
as $$
  with base as (
    (
      select
        'comment'::text as kind,
        c.id::text as event_id,
        c.post_id,
        p.content as post_content,
        coalesce(u.nickname, '탈퇴한 사용자') as actor_nickname,
        c.content as body_text,
        c.created_at
      from public.community_comments c
      join public.community_posts p on p.id = c.post_id
      join public.users u on u.id = c.user_id
      where not c.is_hidden
        and not p.is_hidden
        and c.user_id <> auth.uid()
        and (
          p.user_id = auth.uid()
          or exists (
            select 1 from public.community_post_subscriptions s
            where s.post_id = p.id
              and s.user_id = auth.uid()
              and c.created_at >= s.created_at
          )
        )
    )
    union all
    (
      select
        'like'::text,
        (l.post_id::text || ':' || l.user_id::text),
        l.post_id,
        p.content,
        coalesce(u.nickname, '탈퇴한 사용자'),
        left(coalesce(p.content, ''), 80),
        l.created_at
      from public.community_likes l
      join public.community_posts p on p.id = l.post_id
      join public.users u on u.id = l.user_id
      where not p.is_hidden
        and p.user_id = auth.uid()
        and l.user_id <> auth.uid()
    )
  )
  (
    select
      base.kind,
      base.event_id,
      base.post_id,
      base.post_content,
      base.actor_nickname,
      base.body_text,
      base.created_at,
      (r.event_id is not null) as is_read
    from base
    left join public.community_inbox_reads r
      on r.event_id = base.event_id and r.user_id = auth.uid()
  )
  union all
  (
    select
      ('admin_' || n.target_kind)::text as kind,
      n.id::text as event_id,
      null::uuid as post_id,
      null::text as post_content,
      '캠런관리자'::text as actor_nickname,
      coalesce(n.reason, '')::text as body_text,
      n.created_at,
      false as is_read
    from public.admin_moderation_notifications n
    where n.recipient_user_id = auth.uid()
  )
  order by created_at desc
  limit 100;
$$;

revoke all on function public.community_inbox_notifications() from public;
grant execute on function public.community_inbox_notifications() to authenticated;

-- ── 레드닷 여부: 마지막 인박스 화면 진입 이후 생긴 알림(관리자 포함)이 있는지 ──

create or replace function public.community_inbox_has_unread()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.community_inbox_notifications() n
    where n.created_at > coalesce(
      (select seen_at from public.community_inbox_last_seen where user_id = auth.uid()),
      '-infinity'::timestamptz
    )
  );
$$;

revoke all on function public.community_inbox_has_unread() from public;
grant execute on function public.community_inbox_has_unread() to authenticated;

select 'community_inbox_read_state.sql ok' as status;
