-- 사장님 인증 반려 알림: 승인(owner_approved)과 동일한 방식으로, 신청 시 앱푸시
-- 수신을 선택한 경우 반려 시에도 앱 푸시를 발송한다.
-- Dashboard → SQL Editor → Run (owner_application_notify_method.sql 이후)
-- ※ send-community-push Edge Function에 owner_rejected 핸들러를 먼저 배포한 뒤 실행할 것
--   (안 그러면 반려 알림이 미지원 이벤트로 조용히 무시됨).

create or replace function public.admin_review_owner_application(
  p_application_id uuid,
  p_approve        boolean,
  p_reject_reason  text default null
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_app public.owner_applications;
  edge_url text;
  edge_secret text;
begin
  if not public.is_admin() then
    raise exception '관리자만 처리할 수 있어요.';
  end if;

  select * into v_app
  from public.owner_applications
  where id = p_application_id
  for update;

  if not found then
    raise exception '신청 내역을 찾을 수 없어요.';
  end if;

  if v_app.status <> 'pending' then
    raise exception '이미 처리된 신청이에요.';
  end if;

  if p_approve then
    if exists (
      select 1 from public.restaurants r
      where r.id = v_app.restaurant_id and r.owner_id is not null
    ) then
      raise exception '이미 사장님이 등록된 매장이에요.';
    end if;

    update public.restaurants
    set owner_id = v_app.user_id
    where id = v_app.restaurant_id;

    update public.owner_applications
    set status = 'approved',
        reviewed_by = auth.uid(),
        reviewed_at = now()
    where id = p_application_id;

    if v_app.notify_push then
      begin
        select c.community_url, c.push_secret
          into edge_url, edge_secret
        from public.push_edge_runtime_config c
        where c.id = 1;
        if edge_url is not null and edge_secret is not null then
          perform net.http_post(
            url := edge_url,
            headers := jsonb_build_object(
              'Content-Type', 'application/json',
              'Authorization', coalesce('Bearer ' || edge_secret, '')
            ),
            body := jsonb_build_object(
              'event', 'owner_approved',
              'user_id', v_app.user_id,
              'restaurant_id', v_app.restaurant_id
            )
          );
        end if;
      exception
        when others then
          -- 푸시 실패가 승인 처리를 막지 않는다.
          raise warning 'owner approval push webhook failed: %', sqlerrm;
      end;
    end if;
  else
    update public.owner_applications
    set status = 'rejected',
        reject_reason = p_reject_reason,
        reviewed_by = auth.uid(),
        reviewed_at = now()
    where id = p_application_id;

    if v_app.notify_push then
      begin
        select c.community_url, c.push_secret
          into edge_url, edge_secret
        from public.push_edge_runtime_config c
        where c.id = 1;
        if edge_url is not null and edge_secret is not null then
          perform net.http_post(
            url := edge_url,
            headers := jsonb_build_object(
              'Content-Type', 'application/json',
              'Authorization', coalesce('Bearer ' || edge_secret, '')
            ),
            body := jsonb_build_object(
              'event', 'owner_rejected',
              'user_id', v_app.user_id
            )
          );
        end if;
      exception
        when others then
          -- 푸시 실패가 반려 처리를 막지 않는다.
          raise warning 'owner rejection push webhook failed: %', sqlerrm;
      end;
    end if;
  end if;
end;
$$;

revoke all on function public.admin_review_owner_application(uuid, boolean, text) from public;
grant execute on function public.admin_review_owner_application(uuid, boolean, text) to authenticated;

select 'owner_application_reject_push.sql ok' as status;
