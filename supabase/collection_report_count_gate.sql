-- 맛집 컬렉션 등록 조건: 누적 제보수 10회 이상 (Dashboard → SQL Editor → Run)
-- 실행 순서: community_user_collections_min5.sql 이후

create or replace function public.my_crowd_report_count()
returns int
language sql
stable
security definer
set search_path = public
as $$
  select count(*)::int
  from public.crowd_reports cr
  where cr.user_id = auth.uid();
$$;

revoke all on function public.my_crowd_report_count() from public;
grant execute on function public.my_crowd_report_count() to authenticated;

-- ── create_user_collection: 누적 제보 10회 미만이면 등록 불가 ──

drop function if exists public.create_user_collection(text, text, uuid[]);
create or replace function public.create_user_collection(
  p_title      text,
  p_subtitle   text,
  p_restaurant_ids uuid[]
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_collection_id uuid;
  v_restaurant_id uuid;
  v_idx int := 0;
  v_report_count int;
begin
  if v_uid is null then
    raise exception '로그인이 필요해요.';
  end if;

  select count(*) into v_report_count
  from public.crowd_reports cr
  where cr.user_id = v_uid;

  if v_report_count < 10 then
    raise exception '누적 제보 10회 이상부터 컬렉션을 만들 수 있어요.';
  end if;

  if p_title is null or char_length(trim(p_title)) = 0 then
    raise exception '제목을 입력해주세요.';
  end if;

  if p_restaurant_ids is null or array_length(p_restaurant_ids, 1) is null
     or array_length(p_restaurant_ids, 1) < 5 then
    raise exception '매장을 최소 5개 이상 선택해주세요.';
  end if;

  if array_length(p_restaurant_ids, 1) > 20 then
    raise exception '컬렉션에는 매장을 최대 20개까지 등록할 수 있어요.';
  end if;

  insert into public.collections (title, subtitle, user_id, is_published)
  values (trim(p_title), nullif(trim(coalesce(p_subtitle, '')), ''), v_uid, true)
  returning id into v_collection_id;

  foreach v_restaurant_id in array p_restaurant_ids loop
    insert into public.collection_items (collection_id, restaurant_id, sort_order)
    values (v_collection_id, v_restaurant_id, v_idx);
    v_idx := v_idx + 1;
  end loop;

  return v_collection_id;
end;
$$;

grant execute on function public.create_user_collection(text, text, uuid[]) to authenticated;

select 'collection_report_count_gate.sql ok' as status;
