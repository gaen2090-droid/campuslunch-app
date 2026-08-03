-- 답글 알림 구현(reply_push_notifications.sql) 이후 댓글/답글/좋아요 앱푸시가 전혀 안 오던 문제 수정.
--
-- 원인: 커뮤니티 관련 트리거 함수들이 current_setting('app.settings.edge_community_push_url', ...)로
-- DB 커스텀 설정값을 읽는데, 이 값이 DB에 세팅되어 있지 않아(null) 트리거가 조용히 아무 것도 안 하고
-- 끝났음(예외가 아니라 정상 흐름이라 경고 로그도 안 남음). 이 값을 세팅하려면 ALTER DATABASE 권한이
-- 필요한데 SQL Editor 롤에는 그 권한이 없어(42501) 대시보드에서 세팅 불가.
--
-- 해결: peak-push cron job과 동일하게 URL/secret을 함수 안에 직접 하드코딩. current_setting 의존 제거.
-- (Dashboard → SQL Editor → Run)

-- ═══════════════════════════════════════════════════════════════
-- 1. 자유게시판 댓글/답글 트리거 함수
-- ═══════════════════════════════════════════════════════════════

create or replace function public.notify_community_comment_push()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  edge_url text := 'https://vkacsvoknnlmcyplprft.supabase.co/functions/v1/send-community-push';
  edge_secret text := 'e78e478d5d08fcc689017fc6c2647c01a7f62975db6fce9ea5f7796f2f1a40b6';
  push_event text;
begin
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

-- ═══════════════════════════════════════════════════════════════
-- 2. 맛집 컬렉션 답글 트리거 함수
-- ═══════════════════════════════════════════════════════════════

create or replace function public.notify_collection_reply_push()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  edge_url text := 'https://vkacsvoknnlmcyplprft.supabase.co/functions/v1/send-community-push';
  edge_secret text := 'e78e478d5d08fcc689017fc6c2647c01a7f62975db6fce9ea5f7796f2f1a40b6';
begin
  if new.parent_comment_id is null then
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

-- ═══════════════════════════════════════════════════════════════
-- 3. 좋아요 트리거 함수
-- ═══════════════════════════════════════════════════════════════

create or replace function public.notify_community_like_push()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  edge_url text := 'https://vkacsvoknnlmcyplprft.supabase.co/functions/v1/send-community-push';
  edge_secret text := 'e78e478d5d08fcc689017fc6c2647c01a7f62975db6fce9ea5f7796f2f1a40b6';
begin
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

select 'hotfix_community_push_hardcode_url.sql ok' as status;
