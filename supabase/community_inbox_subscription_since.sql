-- 구독(알림 켠 글) 댓글 알림을 구독 시작 시점 이후로 제한 (Dashboard → SQL Editor → Run)
-- 실행 순서: admin_moderation_notifications.sql 이후
--
-- 문제: 남의 글에 알림을 켜면, 켜기 이전에 이미 달려있던 예전 댓글까지 인박스에
-- 나타남. 구독 레코드의 created_at(구독 시작 시각) 이후에 달린 댓글만 노출하도록
-- 제한한다. 내 글에 달린 댓글(구독 여부 무관)은 기존과 동일하게 항상 노출.

drop function if exists public.community_inbox_notifications();
create or replace function public.community_inbox_notifications()
returns table (
  kind text,
  event_id text,
  post_id uuid,
  post_content text,
  actor_nickname text,
  body_text text,
  created_at timestamptz
)
language sql
stable
security definer
set search_path = public
as $$
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
  union all
  (
    select
      ('admin_' || n.target_kind)::text as kind,
      n.id::text as event_id,
      null::uuid as post_id,
      null::text as post_content,
      '캠런관리자'::text as actor_nickname,
      coalesce(n.reason, '')::text as body_text,
      n.created_at
    from public.admin_moderation_notifications n
    where n.recipient_user_id = auth.uid()
  )
  order by created_at desc
  limit 100;
$$;

revoke all on function public.community_inbox_notifications() from public;
grant execute on function public.community_inbox_notifications() to authenticated;

select 'community_inbox_subscription_since.sql ok' as status;
