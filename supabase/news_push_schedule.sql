-- 캠퍼스런치 소식 알림 — 일회성 예약 발송
-- news_push.sql 이후 실행. (Dashboard → SQL Editor → Run)
--
-- 어드민 웹에서 제목/본문/발송 시각을 등록해두면 pg_cron이 매분 폴링하며
-- 시각이 된 pending 예약을 send-news-push Edge Function으로 발송한다.
-- 예약은 1회성(반복 없음) — 발송 후 status가 sent로 바뀌고 다시 돌지 않는다.

-- ═══════════════════════════════════════════════════════════════
-- 1. 예약 테이블
-- ═══════════════════════════════════════════════════════════════

create table if not exists public.news_push_scheduled (
  id uuid primary key default gen_random_uuid(),
  title text not null,
  body text not null,
  scheduled_at timestamptz not null,
  status text not null default 'pending' check (status in ('pending', 'sent', 'cancelled', 'failed')),
  sent_at timestamptz,
  created_by uuid references public.users(id) on delete set null,
  created_at timestamptz not null default now()
);

create index if not exists news_push_scheduled_pending_idx
  on public.news_push_scheduled (scheduled_at)
  where status = 'pending';

alter table public.news_push_scheduled enable row level security;

drop policy if exists "news_push_scheduled_admin_all" on public.news_push_scheduled;
create policy "news_push_scheduled_admin_all" on public.news_push_scheduled
  for all to authenticated
  using (public.is_admin())
  with check (public.is_admin());

-- ═══════════════════════════════════════════════════════════════
-- 2. 어드민 RPC — 등록/목록/취소
-- ═══════════════════════════════════════════════════════════════

create or replace function public.admin_create_scheduled_news_push(
  p_title text,
  p_body text,
  p_scheduled_at timestamptz
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
begin
  if not public.is_admin() then
    raise exception '관리자만 소식 알림을 예약할 수 있어요.';
  end if;

  v_title := trim(coalesce(p_title, ''));
  v_body := trim(coalesce(p_body, ''));
  if v_title = '' then
    raise exception '제목을 입력해주세요.';
  end if;
  if v_body = '' then
    raise exception '본문을 입력해주세요.';
  end if;
  if p_scheduled_at is null or p_scheduled_at <= now() then
    raise exception '발송 시각은 현재보다 이후여야 해요.';
  end if;

  insert into public.news_push_scheduled (title, body, scheduled_at, created_by)
  values (v_title, v_body, p_scheduled_at, auth.uid())
  returning to_jsonb(news_push_scheduled.*) into result;

  return result;
end;
$$;

revoke all on function public.admin_create_scheduled_news_push(text, text, timestamptz) from public;
grant execute on function public.admin_create_scheduled_news_push(text, text, timestamptz) to authenticated;

create or replace function public.admin_list_scheduled_news_push()
returns setof public.news_push_scheduled
language sql
stable
security definer
set search_path = public
as $$
  select *
  from public.news_push_scheduled
  where public.is_admin()
  order by scheduled_at desc
  limit 50;
$$;

revoke all on function public.admin_list_scheduled_news_push() from public;
grant execute on function public.admin_list_scheduled_news_push() to authenticated;

create or replace function public.admin_cancel_scheduled_news_push(p_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  result jsonb;
begin
  if not public.is_admin() then
    raise exception '관리자만 예약을 취소할 수 있어요.';
  end if;

  update public.news_push_scheduled
  set status = 'cancelled'
  where id = p_id
    and status = 'pending'
  returning to_jsonb(news_push_scheduled.*) into result;

  if result is null then
    raise exception '대기 중인 예약만 취소할 수 있어요.';
  end if;

  return result;
end;
$$;

revoke all on function public.admin_cancel_scheduled_news_push(uuid) from public;
grant execute on function public.admin_cancel_scheduled_news_push(uuid) to authenticated;

-- ═══════════════════════════════════════════════════════════════
-- 3. 디스패처 — pg_cron이 매분 호출. 시각 지난 pending 건을 발송.
--    URL/secret은 push_edge_runtime_config(공식 배선 테이블, news_url 포함)에서
--    읽는다 — 시크릿을 SQL 파일에 박아넣지 않는 프로젝트 규칙(fcm_push_wiring.sql)을 따름.
-- ═══════════════════════════════════════════════════════════════

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
    -- 동시 실행(겹치는 cron 틱) 대비 클레임: pending 상태에서 원자적으로 빠져나가게
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
          'body', r.body
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

revoke all on function public.dispatch_scheduled_news_push() from public;
grant execute on function public.dispatch_scheduled_news_push() to service_role;

-- ═══════════════════════════════════════════════════════════════
-- 4. cron 등록 — 매분 폴링 (기존 campuslunch-peak-push와 동일 주기)
-- ═══════════════════════════════════════════════════════════════

select cron.unschedule('campuslunch-news-push-dispatch')
where exists (select 1 from cron.job where jobname = 'campuslunch-news-push-dispatch');

select cron.schedule(
  'campuslunch-news-push-dispatch',
  '* * * * *',
  $$select public.dispatch_scheduled_news_push();$$
);

select 'news_push_schedule.sql ok' as status;
