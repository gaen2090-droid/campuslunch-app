-- 관리자 삭제(운영정책 위반) 알림 (Dashboard → SQL Editor → Run)
-- 실행 순서: community_push_v2.sql, community_user_collections_min5.sql 이후
--
-- 관리자가 글/댓글/컬렉션을 삭제할 때 사유를 입력하면, 삭제 직전에 알림을
-- 별도 테이블에 저장(삭제되는 원본 콘텐츠에는 더 이상 접근할 수 없으므로)한 뒤
-- 삭제한다. 앱의 커뮤니티 알림창에서 댓글/좋아요 알림과 함께 노출된다.

create table if not exists public.admin_moderation_notifications (
  id                uuid primary key default gen_random_uuid(),
  recipient_user_id uuid not null references public.users(id) on delete cascade,
  target_kind       text not null check (target_kind in ('post', 'comment', 'collection')),
  reason            text,
  created_at        timestamptz not null default now()
);

create index if not exists admin_moderation_notifications_recipient_idx
  on public.admin_moderation_notifications (recipient_user_id);

alter table public.admin_moderation_notifications enable row level security;

drop policy if exists "moderation notifications select own" on public.admin_moderation_notifications;
create policy "moderation notifications select own" on public.admin_moderation_notifications
  for select to authenticated using (recipient_user_id = auth.uid());

-- insert는 아래 security definer RPC를 통해서만 (관리자 검증 포함) — 직접 insert 정책 없음.

-- ── 게시글 삭제 (사유 저장 → 알림 → 삭제, 원자적) ──

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
begin
  if not public.is_admin() then
    raise exception '관리자만 삭제할 수 있어요.';
  end if;

  select user_id into v_author_id
  from public.community_posts
  where id = p_post_id;

  if v_author_id is null then
    raise exception '게시글을 찾을 수 없어요.';
  end if;

  insert into public.admin_moderation_notifications (recipient_user_id, target_kind, reason)
  values (v_author_id, 'post', nullif(trim(coalesce(p_reason, '')), ''));

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
begin
  if not public.is_admin() then
    raise exception '관리자만 삭제할 수 있어요.';
  end if;

  select user_id into v_author_id
  from public.community_comments
  where id = p_comment_id;

  if v_author_id is null then
    raise exception '댓글을 찾을 수 없어요.';
  end if;

  insert into public.admin_moderation_notifications (recipient_user_id, target_kind, reason)
  values (v_author_id, 'comment', nullif(trim(coalesce(p_reason, '')), ''));

  delete from public.community_comments where id = p_comment_id;
end;
$$;

revoke all on function public.admin_delete_community_comment(uuid, text) from public;
grant execute on function public.admin_delete_community_comment(uuid, text) to authenticated;

-- ── 컬렉션 삭제 (유저 작성 컬렉션만 알림, 관리자 큐레이션은 알림 없이 삭제) ──

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
  v_exists boolean;
begin
  if not public.is_admin() then
    raise exception '관리자만 삭제할 수 있어요.';
  end if;

  select user_id, true into v_author_id, v_exists
  from public.collections
  where id = p_collection_id;

  if not coalesce(v_exists, false) then
    raise exception '컬렉션을 찾을 수 없어요.';
  end if;

  if v_author_id is not null then
    insert into public.admin_moderation_notifications (recipient_user_id, target_kind, reason)
    values (v_author_id, 'collection', nullif(trim(coalesce(p_reason, '')), ''));
  end if;

  delete from public.collections where id = p_collection_id;
end;
$$;

revoke all on function public.admin_delete_collection(uuid, text) from public;
grant execute on function public.admin_delete_collection(uuid, text) to authenticated;

-- ── 인박스 RPC 갱신: 관리자 삭제 알림을 댓글/좋아요와 함께 노출 (post_id는 nullable) ──

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
          where s.post_id = p.id and s.user_id = auth.uid()
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

-- ── 어드민 컬렉션 목록에 작성자 정보 포함 (유저 작성 컬렉션 식별용) ──

create or replace function public.admin_list_collections()
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
begin
  if not public.is_admin() then
    raise exception '관리자만 조회할 수 있어요.';
  end if;

  return coalesce((
    select jsonb_agg(row_to_json(t) order by t.sort_order asc nulls last, t.created_at desc)
    from (
      select
        c.id,
        c.title,
        c.subtitle,
        c.sort_order,
        c.is_published,
        c.created_at,
        c.user_id,
        u.nickname as author_nickname
      from public.collections c
      left join public.users u on u.id = c.user_id
    ) t
  ), '[]'::jsonb);
end;
$$;

revoke all on function public.admin_list_collections() from public;
grant execute on function public.admin_list_collections() to authenticated;

select 'admin_moderation_notifications.sql ok' as status;
