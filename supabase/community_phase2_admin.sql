-- 커뮤니티 Phase 2: 웹 어드민 모더레이션 조회 RPC (Dashboard → SQL Editor → Run)
-- 신고 큐 + 최근 글/댓글(숨김 포함) 조회. 숨김/삭제 액션 자체는 phase1의 RLS
-- (posts/comments update-or-admin, delete-or-admin)로 이미 허용되어 있어 별도 RPC 불필요.

-- ── 신고 큐 (게시글/댓글 신고 모두 처리, 신고자·대상 콘텐츠·작성자 닉네임 조인) ──

create or replace function public.admin_list_community_reports()
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
    select jsonb_agg(row_to_json(t) order by t.created_at desc)
    from (
      select
        rep.id,
        rep.reason,
        rep.created_at,
        reporter.nickname as reporter_nickname,
        rep.post_id,
        rep.comment_id,
        case when rep.post_id is not null then p.content else c.content end as content,
        case when rep.post_id is not null then p.is_hidden else c.is_hidden end as is_hidden,
        case when rep.post_id is not null then pu.nickname else cu.nickname end as author_nickname,
        coalesce(rep.post_id, c.post_id) as target_post_id
      from public.community_reports rep
      join public.users reporter on reporter.id = rep.reporter_id
      left join public.community_posts p on p.id = rep.post_id
      left join public.users pu on pu.id = p.user_id
      left join public.community_comments c on c.id = rep.comment_id
      left join public.users cu on cu.id = c.user_id
      order by rep.created_at desc
    ) t
  ), '[]'::jsonb);
end;
$$;

-- ── 최근 게시글 목록 (숨김 포함, 운영 확인용) ──

create or replace function public.admin_list_community_posts(p_limit int default 50)
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
    select jsonb_agg(row_to_json(t) order by t.created_at desc)
    from (
      select
        p.id,
        p.content,
        p.image_urls,
        p.is_hidden,
        p.like_count,
        p.comment_count,
        p.created_at,
        u.nickname
      from public.community_posts p
      join public.users u on u.id = p.user_id
      order by p.created_at desc
      limit p_limit
    ) t
  ), '[]'::jsonb);
end;
$$;

revoke all on function public.admin_list_community_reports() from public;
revoke all on function public.admin_list_community_posts(int) from public;
grant execute on function public.admin_list_community_reports() to authenticated;
grant execute on function public.admin_list_community_posts(int) to authenticated;
