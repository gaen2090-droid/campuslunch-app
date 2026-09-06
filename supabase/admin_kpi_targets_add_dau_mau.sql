-- kpi_targets.metric_key 에 dau/mau 목표 지표 추가
-- admin_kpi_targets.sql 실행 후 Dashboard → SQL Editor → Run

alter table public.kpi_targets
  drop constraint if exists kpi_targets_metric_key_check;

alter table public.kpi_targets
  add constraint kpi_targets_metric_key_check
  check (metric_key in ('new_users', 'new_owners', 'reports', 'posts', 'dau', 'mau'));
