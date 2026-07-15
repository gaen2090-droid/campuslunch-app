-- 내 글 작성 시 자동 구독(알림 켜짐) (Dashboard → SQL Editor → Run)
-- 실행 순서: community_notifications.sql, community_inbox_subscription_since.sql 이후
--
-- 게시글 상세화면의 "알림" 종 아이콘은 community_post_subscriptions 존재 여부로 on/off 표시됨.
-- 지금까지는 글을 써도 구독 레코드가 자동 생성되지 않아 "내 글인데 알림이 꺼진 상태"로 보였다.
-- community_posts INSERT 시 작성자 본인을 자동으로 구독시키는 트리거를 추가하고,
-- "댓글 알림 = 알림 켠 글의 댓글"이라는 규칙 하나로 통일한다(내 글/남의 글 구분 없이
-- 구독 여부만 본다). 좋아요 알림(내 글에 달린 좋아요)은 이 규칙과 무관하므로 그대로 둔다.
--
-- created_at을 글 작성 시각으로 맞춰야 한다 — community_inbox_notifications가
-- "c.created_at >= s.created_at"으로 구독 시작 이후 댓글만 노출하므로, now()로
-- 구독을 만들면 이미 존재하는 과거 댓글들이 전부 인박스에서 사라진다.

create or replace function public.community_auto_subscribe_own_post()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.community_post_subscriptions (post_id, user_id, created_at)
  values (new.id, new.user_id, new.created_at)
  on conflict (post_id, user_id) do nothing;
  return new;
end;
$$;

drop trigger if exists community_posts_auto_subscribe on public.community_posts;
create trigger community_posts_auto_subscribe
  after insert on public.community_posts
  for each row execute function public.community_auto_subscribe_own_post();

-- 기존에 이미 작성된 글도 소급 적용 — 작성자 본인을 구독자로 일괄 추가.
-- created_at = 글 작성 시각(now() 아님) — 과거 댓글이 인박스에서 사라지지 않도록.
insert into public.community_post_subscriptions (post_id, user_id, created_at)
select p.id, p.user_id, p.created_at
from public.community_posts p
on conflict (post_id, user_id) do nothing;

-- ── 인박스 RPC: 댓글 알림 조건을 "구독 여부" 하나로 통일 ──
-- 기존엔 "내 글(p.user_id = auth.uid()) OR 구독함"으로 내 글을 특별 취급했는데,
-- 이제 내 글도 작성 시 자동 구독되므로 이 OR가 없어도 동일하게 동작한다.
-- 좋아요 브랜치는 변경하지 않는다(원래도 "내 글"이어야만 알림 대상).

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
        and exists (
          select 1 from public.community_post_subscriptions s
          where s.post_id = p.id
            and s.user_id = auth.uid()
            and c.created_at >= s.created_at
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

select 'community_post_auto_subscribe.sql ok' as status;
