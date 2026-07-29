-- 맛집 컬렉션 해시태그 (어드민에서 선택, #혼밥/#밥약/#카공/#맛집 등)
-- Dashboard → SQL Editor → Run

alter table public.collections
  add column if not exists hashtags text[] not null default '{}';

-- collections_with_likes(): RETURNS TABLE 이라 컬럼 추가 시 반드시 DROP 후 재생성
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
  created_at timestamptz,
  hashtags text[]
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
    c.created_at,
    c.hashtags
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
grant execute on function public.collections_with_likes() to authenticated, anon;

-- admin_list_collections(): RETURNS jsonb 라 create or replace만으로 안전
create or replace function public.admin_list_collections()
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
begin
  if not public.is_admin() then
    raise exception '관리자만 조회할 수 있어요.';
  end if;

  return coalesce((
    select jsonb_agg(row_to_json(t) order by t.sort_order asc nulls last, t.created_at desc)
    from (
      select
        c.id,
        c.title,
        c.subtitle,
        c.sort_order,
        c.is_published,
        c.created_at,
        c.user_id,
        u.nickname as author_nickname,
        c.hashtags
      from public.collections c
      left join public.users u on u.id = c.user_id
    ) t
  ), '[]'::jsonb);
end;
$$;

select 'collection_hashtags.sql ok' as status;
