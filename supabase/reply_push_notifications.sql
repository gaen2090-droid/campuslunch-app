-- 답글 앱푸시(FCM): 자유게시판 + 맛집 컬렉션 (Dashboard → SQL Editor → Run)
-- 실행 순서: comment_reply_notifications.sql 이후.
--
-- "내가 쓴 댓글에 달린 답글"에 대해 별도 문구({nickname}님이 답글을 남겼어요)로 푸시를
-- 보낸다. 발송 여부는 기존 '커뮤니티 댓글 알림' 토글(user_notification_prefs.
-- community_comments) 하나로 통일 — 댓글/답글/좋아요 모두 이 토글을 본다.
--
-- 중복 방지: 답글이 달리면 부모 댓글 작성자에게는 "답글" 알림만 가야 하고
-- "새 댓글" 알림이 같이 가면 안 된다. 그래서 list_community_comment_push_recipients의
-- 대상에서 부모 댓글 작성자를 제외하고, 그 사람은 새 list_community_reply_push_recipients가
-- 전담한다.

-- ═══════════════════════════════════════════════════════════════
-- 1. push_notification_config에 답글 문구 컬럼 추가
-- ═══════════════════════════════════════════════════════════════

alter table public.push_notification_config
  add column if not exists community_reply_title_template text
    not null default '{nickname}님이 답글을 남겼어요';

alter table public.push_notification_config
  add column if not exists community_reply_body_template text
    not null default '{content}';

-- ═══════════════════════════════════════════════════════════════
-- 2. 자유게시판 댓글 푸시 수신자 재정의 — 부모 댓글 작성자 제외(답글 브랜치가 전담)
-- ═══════════════════════════════════════════════════════════════

create or replace function public.list_community_comment_push_recipients(p_comment_id uuid)
returns table (user_id uuid, token text, post_id uuid, comment_preview text, nickname text)
language sql
stable
security definer
set search_path = public
as $$
  with c as (
    select c.*, p.user_id as author_id, p.content as post_content
    from public.community_comments c
    join public.community_posts p on p.id = c.post_id
    where c.id = p_comment_id
      and not c.is_hidden
      and not p.is_hidden
  ),
  parent_author as (
    select parent.user_id as uid
    from c
    join public.community_comments parent on parent.id = c.parent_comment_id
  ),
  targets as (
    select distinct u.uid
    from c
    cross join lateral (
      select c.author_id as uid
      union
      select s.user_id
      from public.community_post_subscriptions s
      where s.post_id = c.post_id
    ) u
    where u.uid is distinct from (select user_id from c)
      and u.uid not in (select uid from parent_author where uid is not null)
  )
  select
    t.user_id,
    t.token,
    (select post_id from c),
    left(coalesce((select content from c), ''), 80),
    coalesce((select nickname from public.users where id = (select user_id from c)), '익명')
  from targets tgt
  join public.user_push_tokens t on t.user_id = tgt.uid
  join public.user_notification_prefs p on p.user_id = tgt.uid
  where p.community_comments;
$$;

revoke all on function public.list_community_comment_push_recipients(uuid) from public;
grant execute on function public.list_community_comment_push_recipients(uuid) to service_role;

-- ═══════════════════════════════════════════════════════════════
-- 3. 자유게시판 답글 푸시 수신자 — 부모 댓글 작성자만 대상
-- ═══════════════════════════════════════════════════════════════

create or replace function public.list_community_reply_push_recipients(p_comment_id uuid)
returns table (user_id uuid, token text, post_id uuid, comment_preview text, nickname text)
language sql
stable
security definer
set search_path = public
as $$
  with reply as (
    select r.*, p.id as post_id_val
    from public.community_comments r
    join public.community_posts p on p.id = r.post_id
    where r.id = p_comment_id
      and not r.is_hidden
      and not p.is_hidden
  ),
  parent as (
    select parent.user_id as uid
    from reply
    join public.community_comments parent on parent.id = reply.parent_comment_id
    where parent.user_id <> reply.user_id
  )
  select
    t.user_id,
    t.token,
    (select post_id_val from reply),
    left(coalesce((select content from reply), ''), 80),
    coalesce((select nickname from public.users where id = (select user_id from reply)), '익명')
  from parent
  join public.user_push_tokens t on t.user_id = parent.uid
  join public.user_notification_prefs pref on pref.user_id = parent.uid
  where pref.community_comments;
