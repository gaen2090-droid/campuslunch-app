-- 어드민: 미배정·만료 기프티콘 삭제 (배정/사용 완료는 보호)
-- Dashboard → SQL Editor (rewards.sql 이후)

create or replace function public.admin_delete_gifticon(p_gifticon_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_row public.gifticons;
begin
  if not exists (
    select 1 from public.users u
    where u.id = v_uid and u.role = 'admin'
  ) then
    raise exception '관리자만 기프티콘을 삭제할 수 있어요.';
  end if;

  select * into v_row
  from public.gifticons
  where id = p_gifticon_id;

  if not found then
    raise exception '기프티콘을 찾을 수 없어요.';
  end if;

  if v_row.status in ('assigned', 'used') then
    raise exception '배정되었거나 사용 완료된 기프티콘은 삭제할 수 없어요.';
  end if;

  delete from public.gifticons
  where id = p_gifticon_id;

  return jsonb_build_object(
    'status', 'ok',
    'image_url', v_row.image_url
  );
end;
$$;

grant execute on function public.admin_delete_gifticon(uuid) to authenticated;

comment on function public.admin_delete_gifticon(uuid) is
  '어드민: unassigned/expired 기프티콘 삭제. assigned/used는 거부.';
