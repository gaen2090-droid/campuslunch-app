-- 내 글 작성 시 자동 구독(알림 켜짐) (Dashboard → SQL Editor → Run)
-- 게시글 상세화면의 "알림" 종 아이콘은 community_post_subscriptions 존재 여부로 on/off 표시됨.
-- 지금까지는 글을 써도 구독 레코드가 자동 생성되지 않아 "내 글인데 알림이 꺼진 상태"로 보였다.
-- community_posts INSERT 시 작성자 본인을 자동으로 구독시키는 트리거를 추가한다.
-- (유저가 원하면 기존처럼 종 아이콘을 눌러 직접 끌 수 있음 — 강제 유지 아님)

create or replace function public.community_auto_subscribe_own_post()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.community_post_subscriptions (post_id, user_id)
  values (new.id, new.user_id)
  on conflict (post_id, user_id) do nothing;
  return new;
end;
$$;

drop trigger if exists community_posts_auto_subscribe on public.community_posts;
create trigger community_posts_auto_subscribe
  after insert on public.community_posts
  for each row execute function public.community_auto_subscribe_own_post();

-- 기존에 이미 작성된 글도 소급 적용 — 작성자 본인을 구독자로 일괄 추가.
insert into public.community_post_subscriptions (post_id, user_id)
select p.id, p.user_id
from public.community_posts p
on conflict (post_id, user_id) do nothing;

-- 확인 (Success 나오면 OK)
select 'ok' as result;
