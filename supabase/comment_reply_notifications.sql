-- "내 댓글에 달린 답글" 알림 (자유게시판 + 맛집 컬렉션) (Dashboard → SQL Editor → Run)
-- 실행 순서: admin_moderation_content_excerpt.sql, collection_comment_likes_replies.sql 이후
--
-- 문제: 지금까지는 "구독 중인 글의 새 댓글"만 인박스에 떴다. 그래서 내가 구독하지
-- 않은 남의 글에 댓글을 달아두었는데 누가 그 댓글에 답글을 달면, 그 글 구독자가
-- 아니므로 답글 알림이 전혀 오지 않았다. "내가 쓴 댓글에 달린 답글"을 별도 kind로
-- 잡아 항상 알림이 가도록 한다(글 구독 여부와 무관).

-- ── 자유게시판 + 컬렉션 통합 인박스 RPC 재정의: reply kind 추가 ──

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
  is_read boolean,
  suspended_until timestamptz
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
        -- 내 댓글에 달린 답글은 아래 reply 브랜치가 전담 — 여기선 중복 방지로 제외.
        and not exists (
          select 1 from public.community_comments parent
          where parent.id = c.parent_comment_id
            and parent.user_id = auth.uid()
        )
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
    union all
    (
      -- 내 댓글에 달린 답글(자유게시판) — 그 글을 구독하지 않았어도 항상 알림.
      -- 부모 댓글 작성자가 나 자신이 답글을 단 경우(자문자답)는 제외.
      select
        'reply'::text,
        reply.id::text,
        p.id,
        parent.content,
        coalesce(u.nickname, '탈퇴한 사용자'),
        reply.content,
        reply.created_at
      from public.community_comments reply
      join public.community_comments parent on parent.id = reply.parent_comment_id
      join public.community_posts p on p.id = reply.post_id
      join public.users u on u.id = reply.user_id
      where not reply.is_hidden
        and not p.is_hidden
        and parent.user_id = auth.uid()
        and reply.user_id <> auth.uid()
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
      (r.event_id is not null) as is_read,
      null::timestamptz as suspended_until
    from base
    left join public.community_inbox_reads r
      on r.event_id = base.event_id and r.user_id = auth.uid()
  )
  union all
  (
    select
      case
        when n.target_kind in ('post', 'comment', 'collection')
          then ('admin_' || n.target_kind)
        else n.target_kind
      end::text as kind,
      n.id::text as event_id,
      null::uuid as post_id,
      coalesce(n.content_excerpt, '')::text as post_content,
      '캠런관리자'::text as actor_nickname,
      coalesce(n.reason, '')::text as body_text,
      n.created_at,
      false as is_read,
      n.suspended_until
    from public.admin_moderation_notifications n
    where n.recipient_user_id = auth.uid()
  )
  order by created_at desc
  limit 100;
$$;

revoke all on function public.community_inbox_notifications() from public;
grant execute on function public.community_inbox_notifications() to authenticated;

-- ── 맛집 컬렉션 전용 인박스 RPC: 신설 ──
-- 컬렉션은 대부분 관리자 큐레이션 글이라 "내 컬렉션에 댓글/좋아요" 알림은 불필요.
-- "내가 쓴 컬렉션 댓글에 달린 답글"만 알림 대상으로 한다.
-- community_inbox_notifications()와 동일 컬럼 형태로 반환해 앱에서
-- CommunityInboxNotification 모델을 그대로 재사용한다.
-- post_id 자리엔 collection_id를 담아 반환(앱에서 컬렉션 댓글 시트를 열 때 사용).

drop function if exists public.collection_inbox_notifications();
create or replace function public.collection_inbox_notifications()
returns table (
  kind text,
  event_id text,
  post_id uuid,
  post_content text,
  actor_nickname text,
  body_text text,
  created_at timestamptz,
  is_read boolean,
  suspended_until timestamptz
)
language sql
stable
security definer
set search_path = public
as $$
  with base as (
    (
      -- 내가 쓴 컬렉션 댓글에 달린 답글 — 컬렉션 작성자 여부와 무관하게 항상 알림.
      select
        'reply'::text as kind,
        reply.id::text as event_id,
        col.id as post_id,
        parent.content as post_content,
        coalesce(u.nickname, '탈퇴한 사용자') as actor_nickname,
        reply.content as body_text,
        reply.created_at
      from public.collection_comments reply
      join public.collection_comments parent on parent.id = reply.parent_comment_id
      join public.collections col on col.id = reply.collection_id
      join public.users u on u.id = reply.user_id
      where not reply.is_hidden
        and parent.user_id = auth.uid()
        and reply.user_id <> auth.uid()
    )
  )
  select
    base.kind,
    base.event_id,
    base.post_id,
    base.post_content,
    base.actor_nickname,
    base.body_text,
    base.created_at,
    (r.event_id is not null) as is_read,
    null::timestamptz as suspended_until
  from base
  left join public.community_inbox_reads r
    on r.event_id = base.event_id and r.user_id = auth.uid()
  order by created_at desc
  limit 100;
$$;

revoke all on function public.collection_inbox_notifications() from public;
grant execute on function public.collection_inbox_notifications() to authenticated;

-- ── 레드닷: 자유게시판 + 컬렉션 알림 모두 포함 ──

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
  )
  or exists (
    select 1
    from public.collection_inbox_notifications() n
    where n.created_at > coalesce(
      (select seen_at from public.community_inbox_last_seen where user_id = auth.uid()),
      '-infinity'::timestamptz
    )
  );
$$;

revoke all on function public.community_inbox_has_unread() from public;
grant execute on function public.community_inbox_has_unread() to authenticated;

select 'comment_reply_notifications.sql ok' as status;
