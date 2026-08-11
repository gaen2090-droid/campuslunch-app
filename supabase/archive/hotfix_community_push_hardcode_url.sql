-- 예전 하드코딩 시크릿 버전은 폐기.
-- 적용: supabase/hotfix_prelaunch_audit_fixes.sql
-- 푸시 URL/시크릿은 public.push_edge_runtime_config 에만 둔다.

select 'deprecated: use hotfix_prelaunch_audit_fixes.sql' as status;
