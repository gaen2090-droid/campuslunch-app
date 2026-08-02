-- 회원 탈퇴 (Dashboard → SQL Editor → Run)
-- 정책(PRIVACY_POLICY.md): 탈퇴 시 커뮤니티 게시물/댓글은 삭제하지 않고 유지하되,
-- 작성자 표시만 '탈퇴한 회원'으로 익명화한다.
--
-- 주의: public.users.id 는 auth.users(id) on delete cascade 이므로,
-- auth.users 를 삭제하면 public.users 행도 함께 삭제되어 게시물의 작성자 조인이 끊긴다
-- (community_posts.user_id → public.users on delete cascade).
-- 그래서 auth.users 는 삭제하지 않고, public.users 행을 남긴 채 개인정보만 스크럽하고
-- nickname/role 을 '탈퇴한 회원'/user 로 바꿔 기존 조회 RPC(u.nickname, u.role='owner' 조인)가
-- 별도 수정 없이 자동으로 익명화된 값을 반환하도록 한다.
--
-- 운영 통계 보존을 위해 아래 5개 테이블은 삭제 대신 user_id만 null로 비운다
-- (매장별 혼잡도 제보 수·즐겨찾기 수·쿠폰 지급 수·피드백 내용·매장별
-- 조회/클릭수(analytics_events)는 통계/운영 자산이라 탈퇴자 수만큼 계속
-- 깎여나가면 안 됨. 개인 식별자만 제거하면 개인정보보호법상 통계 목적의
-- 익명 정보로 계속 보관 가능):
--   crowd_reports.user_id  (원래 nullable)
--   bookmarks.user_id      (원래 not null → 이 파일에서 nullable로 변경)
--   gifticons.assigned_user_id (원래 nullable, assigned_at은 유지해 지급 이력 보존)
--   app_feedback.user_id   (원래 nullable)
--   analytics_events.user_id (원래 on delete set null — owner_restaurant_engagement_stats,
--     admin_dashboard_metrics가 restaurant_id별 count(*)/count(distinct user_id)로만 집계하므로
--     user_id를 null로 비워도 매장별 조회·클릭수 집계에 영향 없음)
-- 반면 아래는 탈퇴자 개인에게만 의미 있는 데이터라 지금처럼 삭제 유지:
--   user_push_tokens, user_notification_prefs, notification_settings,
--   user_devices, owner_seat_updates(1시간 지나면 조회 자체가
--   안 되는 실시간 정보), user_rewards(1:1 개인 잔액이라 익명화해도 무의미)

-- bookmarks.user_id를 nullable로 바꾸고, 유저 삭제 시 즐겨찾기 row 자체가
-- cascade로 사라지지 않도록 on delete set null로 변경한다.
alter table public.bookmarks alter column user_id drop not null;
alter table public.bookmarks drop constraint if exists bookmarks_user_id_fkey;
alter table public.bookmarks
  add constraint bookmarks_user_id_fkey
  foreign key (user_id) references public.users(id) on delete set null;

create or replace function public.delete_own_account()
returns void
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  uid uuid := auth.uid();
begin
  if uid is null then
    raise exception 'NOT_AUTHENTICATED';
  end if;

  -- 게시물/댓글/좋아요·신고 이력은 커뮤니티 맥락 보존을 위해 삭제하지 않는다.
  -- 매장별 통계에 쓰이는 5개 테이블은 삭제 대신 user_id만 익명화한다.
  update public.crowd_reports set user_id = null where user_id = uid;
  update public.bookmarks set user_id = null where user_id = uid;
  update public.gifticons set assigned_user_id = null where assigned_user_id = uid;
  update public.app_feedback set user_id = null where user_id = uid;
  update public.analytics_events set user_id = null where user_id = uid;

  delete from public.user_push_tokens where user_id = uid;
  delete from public.user_notification_prefs where user_id = uid;
  delete from public.notification_settings where user_id = uid;
  delete from public.user_devices where user_id = uid;
  delete from public.owner_seat_updates where owner_id = uid;
  delete from public.user_rewards where user_id = uid;
  update public.restaurants set owner_id = null where owner_id = uid;
  update public.restaurant_verification_codes set claimed_by = null where claimed_by = uid;

  -- 탈퇴 회원 익명화: 게시물/댓글은 남기고 표시 정보만 스크럽
  -- (nickname_change_lock_30d.sql의 30일 제한 트리거를 이 UPDATE에 한해 우회)
  perform set_config('app.bypass_nickname_lock', '1', true);
  update public.users
  set nickname = '탈퇴한 회원',
      email = null,
      kakao_user_id = null,
      avatar_url = null,
      role = 'user'::public.user_role,
      active_owner_restaurant_id = null
  where id = uid;

  -- auth.users 는 삭제하지 않는다 (cascade로 public.users 까지 사라짐).
  -- 대신 재로그인/재가입 어뷰징(탈퇴 후 즉시 재가입 반복)을 막기 위해
  -- 30일간 계정을 비활성화한다. 30일 후에는 같은 이메일/카카오·구글 계정으로
  -- 재가입할 수 있다 — 그때는 새로 만들어질 public.users 행이 별개이므로
  -- 기존에 남아있는 게시물(작성자 표시는 이미 '탈퇴한 회원'으로 익명화됨)과는 무관하다.
  update auth.users set banned_until = now() + interval '30 days' where id = uid;

  -- 다른 기기에 로그인된 세션도 즉시 무효화한다. 안 지우면 그 기기는 만료
  -- 전까지(기본 ~1시간) 탈퇴한 계정으로 계속 요청을 보낼 수 있고, 서버가
  -- 이를 거부해도 클라이언트가 "성공"으로 오인해 로컬에만 반영되는 유령
  -- 상태(제보 등)를 만들 수 있다. refresh_tokens를 먼저 지워야
  -- sessions 삭제 후 재발급을 막을 수 있다.
  delete from auth.refresh_tokens where user_id = uid::text;
  delete from auth.sessions where user_id = uid;
end;
$$;

revoke all on function public.delete_own_account() from public;
grant execute on function public.delete_own_account() to authenticated;
