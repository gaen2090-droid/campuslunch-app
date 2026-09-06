-- KPI 목표 설정: 관리자가 지표별 월간 목표 숫자를 입력/저장하고,
-- KPI 탭에서 실적 대비 달성률을 확인할 수 있게 한다.
-- policies.sql(is_admin) 실행 후 Dashboard → SQL Editor → Run

create table if not exists public.kpi_targets (
  id            uuid primary key default gen_random_uuid(),
  metric_key    text not null check (metric_key in ('new_users', 'new_owners', 'reports', 'posts')),
  period_month  date not null,
  target_value  integer not null check (target_value >= 0),
  updated_by    uuid references auth.users(id) on delete set null,
  updated_at    timestamptz not null default now(),
  unique (metric_key, period_month)
);

alter table public.kpi_targets enable row level security;

drop policy if exists "kpi_targets_admin_all" on public.kpi_targets;
create policy "kpi_targets_admin_all" on public.kpi_targets
  for all
  to authenticated
  using (public.is_admin())
  with check (public.is_admin());

create or replace function public.admin_upsert_kpi_target(
  p_metric_key text,
  p_period_month date,
  p_target_value integer
)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.uid() is null then
    raise exception 'login required';
  end if;
  if not public.is_admin() then
    raise exception 'admin only';
  end if;

  insert into public.kpi_targets (metric_key, period_month, target_value, updated_by)
  values (p_metric_key, date_trunc('month', p_period_month)::date, p_target_value, auth.uid())
  on conflict (metric_key, period_month)
  do update set
    target_value = excluded.target_value,
    updated_by = excluded.updated_by,
    updated_at = now();
end;
$$;

revoke all on function public.admin_upsert_kpi_target(text, date, integer) from public;
revoke all on function public.admin_upsert_kpi_target(text, date, integer) from anon;
grant execute on function public.admin_upsert_kpi_target(text, date, integer) to authenticated;

create or replace function public.admin_list_kpi_targets()
returns setof public.kpi_targets
language sql
stable
security definer
set search_path = public
as $$
  select *
  from public.kpi_targets
  where public.is_admin()
  order by period_month desc;
$$;

revoke all on function public.admin_list_kpi_targets() from public;
revoke all on function public.admin_list_kpi_targets() from anon;
grant execute on function public.admin_list_kpi_targets() to authenticated;
