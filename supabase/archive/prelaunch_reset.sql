-- 런칭 전 DB 초기화: 계정(로그인)·매장 정보·설정은 유지, 그 외 활동 데이터 전부 삭제
-- Dashboard → SQL Editor에서 실행
--
-- ⚠️ 프로덕션에 대한 파괴적 작업이다. 무료 플랜은 PITR/자동백업을 지원하지
-- 않으므로, 이 파일을 실행하기 전에 반드시 prelaunch_reset_backup.sql을 먼저
-- 실행해 수동 스냅샷(backup_* 테이블)을 만들어둘 것. 문제가 생기면
-- prelaunch_reset_restore.sql로 되돌릴 수 있다.
--
-- 유지되는 것: auth.users/public.users(로그인 계정), restaurants(매장 정보·영업시간·메뉴는
--   restaurants.description JSON에 있어 안전), gifticons(재고 자체), 각종 설정/차단어 테이블,
--   user_legal_consents(재로그인 시 약관 재동의 방지)
-- 비워지는 것: 제보, 커뮤니티, 맛집컬렉션, 리워드/스탬프 진행상황, 신고, 알림/체류 로그 등
--   모든 "활동" 데이터
-- 리셋되는 것: crowd_status(전 매장 "제보필요" 상태로), user_rewards(스탬프 0),
--   gifticons 배정 취소(재고로 환원)
--
-- 아래는 트랜잭션으로 감싸져 있다. 맨 아래 결과(각 테이블 남은 행 수)를 먼저 눈으로
-- 확인한 뒤에 마지막 줄의 commit; 주석을 풀고 다시 실행할 것. 지금 이대로 실행하면
-- rollback으로 끝나 실제로는 아무 것도 지워지지 않는다(dry-run).

begin;

-- ── 1. 비우기: 활동·커뮤니티·맛집컬렉션 데이터 ──
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
  public.restaurant_hours,
  public.restaurant_menus,
  public.restaurant_verification_codes,
  public.suspension_popup_seen
restart identity cascade;

-- ── 2. 리셋: 삭제 대신 초기값으로 되돌림 ──

-- 스탬프 진행상황 초기화 (계정 자체는 유지)
update public.user_rewards
set today_stamps = 0,
    total_stamps = 0,
    last_stamp_date = null;

-- 배정된 기프티콘을 재고(unassigned)로 환원 — gifticons 행 자체는 삭제하지 않음
update public.gifticons
set assigned_user_id = null,
    assigned_at = null,
    status = 'unassigned'
where assigned_user_id is not null;

-- crowd_status는 delete 트리거가 insert에만 걸려 있어 직접 delete하면 정합성이 깨진다.
-- 다만 recalculate_crowd_status()의 "제보 없음" 분기는 새로 1로 초기화하지 않고
-- DB에 남아있는 기존 display_level을 그대로 유지하는 설계다(평소엔 올바른 동작 —
-- 제보가 잠깐 끊겨도 마지막 상태를 보여줌). 완전 초기화가 목적이므로 재계산 전에
-- 먼저 모든 매장을 기본값(제보필요=1)으로 직접 되돌린 뒤 재계산한다.
update public.crowd_status
set display_level = 1,
    level = 1,
    base_source = 'user',
    confidence = 'low',
    report_count = 0,
    status_started_at = now(),
    updated_at = now(),
    last_applied_report_at = null;

select public.recalculate_all_crowd_status(false);

-- ── 3. 확인용: 비워진 테이블의 남은 행 수(전부 0이어야 정상) ──
select 'analytics_events' as table_name, count(*) from public.analytics_events
union all select 'app_feedback', count(*) from public.app_feedback
union all select 'bookmarks', count(*) from public.bookmarks
union all select 'collection_comment_likes', count(*) from public.collection_comment_likes
union all select 'collection_comment_reports', count(*) from public.collection_comment_reports
union all select 'collection_comments', count(*) from public.collection_comments
union all select 'collection_items', count(*) from public.collection_items
union all select 'collection_likes', count(*) from public.collection_likes
union all select 'collection_reports', count(*) from public.collection_reports
union all select 'collections', count(*) from public.collections
union all select 'community_blocks', count(*) from public.community_blocks
union all select 'community_comment_likes', count(*) from public.community_comment_likes
union all select 'community_comments', count(*) from public.community_comments
union all select 'community_inbox_last_seen', count(*) from public.community_inbox_last_seen
union all select 'community_inbox_reads', count(*) from public.community_inbox_reads
union all select 'community_likes', count(*) from public.community_likes
union all select 'community_notices', count(*) from public.community_notices
union all select 'community_poll_options', count(*) from public.community_poll_options
union all select 'community_poll_votes', count(*) from public.community_poll_votes
union all select 'community_post_subscriptions', count(*) from public.community_post_subscriptions
union all select 'community_posts', count(*) from public.community_posts
union all select 'community_reports', count(*) from public.community_reports
union all select 'crowd_reports', count(*) from public.crowd_reports
union all select 'news_push_scheduled', count(*) from public.news_push_scheduled
union all select 'news_push_sent_log', count(*) from public.news_push_sent_log
union all select 'owner_applications', count(*) from public.owner_applications
union all select 'owner_seat_updates', count(*) from public.owner_seat_updates
union all select 'peak_push_sent_log', count(*) from public.peak_push_sent_log
union all select 'referrals', count(*) from public.referrals
union all select 'report_attempts', count(*) from public.report_attempts
union all select 'restaurant_hours', count(*) from public.restaurant_hours
union all select 'restaurant_menus', count(*) from public.restaurant_menus
union all select 'restaurant_verification_codes', count(*) from public.restaurant_verification_codes
union all select 'suspension_popup_seen', count(*) from public.suspension_popup_seen
-- 리셋 결과 확인용(0건이 아니라 값 확인)
union all select 'user_rewards_nonzero', count(*) from public.user_rewards where total_stamps <> 0 or today_stamps <> 0
union all select 'gifticons_still_assigned', count(*) from public.gifticons where assigned_user_id is not null
union all select 'crowd_status_not_reset', count(*) from public.crowd_status where display_level <> 1
-- 유지 확인용(0건이면 안 되는 것들 — 계정/매장이 그대로 남아있는지)
union all select 'users_kept', count(*) from public.users
union all select 'restaurants_kept', count(*) from public.restaurants
order by table_name;

-- 위 결과를 확인한 뒤, 문제없으면 아래 주석을 풀고 다시 이 파일 전체를 실행할 것.
-- commit;

-- 지금 이 상태로 실행을 마치면 위의 commit이 주석 처리돼 있으므로 트랜잭션이 자동으로
-- rollback되어 실제로는 아무것도 지워지지 않는다 (dry-run 확인용).
rollback;
