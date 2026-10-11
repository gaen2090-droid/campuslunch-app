-- 사용자 앱 버전 / OS 현황
-- (Dashboard → SQL Editor → Run) — 앱 새 버전 배포 전에 먼저 실행할 것.
--
-- 앱이 진입할 때 record_app_version() 으로 자기 버전/플랫폼을 보고하고,
-- 어드민은 admin_app_version_stats() 로 (플랫폼, 버전)별 가입자 수를 본다.
-- 이 기능이 들어간 빌드를 쓰는 사용자만 값이 채워지고, 그 외는 "미확인"으로 집계된다.

alter table public.users
  add column if not exists app_version text,
  add column if not exists app_build int,
  add column if not exists app_platform text,
  add column if not exists app_version_reported_at timestamptz;

alter table public.users
  drop constraint if exists users_app_platform_check;
alter table public.users
  add constraint users_app_platform_check
  check (app_platform is null or app_platform in ('ios', 'android'));

-- ── 앱 → 서버: 내 버전 보고 ─────────────────────────────────────
create or replace function public.record_app_version(
  p_version text,
  p_build int,
  p_platform text
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  uid uuid := auth.uid();
  v text := nullif(btrim(p_version), '');
  pf text := lower(btrim(coalesce(p_platform, '')));
begin
  if uid is null or v is null or char_length(v) > 32 then
    return;
  end if;
  if pf not in ('ios', 'android') then
    return;
  end if;

  -- 값이 바뀐 경우에만 쓴다 (앱을 열 때마다 불필요한 UPDATE 방지)
  update public.users
  set app_version = v,
      app_build = p_build,
      app_platform = pf,
      app_version_reported_at = now()
  where id = uid
    and (app_version, app_build, app_platform)
        is distinct from (v, p_build, pf);
end;
$$;

revoke all on function public.record_app_version(text, int, text) from public;
grant execute on function public.record_app_version(text, int, text) to authenticated;

-- ── 어드민: 플랫폼·버전별 가입자 수 ──────────────────────────────
-- 가입자 전체 기준. 통계 제외 계정(excluded_from_stats)은 다른 지표와 동일하게 뺀다.
create or replace function public.admin_app_version_stats()
returns table (
  platform text,        -- 'ios' | 'android' | 'unknown'
  app_version text,     -- 미확인이면 null
  user_count bigint
)
language plpgsql
stable
security definer
set search_path = public
as $$
begin
  if not public.is_admin() then
    raise exception 'admin only';
  end if;

  return query
  select
    coalesce(u.app_platform, 'unknown') as platform,
    u.app_version,
    count(*)::bigint as user_count
  from public.users u
  where coalesce(u.excluded_from_stats, false) = false
  group by coalesce(u.app_platform, 'unknown'), u.app_version
  order by user_count desc, platform, app_version;
end;
$$;

revoke all on function public.admin_app_version_stats() from public;
grant execute on function public.admin_app_version_stats() to authenticated;
