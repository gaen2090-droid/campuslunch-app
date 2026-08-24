-- crowd_status 재계산 스윕 / 피크푸시 대상 선정에서 crowd_enabled=false 매장 제외
-- (Dashboard → SQL Editor → Run, crowd_enabled_two_tier.sql 이후)
--
-- submit_crowd_report가 crowd_enabled=false 매장의 제보 자체를 막아서 crowd_reports가
-- 애초에 쌓이지 않지만, 스윕/집계 쪽도 명시적으로 제외해둔다 — "필터링 잊는 숨은 코드"가
-- 되지 않도록 하기 위함 (docs/PLAN_two_tier_restaurants.md §3-5,
-- [[crowd-status-updated-at-trigger-bug]] 재발 방지 원칙).

create or replace function public.recalculate_all_crowd_status(
  p_owner_just_reported boolean default false
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  r record;
begin
  for r in
    select id from public.restaurants
    where is_active = true and crowd_enabled = true
  loop
    perform public.recalculate_crowd_status(r.id, p_owner_just_reported);
  end loop;
end;
$$;

-- 개인화 피크 푸시: 즐겨찾기 추천 후보에서도 crowd_enabled=true만 대상.
create or replace function public.list_peak_push_targets(p_slot text)
returns table (
  user_id uuid,
  token text,
  restaurant_id uuid,
  restaurant_name text
)
language sql
volatile
security definer
set search_path = public
as $$
  with recipients as (
    select t.user_id, t.token
    from public.user_push_tokens t
    join public.user_notification_prefs p on p.user_id = t.user_id
    where (
      (p_slot = 'lunch' and p.peak_lunch)
      or (p_slot = 'dinner' and p.peak_dinner)
      or (
        p_slot is distinct from 'lunch'
        and p_slot is distinct from 'dinner'
        and (p.peak_lunch or p.peak_dinner)
      )
    )
    and not (
      coalesce((select c.peak_exclude_owners from public.push_notification_config c where c.id = 1), false)
      and public.is_any_restaurant_owner(t.user_id)
    )
  ),
  ranked_bookmarks as (
    select
      b.user_id,
      r.id as restaurant_id,
      r.name as restaurant_name,
      row_number() over (
        partition by b.user_id
        order by random()
      ) as rn
    from public.bookmarks b
    join public.restaurants r on r.id = b.restaurant_id
    join public.crowd_status cs on cs.restaurant_id = r.id
    where b.user_id is not null
      and coalesce(r.is_active, true)
      and coalesce(r.crowd_enabled, true)
      and cs.display_level = 1
      and coalesce(cs.last_applied_report_at, cs.updated_at) > now() - interval '3 hours'
  )
  select
    rec.user_id,
    rec.token,
    rb.restaurant_id,
    rb.restaurant_name
  from recipients rec
  left join ranked_bookmarks rb on rb.user_id = rec.user_id and rb.rn = 1;
$$;

revoke all on function public.list_peak_push_targets(text) from public;
grant execute on function public.list_peak_push_targets(text) to service_role;

select 'crowd_enabled_sweep_filter.sql ok' as status;
