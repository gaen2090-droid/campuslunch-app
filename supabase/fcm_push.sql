-- FCM 원격 푸시: 기기 토큰 · 알림 선호 · 피크 발송 로그 · 댓글 웹훅 헬퍼
-- Dashboard → SQL Editor → Run (전체)

-- ═══════════════════════════════════════════════════════════════
-- 1. 토큰 / 선호 / 발송 로그
-- ═══════════════════════════════════════════════════════════════

create table if not exists public.user_push_tokens (
  id         uuid primary key default gen_random_uuid(),
  user_id    uuid not null references public.users(id) on delete cascade,
  token      text not null,
  platform   text not null check (platform in ('ios', 'android', 'web', 'unknown')),
  updated_at timestamptz not null default now(),
  unique (user_id, token)
);

create index if not exists user_push_tokens_user_idx
  on public.user_push_tokens (user_id);

create table if not exists public.user_notification_prefs (
  user_id              uuid primary key references public.users(id) on delete cascade,
  peak_lunch           boolean not null default true,
  peak_dinner          boolean not null default true,
  community_comments   boolean not null default true,
  updated_at           timestamptz not null default now()
);

create table if not exists public.peak_push_sent_log (
  sent_date  date not null,
  slot       text not null,
  hour       int not null default 0 check (hour >= 0 and hour <= 23),
  minute     int not null default 0 check (minute >= 0 and minute <= 59),
  created_at timestamptz not null default now(),
  primary key (sent_date, slot, hour, minute)
);

alter table public.user_push_tokens enable row level security;
alter table public.user_notification_prefs enable row level security;

drop policy if exists "push_tokens_select_own" on public.user_push_tokens;
create policy "push_tokens_select_own" on public.user_push_tokens
  for select to authenticated using (user_id = auth.uid());

drop policy if exists "push_tokens_insert_own" on public.user_push_tokens;
create policy "push_tokens_insert_own" on public.user_push_tokens
  for insert to authenticated with check (user_id = auth.uid());

drop policy if exists "push_tokens_update_own" on public.user_push_tokens;
create policy "push_tokens_update_own" on public.user_push_tokens
  for update to authenticated using (user_id = auth.uid()) with check (user_id = auth.uid());

drop policy if exists "push_tokens_delete_own" on public.user_push_tokens;
create policy "push_tokens_delete_own" on public.user_push_tokens
  for delete to authenticated using (user_id = auth.uid());

drop policy if exists "notif_prefs_select_own" on public.user_notification_prefs;
create policy "notif_prefs_select_own" on public.user_notification_prefs
  for select to authenticated using (user_id = auth.uid());

drop policy if exists "notif_prefs_upsert_own" on public.user_notification_prefs;
create policy "notif_prefs_upsert_own" on public.user_notification_prefs
  for all to authenticated using (user_id = auth.uid()) with check (user_id = auth.uid());

-- ═══════════════════════════════════════════════════════════════
-- 2. 앱 RPC: 토큰 Upsert / 삭제 · 선호 저장
-- ═══════════════════════════════════════════════════════════════

