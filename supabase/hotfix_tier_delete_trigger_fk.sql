-- 매장 삭제 시 FK 위반으로 트랜잭션이 롤백되는 버그 수정
--
-- 증상: admin_delete_restaurant(또는 직접 DELETE)로 restaurants 행을 지우면
-- on delete cascade로 restaurant_report_targets / restaurant_collection_venues
-- 행도 함께 지워지는데, 그 DELETE 트리거(trg_report_target_sync /
-- trg_collection_venue_sync)가 "고아 방지" 목적으로 반대쪽 테이블에 다시
-- insert를 시도한다. 이때 restaurants 행이 이미 삭제된 상태라 FK 위반이
-- 발생해 트랜잭션 전체가 롤백되고, 결과적으로 매장 삭제가 항상 실패한다.
--
-- 수정: DELETE 트리거 내부에서 restaurants에 해당 id가 더 이상 없으면
-- (= 매장 자체가 삭제되는 중이면) 재삽입을 건너뛴다.

create or replace function public.trg_report_target_sync()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if tg_op = 'INSERT' then
    delete from public.restaurant_collection_venues
    where restaurant_id = new.restaurant_id;
    update public.restaurants
    set crowd_enabled = true
    where id = new.restaurant_id
      and crowd_enabled is distinct from true;
    return new;
  end if;

  -- 매장 자체가 삭제되는 중이면 재삽입 불필요 (FK 위반 방지)
  if not exists (
    select 1 from public.restaurants where id = old.restaurant_id
  ) then
    return old;
  end if;

  -- DELETE: 컬렉션 쪽에 없으면 컬렉션으로 내려 둔다 (고아 방지)
  if not exists (
    select 1 from public.restaurant_collection_venues
    where restaurant_id = old.restaurant_id
  ) then
    insert into public.restaurant_collection_venues (restaurant_id)
    values (old.restaurant_id)
    on conflict (restaurant_id) do nothing;
  end if;
  update public.restaurants
  set crowd_enabled = false
  where id = old.restaurant_id
    and crowd_enabled is distinct from false;
  return old;
end;
$$;

create or replace function public.trg_collection_venue_sync()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if tg_op = 'INSERT' then
    delete from public.restaurant_report_targets
    where restaurant_id = new.restaurant_id;
    update public.restaurants
    set crowd_enabled = false
    where id = new.restaurant_id
      and crowd_enabled is distinct from false;
    return new;
  end if;

  -- 매장 자체가 삭제되는 중이면 재삽입 불필요 (FK 위반 방지)
  if not exists (
    select 1 from public.restaurants where id = old.restaurant_id
  ) then
    return old;
  end if;

  -- DELETE: 제보 쪽에 없으면 제보 대상으로 올린다
  if not exists (
    select 1 from public.restaurant_report_targets
    where restaurant_id = old.restaurant_id
  ) then
    insert into public.restaurant_report_targets (restaurant_id)
    values (old.restaurant_id)
    on conflict (restaurant_id) do nothing;
  end if;
  update public.restaurants
  set crowd_enabled = true
  where id = old.restaurant_id
    and crowd_enabled is distinct from true;
  return old;
end;
$$;