$$;

revoke all on function public.list_community_reply_push_recipients(uuid) from public;
grant execute on function public.list_community_reply_push_recipients(uuid) to service_role;

-- ═══════════════════════════════════════════════════════════════
-- 4. 맛집 컬렉션 답글 푸시 수신자 — 부모 댓글 작성자만 대상
--    (컬렉션은 댓글/좋아요 알림 자체가 없으므로 답글 전용)
-- ═══════════════════════════════════════════════════════════════

create or replace function public.list_collection_reply_push_recipients(p_comment_id uuid)
returns table (user_id uuid, token text, collection_id uuid, comment_preview text, nickname text)
language sql
stable
security definer
set search_path = public
as $$
  with reply as (
    select r.*
    from public.collection_comments r
    where r.id = p_comment_id
      and not r.is_hidden
  ),
  parent as (
    select parent.user_id as uid
    from reply
    join public.collection_comments parent on parent.id = reply.parent_comment_id
    where parent.user_id <> reply.user_id
  )
  select
    t.user_id,
    t.token,
    (select collection_id from reply),
    left(coalesce((select content from reply), ''), 80),
    coalesce((select nickname from public.users where id = (select user_id from reply)), '익명')
  from parent
  join public.user_push_tokens t on t.user_id = parent.uid
  join public.user_notification_prefs pref on pref.user_id = parent.uid
  where pref.community_comments;
$$;

revoke all on function public.list_collection_reply_push_recipients(uuid) from public;
grant execute on function public.list_collection_reply_push_recipients(uuid) to service_role;

-- ═══════════════════════════════════════════════════════════════
-- 5. 트리거 함수 재정의 — 자유게시판(댓글/답글 구분해 event 명시)
-- ═══════════════════════════════════════════════════════════════

create or replace function public.notify_community_comment_push()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  edge_url text;
  edge_secret text;
  push_event text;
begin
  edge_url := nullif(current_setting('app.settings.edge_community_push_url', true), '');
  edge_secret := nullif(current_setting('app.settings.edge_push_secret', true), '');
  if edge_url is null then
    return new;
  end if;

  push_event := case when new.parent_comment_id is not null then 'reply' else 'comment' end;

  perform net.http_post(
    url := edge_url,
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'Authorization', coalesce('Bearer ' || edge_secret, '')
    ),
    body := jsonb_build_object(
      'event', push_event,
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
-- 6. 맛집 컬렉션 답글 트리거 — 답글(parent_comment_id 있는 경우)만 발송
--    (댓글 자체는 알림/푸시 대상 아님 — 불필요한 Edge 호출 방지)
-- ═══════════════════════════════════════════════════════════════

create or replace function public.notify_collection_reply_push()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  edge_url text;
  edge_secret text;
begin
  if new.parent_comment_id is null then
    return new;
  end if;

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
      'event', 'collection_reply',
      'comment_id', new.id
    )
  );
  return new;
exception
  when others then
    raise warning 'collection reply push webhook failed: %', sqlerrm;
    return new;
end;
$$;

drop trigger if exists collection_comments_fcm_push on public.collection_comments;
create trigger collection_comments_fcm_push
  after insert on public.collection_comments
  for each row execute function public.notify_collection_reply_push();

-- ═══════════════════════════════════════════════════════════════
-- 7. 어드민 설정 RPC — 답글 문구 파라미터 추가
--    (라이브 시그니처: jsonb, boolean, integer, boolean, boolean, boolean, text, text, boolean)
-- ═══════════════════════════════════════════════════════════════

drop function if exists public.admin_update_push_notification_config(
  jsonb, boolean, integer, boolean, boolean, boolean, text, text, boolean
);

