-- ── 유저 작성 맛집 컬렉션 수정 (Dashboard → SQL Editor → Run) ──
-- 실행 순서: community_user_collections.sql 이후

drop function if exists public.update_user_collection(uuid, text, text, uuid[]);
create or replace function public.update_user_collection(
  p_collection_id  uuid,
  p_title          text,
  p_subtitle       text,
  p_restaurant_ids uuid[]
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_owner_id uuid;
  v_restaurant_id uuid;
  v_idx int := 0;
begin
  if v_uid is null then
    raise exception '로그인이 필요해요.';
  end if;

  select user_id into v_owner_id
  from public.collections
  where id = p_collection_id;

  if v_owner_id is null or v_owner_id <> v_uid then
    raise exception '본인이 작성한 컬렉션만 수정할 수 있어요.';
  end if;

  if p_title is null or char_length(trim(p_title)) = 0 then
    raise exception '제목을 입력해주세요.';
  end if;

  if p_restaurant_ids is null or array_length(p_restaurant_ids, 1) is null then
    raise exception '매장을 1개 이상 선택해주세요.';
  end if;

  if array_length(p_restaurant_ids, 1) > 20 then
    raise exception '컬렉션에는 매장을 최대 20개까지 등록할 수 있어요.';
  end if;

  update public.collections
  set title    = trim(p_title),
      subtitle = nullif(trim(coalesce(p_subtitle, '')), '')
  where id = p_collection_id;

  delete from public.collection_items where collection_id = p_collection_id;

  foreach v_restaurant_id in array p_restaurant_ids loop
    insert into public.collection_items (collection_id, restaurant_id, sort_order)
    values (p_collection_id, v_restaurant_id, v_idx);
    v_idx := v_idx + 1;
  end loop;
end;
$$;

grant execute on function public.update_user_collection(uuid, text, text, uuid[]) to authenticated;
