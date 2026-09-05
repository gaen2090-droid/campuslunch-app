-- 통계·지표 수집에서 완전히 제외되는 내부 테스트/제보용 계정 지원
-- Dashboard → SQL Editor → Run
--
-- campuslunch2026@gmail.com 같은 "관리자 제보 전용" 계정은:
--   - crowd_reports(제보)는 정상적으로 남고 앱 화면(혼잡도)에는 실시간 반영되어야 함
--   - 다만 admin 대시보드/사장님 통계 등 "집계"되는 모든 지표에서는 완전히 빠져야 함
--   - analytics_events(지도 마커 클릭·검색결과 클릭·상세조회·배너·앱세션 등)는
--     이 계정 행동이면 애초에 기록(insert) 자체를 하지 않음
--
-- is_admin()과는 별개 플래그다. 관리자 권한과 통계 제외는 서로 다른 개념이므로
-- role='admin'에 얹지 않고 전용 컬럼을 둔다 (향후 다른 계정을 추가/해제하기 쉽도록).

alter table public.users
  add column if not exists excluded_from_stats boolean not null default false;

create or replace function public.is_stats_excluded(p_user_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select coalesce(
    (select u.excluded_from_stats from public.users u where u.id = p_user_id),
    false
  );
$$;

revoke all on function public.is_stats_excluded(uuid) from public;
grant execute on function public.is_stats_excluded(uuid) to authenticated;

-- 최초 대상 계정 지정 (필요 시 추가/해제는 이 UPDATE만 다시 실행)
update public.users
set excluded_from_stats = true
where id = (select id from auth.users where lower(email) = 'campuslunch2026@gmail.com');

-- admin-web이 RPC 대신 crowd_reports를 직접 select하는 지표 화면(매장 목록의
-- 오늘/주간 제보수 등)이 있어, 뷰로 통계 제외 계정의 행을 미리 걸러 제공한다.
-- crowd_reports 원본 테이블 자체는 건드리지 않으므로 앱의 실시간 혼잡도 반영과는 무관하다.
create or replace view public.crowd_reports_for_stats
with (security_invoker = true) as
select cr.*
from public.crowd_reports cr
where not public.is_stats_excluded(cr.user_id);

grant select on public.crowd_reports_for_stats to authenticated;

select 'stats_excluded_users.sql ok' as status;