create or replace function public.admin_update_push_notification_config(
  p_peak_schedules jsonb,
  p_weekdays_only boolean,
  p_schedule_days_ahead integer,
  p_peak_fcm_enabled boolean default false,
  p_community_fcm_enabled boolean default true,
  p_peak_local_schedule_enabled boolean default true,
  p_community_comment_title_template text default null,
  p_community_comment_body_template text default null,
  p_news_fcm_enabled boolean default true,
  p_community_reply_title_template text default null,
  p_community_reply_body_template text default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  result jsonb;
  elem jsonb;
  i int;
  v_id text;
  v_hour int;
  v_minute int;
  v_title text;
  v_body text;
  v_enabled boolean;
  enabled_count int := 0;
  lunch_h int := 12;
  lunch_m int := 0;
  dinner_h int := 18;
  dinner_m int := 0;
  sync_title text;
  sync_body text;
  seen_lunch boolean := false;
  seen_dinner boolean := false;
begin
  if not public.is_admin() then
    raise exception '관리자만 푸시 설정을 변경할 수 있어요.';
  end if;

  if p_peak_schedules is null or jsonb_typeof(p_peak_schedules) <> 'array' then
    raise exception '피크 스케줄 목록이 올바르지 않아요.';
  end if;
  if jsonb_array_length(p_peak_schedules) = 0 then
    raise exception '피크 스케줄을 1개 이상 추가해주세요.';
  end if;
  if jsonb_array_length(p_peak_schedules) > 8 then
    raise exception '피크 스케줄은 최대 8개까지예요.';
  end if;

  for i in 0 .. jsonb_array_length(p_peak_schedules) - 1 loop
    elem := p_peak_schedules -> i;
    v_id := nullif(trim(coalesce(elem ->> 'id', '')), '');
    v_hour := coalesce((elem ->> 'hour')::int, -1);
    v_minute := coalesce((elem ->> 'minute')::int, -1);
    v_title := trim(coalesce(elem ->> 'title_template', ''));
    v_body := trim(coalesce(elem ->> 'body_template', ''));
    v_enabled := coalesce((elem ->> 'enabled')::boolean, true);

    if v_id is null then
      raise exception '스케줄 id가 비어 있어요.';
    end if;
    if v_hour < 0 or v_hour > 23 or v_minute < 0 or v_minute > 59 then
      raise exception '스케줄 시각이 올바르지 않아요. (%)', v_id;
    end if;
    if v_title = '' then
      raise exception '스케줄 제목을 입력해주세요. (%)', v_id;
    end if;
    if v_body = '' then
      raise exception '스케줄 본문을 입력해주세요. (%)', v_id;
    end if;

    if v_enabled then
      enabled_count := enabled_count + 1;
    end if;

    if v_id = 'lunch' or (not seen_lunch and i = 0) then
      lunch_h := v_hour;
      lunch_m := v_minute;
      seen_lunch := true;
    end if;
    if v_id = 'dinner' or (not seen_dinner and i = 1) then
      dinner_h := v_hour;
      dinner_m := v_minute;
      seen_dinner := true;
    end if;

    if sync_title is null then
      sync_title := v_title;
      sync_body := v_body;
    end if;
  end loop;

  if enabled_count = 0 then
    raise exception '활성화된 피크 스케줄이 최소 1개 필요해요.';
  end if;

  update public.push_notification_config
  set
    peak_schedules = p_peak_schedules,
    lunch_hour = lunch_h,
    lunch_minute = lunch_m,
    dinner_hour = dinner_h,
    dinner_minute = dinner_m,
    title_template = coalesce(sync_title, title_template),
    body_template = coalesce(sync_body, body_template),
    weekdays_only = p_weekdays_only,
    schedule_days_ahead = greatest(1, least(coalesce(p_schedule_days_ahead, 14), 30)),
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
    news_fcm_enabled = coalesce(p_news_fcm_enabled, true),
    community_reply_title_template = coalesce(
      nullif(trim(p_community_reply_title_template), ''),
      community_reply_title_template
    ),
    community_reply_body_template = coalesce(
      nullif(trim(p_community_reply_body_template), ''),
      community_reply_body_template
    ),
    updated_at = now()
  where id = 1
  returning to_jsonb(push_notification_config.*) into result;

  return result;
end;
$$;

revoke all on function public.admin_update_push_notification_config(
  jsonb, boolean, integer, boolean, boolean, boolean, text, text, boolean, text, text
) from public;
grant execute on function public.admin_update_push_notification_config(
  jsonb, boolean, integer, boolean, boolean, boolean, text, text, boolean, text, text
) to authenticated;

select 'reply_push_notifications.sql ok' as status;
