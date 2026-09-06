-- kpi_targets.metric_key 를 캠퍼스런치 서비스에 맞는 6개 지표로 교체
-- (신규가입자/점심DAU/WAU/제보/일평균참여자/커버리지)
-- 기존 new_owners/posts/dau/mau 키의 테스트 데이터는 새 체계와 호환되지 않아 삭제한다.
-- admin_kpi_targets.sql 실행 후 Dashboard → SQL Editor → Run

delete from public.kpi_targets
where metric_key in ('new_owners', 'posts', 'dau', 'mau');

alter table public.kpi_targets
  drop constraint if exists kpi_targets_metric_key_check;

alter table public.kpi_targets
  add constraint kpi_targets_metric_key_check
  check (metric_key in ('new_users', 'lunch_dau', 'wau', 'reports', 'report_participants', 'coverage'));
