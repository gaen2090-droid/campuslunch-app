-- 앱스토어 제출 전 보안·정본 패치 (Dashboard → SQL Editor → Run)
-- 시크릿 값은 이 파일에 넣지 말 것. 푸시는 push_edge_runtime_config 를 읽는다.
-- 제보 RPC 정본은 이 파일이 아니라 submit_crowd_report.sql — 함께 Run.

-- ═══════════════════════════════════════════════════════════════
-- 1. 스탬프/기프티콘 민트 RPC — 클라이언트 실행 금지
--    grant_stamp / _perform_gifticon_redeem 은 SECURITY DEFINER 내부에서만 호출
-- ═══════════════════════════════════════════════════════════════

revoke all on function public.grant_stamp(uuid, int) from public;
revoke all on function public.grant_stamp(uuid, int) from anon;
revoke all on function public.grant_stamp(uuid, int) from authenticated;

revoke all on function public._perform_gifticon_redeem(uuid) from public;
revoke all on function public._perform_gifticon_redeem(uuid) from anon;
revoke all on function public._perform_gifticon_redeem(uuid) from authenticated;

-- ═══════════════════════════════════════════════════════════════
-- 2. crowd_reports RLS — 본인 user 제보만 / owner 는 본인 매장만
-- ═══════════════════════════════════════════════════════════════

drop policy if exists "crowd_reports_insert_auth" on public.crowd_reports;
create policy "crowd_reports_insert_auth" on public.crowd_reports
  for insert
  to authenticated
  with check (
    user_id = auth.uid()
    and (
      (
        source = 'user'::public.crowd_source
      )
      or (
        source = 'owner'::public.crowd_source
        and public.is_restaurant_owner(restaurant_id)
      )
    )
  );

-- 제보 좌표·user_id 가 anon 에 노출되지 않게 select 는 집계용 최소만 허용하지 않고
-- 기존 공개 읽기는 유지하되 metadata 좌표는 RPC 경로가 정본.
-- (앱이 crowd_reports 를 직접 select 하지 않음)

-- ═══════════════════════════════════════════════════════════════
-- 3. submit_crowd_report — 이 파일에 두지 않음
--    정본: supabase/submit_crowd_report.sql (이 핫픽스와 함께 Run)
-- ═══════════════════════════════════════════════════════════════

-- ═══════════════════════════════════════════════════════════════
-- 4. handle_new_user — 고정 닉네임 '사용자' 금지
-- ═══════════════════════════════════════════════════════════════

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path to 'public'
as $$
declare
  fruits text[] := array['딸기', '사고', '포도', '수박', '레몬', '망고', '복숭아', '바나나'];
  v_nickname text;
  v_from_meta text := new.raw_user_meta_data ->> 'nickname';
begin
  if v_from_meta is not null and trim(v_from_meta) <> '' then
    v_nickname := v_from_meta;
  else
    loop
      v_nickname := '앙대' || fruits[1 + floor(random() * array_length(fruits, 1))::int]
        || (1000 + floor(random() * 9000))::int;
      exit when not exists (
        select 1 from public.users
        where lower(trim(nickname)) = lower(trim(v_nickname))
      );
    end loop;
  end if;

  insert into public.users (
    id, email, nickname, role, provider, kakao_user_id, avatar_url, last_login_at
  )
  values (
    new.id,
    new.email,
    v_nickname,
    'user'::public.user_role,
    coalesce(
      new.raw_user_meta_data ->> 'auth_provider',
      new.raw_app_meta_data ->> 'provider',
      'email'
    ),
    new.raw_user_meta_data ->> 'kakao_user_id',
    new.raw_user_meta_data ->> 'avatar_url',
    now()
  )
  on conflict (id) do update set
    email = coalesce(excluded.email, users.email),
    provider = coalesce(excluded.provider, users.provider),
    kakao_user_id = coalesce(excluded.kakao_user_id, users.kakao_user_id),
    avatar_url = coalesce(excluded.avatar_url, users.avatar_url),
    last_login_at = now(),
    updated_at = now();
  return new;
end;
$$;

-- ═══════════════════════════════════════════════════════════════
-- 5. users insert — role=user 만 허용
-- ═══════════════════════════════════════════════════════════════

drop policy if exists "users_insert_own" on public.users;
create policy "users_insert_own" on public.users
  for insert to authenticated
  with check (auth.uid() = id and role = 'user'::public.user_role);

-- ═══════════════════════════════════════════════════════════════
-- 6. 필수 약관 서버 조회
-- ═══════════════════════════════════════════════════════════════

create or replace function public.has_required_legal_consents()
returns boolean
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_ok int;
begin
  if v_uid is null then
    return false;
  end if;

  select count(distinct latest.term_id) into v_ok
  from (
    select distinct on (c.term_id) c.term_id, c.agreed
    from public.user_legal_consents c
    where c.user_id = v_uid
      and c.term_id in ('age_over_14', 'privacy', 'terms', 'operation', 'reward')
    order by c.term_id, c.agreed_at desc
  ) latest
  where latest.agreed = true;

  return coalesce(v_ok, 0) = 5;
