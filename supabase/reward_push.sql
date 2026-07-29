-- 리워드(기프티콘) 지급 알림 푸시
-- Dashboard → SQL Editor → Run (fcm_push.sql 이후)

-- ═══════════════════════════════════════════════════════════════
-- 1. user_notification_prefs에 reward_gifticon 컬럼 추가
-- ═══════════════════════════════════════════════════════════════

alter table public.user_notification_prefs
  add column if not exists reward_gifticon boolean not null default true;

-- ═══════════════════════════════════════════════════════════════
-- 2. upsert_notification_prefs / get_notification_prefs 재정의
--    (기존 3-인자 오버로드가 남지 않도록 반드시 DROP 후 재생성)
-- ═══════════════════════════════════════════════════════════════

drop function if exists public.upsert_notification_prefs(boolean, boolean, boolean);

create or replace function public.upsert_notification_prefs(
  p_peak_lunch boolean,
  p_peak_dinner boolean,
  p_community_comments boolean,
  p_reward_gifticon boolean default true
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
    user_id, peak_lunch, peak_dinner, community_comments, reward_gifticon, updated_at
  )
  values (
    uid,
    coalesce(p_peak_lunch, true),
    coalesce(p_peak_dinner, true),
    coalesce(p_community_comments, true),
    coalesce(p_reward_gifticon, true),
    now()
  )
  on conflict (user_id) do update set
    peak_lunch = excluded.peak_lunch,
    peak_dinner = excluded.peak_dinner,
    community_comments = excluded.community_comments,
    reward_gifticon = excluded.reward_gifticon,
    updated_at = now()
  returning to_jsonb(user_notification_prefs.*) into result;

  return result;
end;
$$;

revoke all on function public.upsert_notification_prefs(boolean, boolean, boolean, boolean) from public;
grant execute on function public.upsert_notification_prefs(boolean, boolean, boolean, boolean) to authenticated;

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
      'community_comments', true,
      'reward_gifticon', true
    )
  );
$$;

revoke all on function public.get_notification_prefs() from public;
grant execute on function public.get_notification_prefs() to authenticated;

-- ═══════════════════════════════════════════════════════════════
-- 3. 리워드 지급 푸시 수신자 토큰 (특정 유저 1명, 동의한 경우만)
-- ═══════════════════════════════════════════════════════════════

create or replace function public.list_reward_push_tokens(p_user_id uuid)
returns table (token text)
language sql
stable
security definer
set search_path = public
as $$
  select t.token
  from public.user_push_tokens t
  join public.user_notification_prefs p on p.user_id = t.user_id
  where t.user_id = p_user_id
    and p.reward_gifticon;
$$;

revoke all on function public.list_reward_push_tokens(uuid) from public;
grant execute on function public.list_reward_push_tokens(uuid) to service_role;

-- ═══════════════════════════════════════════════════════════════
-- 4. 기프티콘 배정(assigned) → Edge Function 호출 (pg_net)
--    secrets: app.settings.edge_reward_push_url, app.settings.edge_push_secret
-- ═══════════════════════════════════════════════════════════════

create or replace function public.notify_reward_gifticon_push()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  edge_url text;
  edge_secret text;
begin
  -- 이미 assigned 상태였다면(재배정 등) 중복 알림 방지
  if old.status = 'assigned' then
    return new;
  end if;
  if new.assigned_user_id is null then
    return new;
  end if;

  edge_url := nullif(current_setting('app.settings.edge_reward_push_url', true), '');
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
      'user_id', new.assigned_user_id,
      'gifticon_id', new.id,
      'brand', new.brand,
      'product_name', new.product_name
    )
  );
  return new;
exception
  when others then
    -- 푸시 실패가 기프티콘 배정을 막지 않음
    raise warning 'reward push webhook failed: %', sqlerrm;
    return new;
end;
$$;

drop trigger if exists gifticons_reward_push on public.gifticons;
create trigger gifticons_reward_push
  after update on public.gifticons
  for each row
  when (new.status = 'assigned')
  execute function public.notify_reward_gifticon_push();

select 'reward_push.sql ok' as status;
