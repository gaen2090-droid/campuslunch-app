-- prelaunch_reset.sql 실행 전 수동 스냅샷 (무료 플랜은 PITR/자동백업 미지원)
-- Dashboard → SQL Editor에서 이 파일을 먼저 통째로 실행하고, 정상 완료된 걸
-- 확인한 뒤에 prelaunch_reset.sql을 실행할 것.
--
-- prelaunch_reset.sql이 지우는 34개 테이블을 backup_<원본이름> 이름으로 그대로 복제한다.
-- 문제가 생기면 이 백업 테이블에서 원본으로 다시 insert해 복구할 수 있다.
--
-- ⚠️ 이 스크립트는 트랜잭션으로 감싸지 않는다 — 각 create table이 끝나는 대로
-- 바로 커밋되어야 프렐런치 리셋 트랜잭션이 rollback되어도 백업이 남아있다.

create table if not exists public.backup_analytics_events as table public.analytics_events;
create table if not exists public.backup_app_feedback as table public.app_feedback;
create table if not exists public.backup_bookmarks as table public.bookmarks;
create table if not exists public.backup_collection_comment_likes as table public.collection_comment_likes;
create table if not exists public.backup_collection_comment_reports as table public.collection_comment_reports;
create table if not exists public.backup_collection_comments as table public.collection_comments;
create table if not exists public.backup_collection_items as table public.collection_items;
create table if not exists public.backup_collection_likes as table public.collection_likes;
create table if not exists public.backup_collection_reports as table public.collection_reports;
create table if not exists public.backup_collections as table public.collections;
create table if not exists public.backup_community_blocks as table public.community_blocks;
create table if not exists public.backup_community_comment_likes as table public.community_comment_likes;
create table if not exists public.backup_community_comments as table public.community_comments;
create table if not exists public.backup_community_inbox_last_seen as table public.community_inbox_last_seen;
create table if not exists public.backup_community_inbox_reads as table public.community_inbox_reads;
create table if not exists public.backup_community_likes as table public.community_likes;
create table if not exists public.backup_community_notices as table public.community_notices;
create table if not exists public.backup_community_poll_options as table public.community_poll_options;
create table if not exists public.backup_community_poll_votes as table public.community_poll_votes;
create table if not exists public.backup_community_post_subscriptions as table public.community_post_subscriptions;
create table if not exists public.backup_community_posts as table public.community_posts;
create table if not exists public.backup_community_reports as table public.community_reports;
create table if not exists public.backup_crowd_reports as table public.crowd_reports;
create table if not exists public.backup_news_push_scheduled as table public.news_push_scheduled;
create table if not exists public.backup_news_push_sent_log as table public.news_push_sent_log;
create table if not exists public.backup_owner_applications as table public.owner_applications;
create table if not exists public.backup_owner_seat_updates as table public.owner_seat_updates;
create table if not exists public.backup_peak_push_sent_log as table public.peak_push_sent_log;
create table if not exists public.backup_referrals as table public.referrals;
create table if not exists public.backup_report_attempts as table public.report_attempts;
create table if not exists public.backup_suspension_popup_seen as table public.suspension_popup_seen;

-- 리셋(delete 아님) 대상도 되돌릴 수 있도록 현재 상태를 함께 스냅샷
create table if not exists public.backup_user_rewards as table public.user_rewards;
create table if not exists public.backup_gifticons as table public.gifticons;
create table if not exists public.backup_crowd_status as table public.crowd_status;

-- 확인: 백업 테이블 개수와 각 건수가 원본과 일치하는지
select
  'analytics_events' as table_name,
  (select count(*) from public.analytics_events) as original_count,
  (select count(*) from public.backup_analytics_events) as backup_count
union all
select 'crowd_reports',
  (select count(*) from public.crowd_reports),
  (select count(*) from public.backup_crowd_reports)
union all
select 'user_rewards',
  (select count(*) from public.user_rewards),
  (select count(*) from public.backup_user_rewards)
union all
select 'gifticons',
  (select count(*) from public.gifticons),
  (select count(*) from public.backup_gifticons)
union all
select 'crowd_status',
  (select count(*) from public.crowd_status),
  (select count(*) from public.backup_crowd_status);

select 'prelaunch_reset_backup.sql ok — 위 original_count와 backup_count가 각 행마다 같은지 확인할 것' as status;
