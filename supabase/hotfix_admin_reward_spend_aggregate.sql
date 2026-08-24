-- 어드민 리워드 지출 리포트: gifts 원본 전부 jsonb_agg 하지 않고 유저별 집계만 반환
-- (전체 지표 엑셀 내보내기 시 PostgREST 응답·타임아웃으로 실패하던 원인 수정)
-- Dashboard → SQL Editor → Run

create or replace function public.admin_reward_spend_report()
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_users jsonb;
  v_total_count int;
  v_total_amount bigint;
  v_attributed int;
  v_unattributed int;
  v_missing_face int;
begin
  if not exists (
    select 1 from public.users u
    where u.id = v_uid and u.role = 'admin'
  ) then
    raise exception '관리자만 조회할 수 있어요.';
  end if;

  with assigned as (
    select
      g.assigned_user_id as user_id,
      coalesce(u.nickname, '') as nickname,
      coalesce(u.email, '') as email,
      g.face_value,
      g.product_name,
      case
        when g.face_value is not null and g.face_value > 0 then g.face_value
        when (regexp_match(coalesce(g.product_name, ''), '([0-9]{3,6})\s*원'))[1] is not null
          then ((regexp_match(coalesce(g.product_name, ''), '([0-9]{3,6})\s*원'))[1])::int
        else 0
      end as amount_krw,
      (g.face_value is null or g.face_value <= 0) as missing_face
    from public.gifticons g
    left join public.users u on u.id = g.assigned_user_id
    where g.assigned_at is not null
  ),
  totals as (
    select
      count(*)::int as total_count,
      coalesce(sum(amount_krw), 0)::bigint as total_amount,
      count(*) filter (where user_id is not null)::int as attributed,
      count(*) filter (where user_id is null)::int as unattributed,
      count(*) filter (where missing_face)::int as missing_face
    from assigned
  ),
  by_user as (
    select
      a.user_id,
      max(a.nickname) as nickname,
      max(a.email) as email,
      count(*)::int as reward_count,
      coalesce(sum(a.amount_krw), 0)::bigint as amount_krw
    from assigned a
    where a.user_id is not null
    group by a.user_id
  )
  select
    t.total_count,
    t.total_amount,
    t.attributed,
    t.unattributed,
    t.missing_face,
    coalesce(
      (
        select jsonb_agg(
          jsonb_build_object(
            'user_id', b.user_id,
            'nickname', b.nickname,
            'email', b.email,
            'reward_count', b.reward_count,
            'amount_krw', b.amount_krw
          )
          order by b.reward_count desc, b.amount_krw desc
        )
        from by_user b
      ),
      '[]'::jsonb
    )
  into
    v_total_count,
    v_total_amount,
    v_attributed,
    v_unattributed,
    v_missing_face,
    v_users
  from totals t;

  return jsonb_build_object(
    'users', coalesce(v_users, '[]'::jsonb),
    'total_reward_count', coalesce(v_total_count, 0),
    'total_amount_krw', coalesce(v_total_amount, 0),
    'attributed_count', coalesce(v_attributed, 0),
    'unattributed_count', coalesce(v_unattributed, 0),
    'missing_face_value_count', coalesce(v_missing_face, 0),
    'note', '서버 집계본. face_value 우선, 없으면 product_name N원 패턴.'
  );
end;
$$;

grant execute on function public.admin_reward_spend_report() to authenticated;

comment on function public.admin_reward_spend_report() is
  '어드민 리워드 지출: 유저별 집계만 반환 (원본 gifts 전부 전송하지 않음)';

select 'hotfix_admin_reward_spend_aggregate.sql ok' as status;
