-- 커뮤니티 피드 검색 (Dashboard → SQL Editor → Run)
-- community_feed RPC에 검색어 파라미터(p_query) 추가 — 게시글 내용/매장명/댓글 내용 기준
-- ilike 검색(댓글에 매치되면 그 댓글이 달린 게시글을 결과에 포함, 카카오톡/카페 검색 방식).
-- 기존 (int, timestamptz) 시그니처를 대체하므로 먼저 drop 후 재생성한다.

drop function if exists public.community_feed(int, timestamptz);

create or replace function public.community_feed(
  p_limit int default 20,
  p_before timestamptz default null,
  p_query text default null
)
returns table (
  id uuid,
  content text,
  image_urls text[],
  nickname text,
  restaurant_id uuid,
  restaurant_name text,
  like_count int,
  comment_count int,
  liked_by_me boolean,
  created_at timestamptz,
  updated_at timestamptz,
  is_owner boolean
)
language sql
stable
security definer
set search_path = public
as $$
  select
    p.id,
    p.content,
    p.image_urls,
    u.nickname,
    p.restaurant_id,
    r.name as restaurant_name,
    p.like_count,
    p.comment_count,
    exists (
      select 1 from public.community_likes l
      where l.post_id = p.id and l.user_id = auth.uid()
    ) as liked_by_me,
    p.created_at,
    p.updated_at,
    (p.user_id = auth.uid()) as is_owner
  from public.community_posts p
  join public.users u on u.id = p.user_id
  left join public.restaurants r on r.id = p.restaurant_id
  where not p.is_hidden
    and (p_before is null or p.created_at < p_before)
    and (
      p_query is null
      or trim(p_query) = ''
      or p.content ilike '%' || replace(replace(trim(p_query), '%', '\%'), '_', '\_') || '%'
      or r.name ilike '%' || replace(replace(trim(p_query), '%', '\%'), '_', '\_') || '%'
      or exists (
        select 1 from public.community_comments c
        where c.post_id = p.id
          and not c.is_hidden
          and c.content ilike '%' || replace(replace(trim(p_query), '%', '\%'), '_', '\_') || '%'
      )
    )
  order by p.created_at desc
  limit p_limit;
$$;

revoke all on function public.community_feed(int, timestamptz, text) from public;
grant execute on function public.community_feed(int, timestamptz, text) to authenticated;

-- 확인 (Success 나오면 OK)
select public.community_feed(5, null, null);
