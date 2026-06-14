-- admin_dashboard_metrics 보안 강화 (웹 Admin 공개 배포 전)
-- Dashboard → SQL Editor
--
-- 1) supabase/push_analytics.sql 의 admin_dashboard_metrics() 본문
--    declare 섹션 직후에 아래 2줄 추가:
--
--      if auth.uid() is null then
--        raise exception 'login required';
--      end if;
--      if not public.is_admin() then
--        raise exception 'admin only';
--      end if;
--
-- 2) 파일 하단 grant 수정:

revoke all on function public.admin_dashboard_metrics() from public;
revoke all on function public.admin_dashboard_metrics() from anon;
grant execute on function public.admin_dashboard_metrics() to authenticated;

-- 앱 admin/admin123 로컬 관리자는 RPC 대신 클라이언트 fallback을 사용하므로
-- anon 제거해도 앱 지표 탭은 crowd_reports fallback으로 동작합니다.
