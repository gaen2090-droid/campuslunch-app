-- 커뮤니티 푸시 문구 템플릿 + 인박스(댓글·좋아요) + 좋아요 FCM 트리거
-- fcm_push.sql, admin_push_control.sql 이후 Run

-- ═══════════════════════════════════════════════════════════════
-- 1. 설정 컬럼 (피크 로컬 기본 + 커뮤니티 문구)
-- ═══════════════════════════════════════════════════════════════

alter table public.push_notification_config
  add column if not exists community_comment_title_template text
    not null default '{nickname}님이 댓글을 남겼어요';

alter table public.push_notification_config
  add column if not exists community_comment_body_template text
    not null default '{content}';

alter table public.push_notification_config
  add column if not exists community_like_title_template text
    not null default '{nickname}님이 좋아요를 눌렀어요';

alter table public.push_notification_config
  add column if not exists community_like_body_template text
    not null default '{post_preview}';

-- 피크: 로컬 예약이 기본, 서버 FCM은 옵션
alter table public.push_notification_config
  alter column peak_local_schedule_enabled set default true;

alter table public.push_notification_config
  alter column peak_fcm_enabled set default false;

update public.push_notification_config
set
  peak_local_schedule_enabled = true,
  peak_fcm_enabled = false
where id = 1;

-- ═══════════════════════════════════════════════════════════════
-- 2. 인박스 = 댓글(내 글·구독) + 좋아요(내 글만)
-- ═══════════════════════════════════════════════════════════════

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
  order by created_at desc
  limit 100;
$$;

revoke all on function public.community_inbox_notifications() from public;
grant execute on function public.community_inbox_notifications() to authenticated;

-- 기존 RPC 유지(댓글만) — 앱이 inbox로 이전하기 전 호환
create or replace function public.community_comment_notifications()
returns table (
  comment_id uuid,
  post_id uuid,
  post_content text,
  commenter_nickname text,
  comment_content text,
  created_at timestamptz
)
language sql
stable
security definer
set search_path = public
as $$
  select
    c.id as comment_id,
    c.post_id,
    p.content as post_content,
    u.nickname as commenter_nickname,
    c.content as comment_content,
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
  order by c.created_at desc
  limit 100;
$$;

-- 좋아요 푸시 수신자 = 글 작성자 (본인 제외) + 커뮤니티 푸시 ON
create or replace function public.list_community_like_push_recipients(
  p_post_id uuid,
  p_liker_id uuid
)
returns table (
  user_id uuid,
  token text,
  post_id uuid,
  post_preview text,
  nickname text
)
language sql
stable
security definer
set search_path = public
as $$
  select
    t.user_id,
    t.token,
    p.id as post_id,
    left(coalesce(p.content, ''), 80) as post_preview,
    coalesce(u.nickname, '익명') as nickname
  from public.community_posts p
  join public.user_push_tokens t on t.user_id = p.user_id
  join public.user_notification_prefs pref on pref.user_id = p.user_id
  join public.users u on u.id = p_liker_id
  where p.id = p_post_id
    and not p.is_hidden
    and p.user_id <> p_liker_id
    and pref.community_comments;
$$;

revoke all on function public.list_community_like_push_recipients(uuid, uuid) from public;
grant execute on function public.list_community_like_push_recipients(uuid, uuid) to service_role;

-- 좋아요 INSERT → Edge (pg_net, URL 설정 시)
create or replace function public.notify_community_like_push()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  edge_url text;
  edge_secret text;
begin
  edge_url := nullif(current_setting('app.settings.edge_community_push_url', true), '');
  edge_secret := nullif(current_setting('app.settings.edge_push_secret', true), '');
  if edge_url is null then
    return new;
  end if;

  perform net.http_post(
    url := edge_url,
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'Authorization', coalesce('Bearer ' || edge_secret, '')
    ),
    body := jsonb_build_object(
      'event', 'like',
      'post_id', new.post_id,
      'liker_id', new.user_id
    )
  );
  return new;
exception
  when others then
    raise warning 'community like push webhook failed: %', sqlerrm;
    return new;
end;
$$;

