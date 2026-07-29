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
  delete from public.bookmarks where user_id = uid;
  delete from public.user_push_tokens where user_id = uid;
  delete from public.user_notification_prefs where user_id = uid;
  delete from public.notification_settings where user_id = uid;
  delete from public.user_devices where user_id = uid;
  delete from public.crowd_reports where user_id = uid;
  delete from public.analytics_events where user_id = uid;
  delete from public.app_feedback where user_id = uid;
  delete from public.owner_seat_updates where owner_id = uid;
  delete from public.user_rewards where user_id = uid;
  update public.gifticons set assigned_user_id = null, assigned_at = null where assigned_user_id = uid;
  update public.restaurants set owner_id = null where owner_id = uid;
  update public.restaurant_verification_codes set claimed_by = null where claimed_by = uid;

  -- 탈퇴 회원 익명화: 게시물/댓글은 남기고 표시 정보만 스크럽
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
end;
$$;

revoke all on function public.delete_own_account() from public;
grant execute on function public.delete_own_account() to authenticated;
