-- 캠퍼스런치 소식 알림에 발송 대상(전체 / 사장님만) 추가
-- Dashboard → SQL Editor → Run (push_exclude_owners.sql 이후)

-- ── 1. 예약 테이블에 target 컬럼 추가 ──
alter table public.news_push_scheduled
  add column if not exists target text not null default 'all'
  check (target in ('all', 'owners_only'));

-- ── 2. list_news_push_tokens: 대상 인자 추가 (owners_only는 사장님 제외 설정 무시) ──
drop function if exists public.list_news_push_tokens();

create or replace function public.list_news_push_tokens(p_target text default 'all')
returns table (token text)
language sql
stable
security definer
set search_path = public
as $$
  select t.token
  from public.user_push_tokens t
  left join public.user_notification_prefs p on p.user_id = t.user_id
  where coalesce(p.news, true)
    and (
      p_target = 'owners_only' and public.is_any_restaurant_owner(t.user_id)
      or p_target <> 'owners_only'
        and not (
          coalesce((select c.news_exclude_owners from public.push_notification_config c where c.id = 1), false)
          and public.is_any_restaurant_owner(t.user_id)
        )
    );
$$;

revoke all on function public.list_news_push_tokens(text) from public;
grant execute on function public.list_news_push_tokens(text) to service_role;

-- ── 3. 즉시 발송용: 대상별 도달 인원 수 (어드민 웹 미리보기용) ──
create or replace function public.admin_news_push_reach(p_target text default 'all')
returns jsonb
language plpgsql
stable security definer
set search_path = public
as $$
declare
  result jsonb;
begin
  if not public.is_admin() then
    raise exception '관리자만 조회할 수 있어요.';
  end if;

  select jsonb_build_object(
    'users', (
      select count(distinct t.user_id)::int
      from public.user_push_tokens t
      left join public.user_notification_prefs p on p.user_id = t.user_id
      where coalesce(p.news, true)
        and (
          p_target = 'owners_only' and public.is_any_restaurant_owner(t.user_id)
          or p_target <> 'owners_only'
            and not (
              coalesce((select c.news_exclude_owners from public.push_notification_config c where c.id = 1), false)
              and public.is_any_restaurant_owner(t.user_id)
            )
        )
    ),
    'devices', (
      select count(*)::int
      from public.user_push_tokens t
      left join public.user_notification_prefs p on p.user_id = t.user_id
      where coalesce(p.news, true)
        and (
          p_target = 'owners_only' and public.is_any_restaurant_owner(t.user_id)
          or p_target <> 'owners_only'
            and not (
              coalesce((select c.news_exclude_owners from public.push_notification_config c where c.id = 1), false)
              and public.is_any_restaurant_owner(t.user_id)
            )
        )
    )
  ) into result;

  return result;
end;
$$;

revoke all on function public.admin_news_push_reach(text) from public;
grant execute on function public.admin_news_push_reach(text) to authenticated;

-- ── 4. admin_create_scheduled_news_push: target 인자 추가 ──
drop function if exists public.admin_create_scheduled_news_push(text, text, timestamptz);

create or replace function public.admin_create_scheduled_news_push(
  p_title text,
  p_body text,
  p_scheduled_at timestamptz,
  p_target text default 'all'
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  result jsonb;
  v_title text;
  v_body text;
  v_target text;
begin
  if not public.is_admin() then
    raise exception '관리자만 소식 알림을 예약할 수 있어요.';
  end if;

  v_title := trim(coalesce(p_title, ''));
  v_body := trim(coalesce(p_body, ''));
  v_target := coalesce(nullif(trim(p_target), ''), 'all');
  if v_target not in ('all', 'owners_only') then
    raise exception '알 수 없는 발송 대상이에요: %', v_target;
  end if;
  if v_title = '' then
    raise exception '제목을 입력해주세요.';
  end if;
  if v_body = '' then
    raise exception '본문을 입력해주세요.';
  end if;
  if p_scheduled_at is null or p_scheduled_at <= now() then
    raise exception '발송 시각은 현재보다 이후여야 해요.';
  end if;

  insert into public.news_push_scheduled (title, body, scheduled_at, created_by, target)
  values (v_title, v_body, p_scheduled_at, auth.uid(), v_target)
  returning to_jsonb(news_push_scheduled.*) into result;

  return result;
end;
$$;

revoke all on function public.admin_create_scheduled_news_push(text, text, timestamptz, text) from public;
grant execute on function public.admin_create_scheduled_news_push(text, text, timestamptz, text) to authenticated;

-- ── 5. dispatch_scheduled_news_push: 발송 시 target을 웹훅 body에 함께 전달 ──
create or replace function public.dispatch_scheduled_news_push()
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  edge_url text;
  edge_secret text;
  r record;
  claimed int;
begin
  select news_url, push_secret into edge_url, edge_secret
  from public.push_edge_runtime_config
  where id = 1;

  if edge_url is null or edge_secret is null then
    raise warning 'dispatch_scheduled_news_push: push_edge_runtime_config.news_url/push_secret not set';
    return;
  end if;

  for r in
    select * from public.news_push_scheduled
    where status = 'pending'
      and scheduled_at <= now()
    order by scheduled_at
  loop
    update public.news_push_scheduled
    set status = 'sent', sent_at = now()
    where id = r.id
      and status = 'pending';
    get diagnostics claimed = row_count;
    if claimed = 0 then
      continue;
    end if;

    begin
      perform net.http_post(
        url := edge_url,
        headers := jsonb_build_object(
          'Content-Type', 'application/json',
          'Authorization', 'Bearer ' || edge_secret
        ),
        body := jsonb_build_object(
          'title', r.title,
          'body', r.body,
          'target', r.target
        )
      );
    exception
      when others then
        update public.news_push_scheduled
        set status = 'failed'
        where id = r.id;
        raise warning 'scheduled news push webhook failed (id=%): %', r.id, sqlerrm;
    end;
  end loop;
end;
$$;

select 'news_push_owner_target.sql ok' as status;
