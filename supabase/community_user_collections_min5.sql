-- ── 맛집 컬렉션 최소 5개 등록 제한 + 관리자 작성자명 표시 (Dashboard → SQL Editor → Run) ──
-- 실행 순서: community_user_collections_update.sql 이후

-- ── create_user_collection: 최소 5개 검증 추가 ──

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
begin
  if v_uid is null then
    raise exception '로그인이 필요해요.';
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

-- ── update_user_collection: 최소 5개 검증 추가 ──

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

  if p_restaurant_ids is null or array_length(p_restaurant_ids, 1) is null
     or array_length(p_restaurant_ids, 1) < 5 then
    raise exception '매장을 최소 5개 이상 선택해주세요.';
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

-- ── collections_with_likes: 관리자 큐레이션 작성자명을 '캠런관리자'로 표시 ──

drop function if exists public.collections_with_likes();
create or replace function public.collections_with_likes()
returns table (
  id uuid,
  title text,
  subtitle text,
  sort_order int,
  like_count int,
  liked_by_me boolean,
  comment_count int,
  author_nickname text,
  is_owner boolean,
  created_at timestamptz
)
language sql
stable
security definer
set search_path = public
as $$
  select
    c.id,
    c.title,
    c.subtitle,
    c.sort_order,
    (select count(*) from public.collection_likes l where l.collection_id = c.id)::int as like_count,
    exists (
      select 1 from public.collection_likes l
      where l.collection_id = c.id and l.user_id = auth.uid()
    ) as liked_by_me,
    (
      select count(*) from public.collection_comments cc
      where cc.collection_id = c.id and not cc.is_hidden
    )::int as comment_count,
    case when c.user_id is null then '캠런관리자' else u.nickname end as author_nickname,
    (c.user_id = auth.uid()) as is_owner,
    c.created_at
  from public.collections c
  left join public.users u on u.id = c.user_id
  where
    (c.user_id is null and c.is_published)
    or (c.user_id is not null and not c.is_hidden)
  order by
    case when c.user_id is null then c.sort_order else null end asc nulls last,
    c.created_at desc;
$$;

revoke all on function public.collections_with_likes() from public;
grant execute on function public.collections_with_likes() to authenticated;