drop trigger if exists community_likes_fcm_push on public.community_likes;
create trigger community_likes_fcm_push
  after insert on public.community_likes
  for each row execute function public.notify_community_like_push();

-- 댓글 트리거 body에 event 명시 (기존 함수 갱신)
create or replace function public.notify_community_comment_push()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  edge_url text;
  edge_secret text;
begin
  edge_url := nullif(current_setting('app.settings.edge_community_push_url', true), '');
  edge_secret := nullif(current_setting('app.settings.edge_push_secret', true), '');
  if edge_url is null then
    return new;
  end if;

  perform net.http_post(
    url := edge_url,
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'Authorization', coalesce('Bearer ' || edge_secret, '')
    ),
    body := jsonb_build_object(
      'event', 'comment',
      'comment_id', new.id
    )
  );
  return new;
exception
  when others then
    raise warning 'community push webhook failed: %', sqlerrm;
    return new;
end;
$$;

-- ═══════════════════════════════════════════════════════════════
-- 3. 어드민 설정 RPC (피크 + 커뮤니티 문구)
-- ═══════════════════════════════════════════════════════════════

drop function if exists public.admin_update_push_notification_config(int, int, int, int, text, text, boolean, int, boolean, boolean, boolean);

create or replace function public.admin_update_push_notification_config(
  p_lunch_hour int,
  p_lunch_minute int,
  p_dinner_hour int,
  p_dinner_minute int,
  p_title_template text,
  p_body_template text,
  p_weekdays_only boolean,
  p_schedule_days_ahead int,
  p_peak_fcm_enabled boolean default false,
  p_community_fcm_enabled boolean default true,
  p_peak_local_schedule_enabled boolean default true,
  p_community_comment_title_template text default null,
  p_community_comment_body_template text default null,
  p_community_like_title_template text default null,
  p_community_like_body_template text default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  result jsonb;
begin
  if not public.is_admin() then
    raise exception '관리자만 푸시 설정을 변경할 수 있어요.';
  end if;

  if trim(coalesce(p_title_template, '')) = '' then
    raise exception '피크 제목 템플릿을 입력해주세요.';
  end if;
  if trim(coalesce(p_body_template, '')) = '' then
    raise exception '피크 본문을 입력해주세요.';
  end if;
  if position('{gate}' in p_title_template) = 0 then
    raise exception '피크 제목 템플릿에 {gate} 가 포함되어야 해요.';
  end if;

  update public.push_notification_config
  set
    lunch_hour = p_lunch_hour,
    lunch_minute = p_lunch_minute,
    dinner_hour = p_dinner_hour,
    dinner_minute = p_dinner_minute,
    title_template = trim(p_title_template),
    body_template = trim(p_body_template),
    weekdays_only = p_weekdays_only,
    schedule_days_ahead = p_schedule_days_ahead,
    peak_fcm_enabled = coalesce(p_peak_fcm_enabled, false),
    community_fcm_enabled = coalesce(p_community_fcm_enabled, true),
    peak_local_schedule_enabled = coalesce(p_peak_local_schedule_enabled, true),
    community_comment_title_template = coalesce(
      nullif(trim(p_community_comment_title_template), ''),
      community_comment_title_template
    ),
    community_comment_body_template = coalesce(
      nullif(trim(p_community_comment_body_template), ''),
      community_comment_body_template
    ),
    community_like_title_template = coalesce(
      nullif(trim(p_community_like_title_template), ''),
      community_like_title_template
    ),
    community_like_body_template = coalesce(
      nullif(trim(p_community_like_body_template), ''),
      community_like_body_template
    ),
    updated_at = now()
  where id = 1
  returning to_jsonb(push_notification_config.*) into result;

  return result;
end;
$$;

revoke all on function public.admin_update_push_notification_config(
  int, int, int, int, text, text, boolean, int, boolean, boolean, boolean, text, text, text, text
) from public;
grant execute on function public.admin_update_push_notification_config(
  int, int, int, int, text, text, boolean, int, boolean, boolean, boolean, text, text, text, text
) to authenticated;

select 'community_push_v2.sql ok' as status;
