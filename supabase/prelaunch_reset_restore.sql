-- prelaunch_reset.sql 실행 후 문제가 생겼을 때 복구용
-- prelaunch_reset_backup.sql로 만들어둔 backup_* 테이블에서 원본으로 되돌린다.
--
-- ⚠️ 원본 테이블에 이미 새로 쌓인 데이터(리셋 이후 들어온 새 제보 등)가 있다면
-- 이 스크립트가 그것까지 지우고 백업 시점으로 통째로 되돌린다. 되돌리기 전에
-- 정말 필요한 상황인지, 새 데이터를 잃어도 되는지 먼저 확인할 것.

begin;

truncate table
  public.analytics_events,
  public.app_feedback,
  public.bookmarks,
  public.collection_comment_likes,
  public.collection_comment_reports,
  public.collection_comments,
  public.collection_items,
  public.collection_likes,
  public.collection_reports,
  public.collections,
  public.community_blocks,
  public.community_comment_likes,
  public.community_comments,
  public.community_inbox_last_seen,
  public.community_inbox_reads,
  public.community_likes,
  public.community_notices,
  public.community_poll_options,
  public.community_poll_votes,
  public.community_post_subscriptions,
  public.community_posts,
  public.community_reports,
  public.crowd_reports,
  public.news_push_scheduled,
  public.news_push_sent_log,
  public.owner_applications,
  public.owner_seat_updates,
  public.peak_push_sent_log,
  public.referrals,
  public.report_attempts,
  public.suspension_popup_seen
restart identity cascade;

insert into public.analytics_events select * from public.backup_analytics_events;
insert into public.app_feedback select * from public.backup_app_feedback;
insert into public.bookmarks select * from public.backup_bookmarks;
insert into public.collections select * from public.backup_collections;
insert into public.collection_items select * from public.backup_collection_items;
insert into public.collection_comments select * from public.backup_collection_comments;
insert into public.collection_comment_likes select * from public.backup_collection_comment_likes;
insert into public.collection_comment_reports select * from public.backup_collection_comment_reports;
insert into public.collection_likes select * from public.backup_collection_likes;
insert into public.collection_reports select * from public.backup_collection_reports;
insert into public.community_posts select * from public.backup_community_posts;
insert into public.community_comments select * from public.backup_community_comments;
insert into public.community_comment_likes select * from public.backup_community_comment_likes;
insert into public.community_likes select * from public.backup_community_likes;
insert into public.community_reports select * from public.backup_community_reports;
insert into public.community_blocks select * from public.backup_community_blocks;
insert into public.community_inbox_last_seen select * from public.backup_community_inbox_last_seen;
insert into public.community_inbox_reads select * from public.backup_community_inbox_reads;
insert into public.community_notices select * from public.backup_community_notices;
insert into public.community_poll_options select * from public.backup_community_poll_options;
insert into public.community_poll_votes select * from public.backup_community_poll_votes;
insert into public.community_post_subscriptions select * from public.backup_community_post_subscriptions;
insert into public.crowd_reports select * from public.backup_crowd_reports;
insert into public.news_push_scheduled select * from public.backup_news_push_scheduled;
insert into public.news_push_sent_log select * from public.backup_news_push_sent_log;
insert into public.owner_applications select * from public.backup_owner_applications;
insert into public.owner_seat_updates select * from public.backup_owner_seat_updates;
insert into public.peak_push_sent_log select * from public.backup_peak_push_sent_log;
insert into public.referrals select * from public.backup_referrals;
insert into public.report_attempts select * from public.backup_report_attempts;
insert into public.suspension_popup_seen select * from public.backup_suspension_popup_seen;

-- 리셋했던 것도 백업 시점 값으로 복원
delete from public.user_rewards;
insert into public.user_rewards select * from public.backup_user_rewards;

update public.gifticons g
set assigned_user_id = b.assigned_user_id,
    assigned_at = b.assigned_at,
    status = b.status
from public.backup_gifticons b
where g.id = b.id;

update public.crowd_status cs
set display_level = b.display_level,
    level = b.level,
    base_source = b.base_source,
    confidence = b.confidence,
    report_count = b.report_count,
    status_started_at = b.status_started_at,
    updated_at = b.updated_at,
    last_applied_report_at = b.last_applied_report_at
from public.backup_crowd_status b
where cs.restaurant_id = b.restaurant_id;

-- 확인 후 문제없으면 commit, 이상하면 rollback
-- commit;
rollback;