create or replace function public.upsert_push_token(
  p_token text,
  p_platform text
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  uid uuid := auth.uid();
  plat text := coalesce(nullif(trim(p_platform), ''), 'unknown');
begin
  if uid is null then
    raise exception 'NOT_AUTHENTICATED';
  end if;
  if trim(coalesce(p_token, '')) = '' then
    raise exception 'TOKEN_REQUIRED';
  end if;
  if plat not in ('ios', 'android', 'web', 'unknown') then
    plat := 'unknown';
  end if;

  -- 동일 토큰이 다른 계정에 있으면 제거 (기기 재로그인)
  delete from public.user_push_tokens
  where token = trim(p_token) and user_id <> uid;

  insert into public.user_push_tokens (user_id, token, platform, updated_at)
  values (uid, trim(p_token), plat, now())
  on conflict (user_id, token) do update
    set platform = excluded.platform,
        updated_at = now();
end;
$$;

revoke all on function public.upsert_push_token(text, text) from public;
grant execute on function public.upsert_push_token(text, text) to authenticated;

create or replace function public.delete_push_token(p_token text)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  uid uuid := auth.uid();
begin
  if uid is null then
    raise exception 'NOT_AUTHENTICATED';
  end if;
  delete from public.user_push_tokens
  where user_id = uid and token = trim(coalesce(p_token, ''));
end;
$$;

revoke all on function public.delete_push_token(text) from public;
grant execute on function public.delete_push_token(text) to authenticated;

create or replace function public.upsert_notification_prefs(
  p_peak_lunch boolean,
  p_peak_dinner boolean,
  p_community_comments boolean
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  uid uuid := auth.uid();
  result jsonb;
begin
  if uid is null then
    raise exception 'NOT_AUTHENTICATED';
  end if;

  insert into public.user_notification_prefs (
    user_id, peak_lunch, peak_dinner, community_comments, updated_at
  )
  values (
    uid,
    coalesce(p_peak_lunch, true),
    coalesce(p_peak_dinner, true),
    coalesce(p_community_comments, true),
    now()
  )
  on conflict (user_id) do update set
    peak_lunch = excluded.peak_lunch,
    peak_dinner = excluded.peak_dinner,
    community_comments = excluded.community_comments,
    updated_at = now()
  returning to_jsonb(user_notification_prefs.*) into result;

  return result;
end;
$$;

revoke all on function public.upsert_notification_prefs(boolean, boolean, boolean) from public;
grant execute on function public.upsert_notification_prefs(boolean, boolean, boolean) to authenticated;

create or replace function public.get_notification_prefs()
returns jsonb
language sql
security definer
stable
set search_path = public
as $$
  select coalesce(
    (
      select to_jsonb(p)
      from public.user_notification_prefs p
      where p.user_id = auth.uid()
    ),
    jsonb_build_object(
      'user_id', auth.uid(),
      'peak_lunch', true,
      'peak_dinner', true,
      'community_comments', true
    )
  );
$$;

revoke all on function public.get_notification_prefs() from public;
grant execute on function public.get_notification_prefs() to authenticated;

-- ═══════════════════════════════════════════════════════════════
-- 3. 피크 추천 매장 선정 (앱 Dart 규칙 단순화: 여유/약간혼잡 · 최신순)
-- ═══════════════════════════════════════════════════════════════

create or replace function public.pick_peak_push_restaurant()
returns table (
  restaurant_id uuid,
  restaurant_name text,
  area text,
  gate text,
  display_level int
)
language sql
stable
security definer
set search_path = public
as $$
  select
    r.id,
    r.name,
    coalesce(r.area::text, '') as area,
    case
      when coalesce(r.area::text, '') like '%정문%' then '정문'
      when coalesce(r.area::text, '') like '%중문%' then '중문'
      when coalesce(r.area::text, '') like '%후문%' then '후문'
      when coalesce(r.area::text, '') like '%학교%'
        or coalesce(r.area::text, '') like '%학생%' then '학교'
      else '캠퍼스'
    end as gate,
    cs.display_level
  from public.restaurants r
  join public.crowd_status cs on cs.restaurant_id = r.id
  where coalesce(r.is_active, true)
    and cs.display_level in (1, 2) -- 1=여유로움, 2=약간혼잡
  order by
    floor(extract(epoch from (now() - coalesce(cs.last_applied_report_at, cs.updated_at))) / 60 / 60),
    cs.display_level asc,
    coalesce(cs.last_applied_report_at, cs.updated_at) desc
  limit 1;
$$;

revoke all on function public.pick_peak_push_restaurant() from public;
grant execute on function public.pick_peak_push_restaurant() to service_role;

-- 피크 수신자 토큰
create or replace function public.list_peak_push_tokens(p_slot text)
returns table (user_id uuid, token text)
language sql
stable
security definer
set search_path = public
as $$
  select t.user_id, t.token
  from public.user_push_tokens t
  join public.user_notification_prefs p on p.user_id = t.user_id
  where (
    (p_slot = 'lunch' and p.peak_lunch)
    or (p_slot = 'dinner' and p.peak_dinner)
  );
$$;

revoke all on function public.list_peak_push_tokens(text) from public;
grant execute on function public.list_peak_push_tokens(text) to service_role;

-- 커뮤니티 댓글 푸시 수신자
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

-- 중복 발송 방지: 같은 날짜·슬롯·시·분만 (시각 바꾸면 당일 재발송 가능)
create or replace function public.try_claim_peak_push(
  p_slot text,
  p_date date default (timezone('Asia/Seoul', now()))::date,
  p_hour int default null,
  p_minute int default null
)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
declare
  inserted int;
  v_hour int;
  v_minute int;
  v_slot text;
begin
  v_slot := nullif(trim(coalesce(p_slot, '')), '');
  if v_slot is null then
    return false;
  end if;

  v_hour := coalesce(p_hour, extract(hour from timezone('Asia/Seoul', now()))::int);
  v_minute := coalesce(p_minute, extract(minute from timezone('Asia/Seoul', now()))::int);

  if v_hour < 0 or v_hour > 23 or v_minute < 0 or v_minute > 59 then
    return false;
  end if;

  insert into public.peak_push_sent_log (sent_date, slot, hour, minute)
  values (p_date, v_slot, v_hour, v_minute)
  on conflict do nothing;
  get diagnostics inserted = row_count;
  return inserted > 0;
end;
$$;

revoke all on function public.try_claim_peak_push(text, date, int, int) from public;
grant execute on function public.try_claim_peak_push(text, date, int, int) to service_role;

-- ═══════════════════════════════════════════════════════════════
-- 4. 댓글 INSERT → Edge Function 호출 (pg_net)
--    secrets: app.settings.edge_push_url, app.settings.edge_push_secret
--    (또는 아래 기본값 주석 / Dashboard Database Webhook 사용)
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
    body := jsonb_build_object('comment_id', new.id)
  );
  return new;
exception
  when others then
    -- 푸시 실패가 댓글 저장을 막지 않음
    raise warning 'community push webhook failed: %', sqlerrm;
    return new;
end;
$$;

drop trigger if exists community_comments_fcm_push on public.community_comments;
create trigger community_comments_fcm_push
  after insert on public.community_comments
  for each row execute function public.notify_community_comment_push();

-- 확인
select 'fcm_push.sql ok' as status;