end;
$$;

revoke all on function public.has_required_legal_consents() from public;
grant execute on function public.has_required_legal_consents() to authenticated;

-- ═══════════════════════════════════════════════════════════════
-- 7. 레퍼럴 스탬프 FOR UPDATE
-- ═══════════════════════════════════════════════════════════════

create or replace function public.grant_referral_stamp(p_user_id uuid, p_count int default 3)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_total_stamps int;
  v_redeem       jsonb;
begin
  insert into public.user_rewards (user_id)
  values (p_user_id)
  on conflict (user_id) do nothing;

  select total_stamps into v_total_stamps
  from public.user_rewards
  where user_id = p_user_id
  for update;

  update public.user_rewards
  set total_stamps = total_stamps + p_count
  where user_id = p_user_id
  returning total_stamps into v_total_stamps;

  while v_total_stamps >= 20 loop
    v_redeem := public._perform_gifticon_redeem(p_user_id);
    if v_redeem->>'status' != 'ok' then
      exit;
    end if;
    v_total_stamps := (v_redeem->>'total_stamps')::int;
  end loop;

  return jsonb_build_object(
    'granted_count', p_count,
    'total_stamps',  v_total_stamps
  );
end;
$$;

revoke all on function public.grant_referral_stamp(uuid, int) from public;
revoke all on function public.grant_referral_stamp(uuid, int) from anon;
revoke all on function public.grant_referral_stamp(uuid, int) from authenticated;

-- ═══════════════════════════════════════════════════════════════
-- 8. peak_push_sent_log RLS / 재계산 RPC / news log admin
-- ═══════════════════════════════════════════════════════════════

alter table if exists public.peak_push_sent_log enable row level security;
revoke all on table public.peak_push_sent_log from public;
revoke all on table public.peak_push_sent_log from anon;
revoke all on table public.peak_push_sent_log from authenticated;

revoke all on function public.recalculate_all_crowd_status(boolean) from public;
revoke all on function public.recalculate_all_crowd_status(boolean) from anon;
revoke all on function public.recalculate_all_crowd_status(boolean) from authenticated;

create or replace function public.admin_log_news_push(
  p_title text,
  p_body text,
  p_sent_count int,
  p_failed_count int
)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  -- service_role(Edge)는 auth.uid()가 null. 로그인 호출자는 admin 만.
  if auth.uid() is not null and not public.is_admin() then
    raise exception '권한이 없어요.';
  end if;
  insert into public.news_push_sent_log (title, body, sent_count, failed_count, sent_by)
  values (p_title, p_body, p_sent_count, p_failed_count, auth.uid());
end;
$$;

revoke all on function public.admin_log_news_push(text, text, int, int) from public;
revoke all on function public.admin_log_news_push(text, text, int, int) from anon;
grant execute on function public.admin_log_news_push(text, text, int, int)
  to authenticated, service_role;

-- ═══════════════════════════════════════════════════════════════
-- 9. 커뮤니티 푸시 — 하드코딩 시크릿 제거, 설정 테이블 사용
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
  select community_url, push_secret
    into edge_url, edge_secret
  from public.push_edge_runtime_config
  where id = 1;

  if edge_url is null or edge_secret is null or edge_url = '' or edge_secret = '' then
    return new;
  end if;

  push_event := case when new.parent_comment_id is not null then 'reply' else 'comment' end;

  perform net.http_post(
    url := edge_url,
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'Authorization', 'Bearer ' || edge_secret
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

  select community_url, push_secret
    into edge_url, edge_secret
  from public.push_edge_runtime_config
  where id = 1;

  if edge_url is null or edge_secret is null or edge_url = '' or edge_secret = '' then
    return new;
  end if;

  perform net.http_post(
    url := edge_url,
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'Authorization', 'Bearer ' || edge_secret
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
  select community_url, push_secret
    into edge_url, edge_secret
  from public.push_edge_runtime_config
  where id = 1;

  if edge_url is null or edge_secret is null or edge_url = '' or edge_secret = '' then
    return new;
  end if;

  perform net.http_post(
    url := edge_url,
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'Authorization', 'Bearer ' || edge_secret
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

-- 리워드 푸시도 GUC 대신 설정 테이블
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
  if old.status = 'assigned' then
    return new;
  end if;
  if new.assigned_user_id is null then
    return new;
  end if;

  select reward_url, push_secret
    into edge_url, edge_secret
  from public.push_edge_runtime_config
  where id = 1;

  if edge_url is null or edge_secret is null or edge_url = '' or edge_secret = '' then
    return new;
  end if;

  perform net.http_post(
    url := edge_url,
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'Authorization', 'Bearer ' || edge_secret
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
    raise warning 'reward push webhook failed: %', sqlerrm;
    return new;
end;
$$;

select 'hotfix_prelaunch_audit_fixes.sql ok' as status;
