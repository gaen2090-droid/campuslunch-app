-- 관리자 삭제 알림에 삭제된 글/댓글 원문 일부 포함 (Dashboard → SQL Editor → Run)
-- 실행 순서: community_post_auto_subscribe.sql 이후 (community_inbox_notifications()를
-- 다시 재정의하므로 반드시 마지막에 실행)
--
-- 지금까지는 삭제 사유만 저장돼서, 알림창에서 어떤 글/댓글이 삭제됐는지 알 수 없었다.
-- 삭제 직전(delete 전에) 원문을 잘라 저장해 알림에 함께 노출한다.

alter table public.admin_moderation_notifications
  add column if not exists content_excerpt text;

-- ── 게시글 삭제 ──

create or replace function public.admin_delete_community_post(
  p_post_id uuid,
  p_reason  text
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_author_id uuid;
  v_content   text;
begin
  if not public.is_admin() then
    raise exception '관리자만 삭제할 수 있어요.';
  end if;

  select user_id, content into v_author_id, v_content
  from public.community_posts
  where id = p_post_id;

  if v_author_id is null then
    raise exception '게시글을 찾을 수 없어요.';
  end if;

  insert into public.admin_moderation_notifications
    (recipient_user_id, target_kind, reason, content_excerpt)
  values (
    v_author_id,
    'post',
    nullif(trim(coalesce(p_reason, '')), ''),
    left(coalesce(v_content, ''), 200)
  );

  delete from public.community_posts where id = p_post_id;
end;
$$;

revoke all on function public.admin_delete_community_post(uuid, text) from public;
grant execute on function public.admin_delete_community_post(uuid, text) to authenticated;

-- ── 댓글 삭제 ──

create or replace function public.admin_delete_community_comment(
  p_comment_id uuid,
  p_reason     text
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_author_id uuid;
  v_content   text;
begin
  if not public.is_admin() then
    raise exception '관리자만 삭제할 수 있어요.';
  end if;

  select user_id, content into v_author_id, v_content
  from public.community_comments
  where id = p_comment_id;

  if v_author_id is null then
    raise exception '댓글을 찾을 수 없어요.';
  end if;

  insert into public.admin_moderation_notifications
    (recipient_user_id, target_kind, reason, content_excerpt)
  values (
    v_author_id,
    'comment',
    nullif(trim(coalesce(p_reason, '')), ''),
    left(coalesce(v_content, ''), 200)
  );

  delete from public.community_comments where id = p_comment_id;
end;
$$;

revoke all on function public.admin_delete_community_comment(uuid, text) from public;
grant execute on function public.admin_delete_community_comment(uuid, text) to authenticated;

-- ── 컬렉션 삭제 (유저 작성 컬렉션만 알림) ──

create or replace function public.admin_delete_collection(
  p_collection_id uuid,
  p_reason        text
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_author_id uuid;
  v_title     text;
  v_exists    boolean;
begin
  if not public.is_admin() then
    raise exception '관리자만 삭제할 수 있어요.';
  end if;

  select user_id, title, true into v_author_id, v_title, v_exists
  from public.collections
  where id = p_collection_id;

  if not coalesce(v_exists, false) then
    raise exception '컬렉션을 찾을 수 없어요.';
  end if;

  if v_author_id is not null then
    insert into public.admin_moderation_notifications
      (recipient_user_id, target_kind, reason, content_excerpt)
    values (
      v_author_id,
      'collection',
      nullif(trim(coalesce(p_reason, '')), ''),
      left(coalesce(v_title, ''), 200)
    );
  end if;

  delete from public.collections where id = p_collection_id;
end;
$$;

revoke all on function public.admin_delete_collection(uuid, text) from public;
grant execute on function public.admin_delete_collection(uuid, text) to authenticated;

-- ── 인박스 RPC: 관리자 알림에 content_excerpt 포함 (post_content 컬럼 재사용) ──

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
      coalesce(n.content_excerpt, '')::text as post_content,
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

select 'admin_moderation_content_excerpt.sql ok' as status;
