-- 사장님 본인 매장 등록 해제 (owner_id·owner_registered 초기화)
-- 마지막 매장 삭제 시 users.role도 owner→user로 되돌림 (커뮤니티 사장님 배지가 users.role 기준이라 안 돌리면 배지가 안 빠짐).
-- Dashboard → SQL Editor (rpc_claim_owner.sql 이후)
-- 기존에 이미 이 버그를 겪은 계정은 rpc_claim_owner.sql 하단의 일회성 UPDATE로 복구.

create or replace function public.release_owner_restaurant(p_restaurant_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  uid uuid := auth.uid();
  desc_json jsonb;
begin
  if uid is null then
    raise exception 'LOGIN_REQUIRED';
  end if;

  select r.description::jsonb
  into desc_json
  from public.restaurants r
  where r.id = p_restaurant_id
    and r.is_active = true
    and r.owner_id = uid;

  if not found then
    raise exception 'NOT_OWNER';
  end if;

  if desc_json is not null then
    desc_json := jsonb_set(desc_json, '{owner_registered}', 'false'::jsonb, true);
  end if;

  update public.restaurants
  set
    owner_id = null,
    description = coalesce(desc_json::text, description)
  where id = p_restaurant_id;

  -- 더 이상 소유한 매장이 없으면 role을 user로 되돌린다 (커뮤니티 사장님 배지 등에 사용됨).
  -- active_owner_restaurant_id도 함께 비워야 한다 — 안 그러면 community_posts_set_owner_snapshot
  -- 트리거가 삭제된 매장 id를 새 글에도 계속 스냅샷해서, 매장 삭제 후 새로 쓴 글까지
  -- "OO 사장님"으로 잘못 표시되는 문제가 생긴다.
  update public.users
  set role = case when role = 'owner'::public.user_role
                  then 'user'::public.user_role else role end,
      active_owner_restaurant_id = null,
      updated_at = now()
  where id = uid
    and not exists (
      select 1 from public.restaurants r
      where r.owner_id = uid and r.is_active = true
    );
end;
$$;

revoke all on function public.release_owner_restaurant(uuid) from public;
grant execute on function public.release_owner_restaurant(uuid) to authenticated;

-- 일회성 복구 1: 이미 매장을 잃었는데 active_owner_restaurant_id가 안 지워진 기존 계정 정리
-- (owner_id가 null이 된 매장을 여전히 active_owner_restaurant_id로 물고 있는 경우)
update public.users u
set active_owner_restaurant_id = null
where u.active_owner_restaurant_id is not null
  and not exists (
    select 1 from public.restaurants r
    where r.id = u.active_owner_restaurant_id and r.owner_id = u.id and r.is_active = true
  );

-- 일회성 복구 2: 이미 작성된 글/댓글에 박힌 스냅샷도 정리.
-- 지금도 그 매장을 소유 중이면(다중 매장 사장님이 활동 매장만 바꾼 경우) 손대지 않고
-- 과거 표시를 그대로 유지 — 실제로 매장을 잃은 경우에만 스냅샷을 지운다.
update public.community_posts p
set author_owner_restaurant_id = null
where p.author_owner_restaurant_id is not null
  and not exists (
    select 1 from public.restaurants r
    where r.id = p.author_owner_restaurant_id
      and r.owner_id = p.user_id and r.is_active = true
  );

update public.community_comments c
set author_owner_restaurant_id = null
where c.author_owner_restaurant_id is not null
  and not exists (
    select 1 from public.restaurants r
    where r.id = c.author_owner_restaurant_id
      and r.owner_id = c.user_id and r.is_active = true
  );
