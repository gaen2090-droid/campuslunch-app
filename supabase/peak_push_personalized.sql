-- 점심/저녁 피크 알림 개인화: 즐겨찾기 매장 기반 추천
-- Dashboard → SQL Editor → Run (push_exclude_owners.sql 이후)
--
-- 기존 pick_peak_push_restaurant()는 전체 유저에게 "그 시각 여유로운 매장 아무거나
-- 하나"를 동일하게 추천했다. 이제는 유저별로:
--   1) 즐겨찾기(bookmarks) 매장이 있고 그중 여유로움(display_level=1) 상태인 곳이
--      있으면 → 그중 랜덤 하나를 추천 매장으로 반환 (개인화용 문구에 매장명 삽입)
--   2) 즐겨찾기가 없거나, 있어도 그중 여유로운 곳이 하나도 없으면 → 추천 매장 없이
--      관리자가 설정한 고정 홍보 문구(fallback) 그대로 발송
--
-- ⚠️ 실행 순서: 이 파일은 pick_peak_push_restaurant()를 아직 drop하지 않는다.
--    send-peak-push Edge Function이 여전히 그 함수를 호출 중이므로, 먼저 이 SQL을
--    실행해 list_peak_push_targets를 만들고 → Edge Function을 재배포한 뒤 →
--    peak_push_personalized_cleanup.sql로 구 함수를 정리한다. 순서를 바꾸면
--    Edge Function이 존재하지 않는 함수를 호출해 그날 피크 푸시가 통째로 실패한다.
--
-- 사장님 제외(peak_exclude_owners) 필터는 그대로 적용된다.

create or replace function public.list_peak_push_targets(p_slot text)
returns table (
  user_id uuid,
  token text,
  restaurant_id uuid,
  restaurant_name text
)
language sql
volatile
security definer
set search_path = public
as $$
  with recipients as (
    select t.user_id, t.token
    from public.user_push_tokens t
    join public.user_notification_prefs p on p.user_id = t.user_id
    where (
      (p_slot = 'lunch' and p.peak_lunch)
      or (p_slot = 'dinner' and p.peak_dinner)
      or (
        p_slot is distinct from 'lunch'
        and p_slot is distinct from 'dinner'
        and (p.peak_lunch or p.peak_dinner)
      )
    )
    and not (
      coalesce((select c.peak_exclude_owners from public.push_notification_config c where c.id = 1), false)
      and public.is_any_restaurant_owner(t.user_id)
    )
  ),
  ranked_bookmarks as (
    select
      b.user_id,
      r.id as restaurant_id,
      r.name as restaurant_name,
      row_number() over (
        partition by b.user_id
        order by random()
      ) as rn
    from public.bookmarks b
    join public.restaurants r on r.id = b.restaurant_id
    join public.crowd_status cs on cs.restaurant_id = r.id
    where b.user_id is not null
      and coalesce(r.is_active, true)
      and cs.display_level = 1
      and coalesce(cs.last_applied_report_at, cs.updated_at) > now() - interval '3 hours'
  )
  select
    rec.user_id,
    rec.token,
    rb.restaurant_id,
    rb.restaurant_name
  from recipients rec
  left join ranked_bookmarks rb on rb.user_id = rec.user_id and rb.rn = 1;
$$;

revoke all on function public.list_peak_push_targets(text) from public;
grant execute on function public.list_peak_push_targets(text) to service_role;

-- ── 피크 스케줄에 "개인화용"/"고정 홍보용" 문구 쌍 추가 ──
-- admin_update_push_notification_config를 재정의해 fallback_title_template /
-- fallback_body_template 검증을 추가한다. 라이브 시그니처는 push_exclude_owners.sql의
-- 13-인자 버전이므로 그대로 유지(인자 목록 변경 없음, 본문 로직만 갱신).

create or replace function public.admin_update_push_notification_config(
  p_peak_schedules jsonb,
  p_weekdays_only boolean,
  p_schedule_days_ahead integer,
  p_peak_fcm_enabled boolean default false,
  p_community_fcm_enabled boolean default true,
  p_peak_local_schedule_enabled boolean default true,
  p_community_comment_title_template text default null,
  p_community_comment_body_template text default null,
  p_news_fcm_enabled boolean default true,
  p_community_reply_title_template text default null,
  p_community_reply_body_template text default null,
  p_peak_exclude_owners boolean default false,
  p_news_exclude_owners boolean default false
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  result jsonb;
  elem jsonb;
  i int;
  v_id text;
  v_hour int;
  v_minute int;
  v_title text;
  v_body text;
  v_fallback_title text;
  v_fallback_body text;
  lunch_h int := 12;
  lunch_m int := 0;
  dinner_h int := 18;
  dinner_m int := 0;
  sync_title text;
  sync_body text;
  seen_lunch boolean := false;
  seen_dinner boolean := false;
begin
  if not public.is_admin() then
    raise exception '관리자만 푸시 설정을 변경할 수 있어요.';
  end if;

  if p_peak_schedules is null or jsonb_typeof(p_peak_schedules) <> 'array' then
    raise exception '피크 스케줄 목록이 올바르지 않아요.';
  end if;
  if jsonb_array_length(p_peak_schedules) = 0 then
    raise exception '피크 스케줄을 1개 이상 추가해주세요.';
  end if;
  if jsonb_array_length(p_peak_schedules) > 8 then
    raise exception '피크 스케줄은 최대 8개까지예요.';
  end if;

  for i in 0 .. jsonb_array_length(p_peak_schedules) - 1 loop
    elem := p_peak_schedules -> i;
    v_id := nullif(trim(coalesce(elem ->> 'id', '')), '');
    v_hour := coalesce((elem ->> 'hour')::int, -1);
    v_minute := coalesce((elem ->> 'minute')::int, -1);
    v_title := trim(coalesce(elem ->> 'title_template', ''));
    v_body := trim(coalesce(elem ->> 'body_template', ''));
    v_fallback_title := trim(coalesce(elem ->> 'fallback_title_template', ''));
    v_fallback_body := trim(coalesce(elem ->> 'fallback_body_template', ''));

    if v_id is null then
      raise exception '스케줄 id가 비어 있어요.';
    end if;
    if v_hour < 0 or v_hour > 23 or v_minute < 0 or v_minute > 59 then
      raise exception '스케줄 시각이 올바르지 않아요. (%)', v_id;
    end if;
    if v_title = '' then
      raise exception '개인화용 제목을 입력해주세요. (%)', v_id;
    end if;
    if v_body = '' then
      raise exception '개인화용 본문을 입력해주세요. (%)', v_id;
    end if;
    if v_fallback_title = '' then
      raise exception '고정 홍보용 제목을 입력해주세요. (%)', v_id;
    end if;
    if v_fallback_body = '' then
      raise exception '고정 홍보용 본문을 입력해주세요. (%)', v_id;
    end if;

    if v_id = 'lunch' or (not seen_lunch and i = 0) then
      lunch_h := v_hour;
      lunch_m := v_minute;
      seen_lunch := true;
    end if;
    if v_id = 'dinner' or (not seen_dinner and i = 1) then
      dinner_h := v_hour;
      dinner_m := v_minute;
      seen_dinner := true;
    end if;

    if sync_title is null then
      sync_title := v_fallback_title;
      sync_body := v_fallback_body;
    end if;
  end loop;

  update public.push_notification_config
  set
    peak_schedules = p_peak_schedules,
    lunch_hour = lunch_h,
    lunch_minute = lunch_m,
    dinner_hour = dinner_h,
    dinner_minute = dinner_m,
    title_template = coalesce(sync_title, title_template),
    body_template = coalesce(sync_body, body_template),
    weekdays_only = p_weekdays_only,
    schedule_days_ahead = greatest(1, least(coalesce(p_schedule_days_ahead, 14), 30)),
    peak_fcm_enabled = coalesce(p_peak_fcm_enabled, false),
    community_fcm_enabled = coalesce(p_community_fcm_enabled, true),
    peak_local_schedule_enabled = coalesce(p_peak_local_schedule_enabled, true),
    community_comment_title_template = coalesce(
      nullif(trim(p_community_comment_title_template), ''),
      community_comment_title_template
    ),
    community_comment_body_template = coalesce(
      nullif(trim(p_community_comment_body_template), ''),
      community_comment_body_template
    ),
    news_fcm_enabled = coalesce(p_news_fcm_enabled, true),
    community_reply_title_template = coalesce(
      nullif(trim(p_community_reply_title_template), ''),
      community_reply_title_template
    ),
    community_reply_body_template = coalesce(
      nullif(trim(p_community_reply_body_template), ''),
      community_reply_body_template
    ),
    peak_exclude_owners = coalesce(p_peak_exclude_owners, false),
    news_exclude_owners = coalesce(p_news_exclude_owners, false),
    updated_at = now()
  where id = 1
  returning to_jsonb(push_notification_config.*) into result;

  return result;
end;
$$;

revoke all on function public.admin_update_push_notification_config(
  jsonb, boolean, integer, boolean, boolean, boolean, text, text, boolean, text, text, boolean, boolean
) from public;
grant execute on function public.admin_update_push_notification_config(
  jsonb, boolean, integer, boolean, boolean, boolean, text, text, boolean, text, text, boolean, boolean
) to authenticated;

-- ── 기존 peak_schedules에 fallback_* 필드 백필 (없으면 기존 문구를 그대로 고정용으로) ──
update public.push_notification_config c
set peak_schedules = (
  select jsonb_agg(
    case
      when elem ? 'fallback_title_template' and elem ? 'fallback_body_template'
        then elem
      else elem
        || jsonb_build_object(
          'fallback_title_template',
          coalesce(nullif(elem ->> 'title_template', ''), '대기 없이 식사할 수 있어요'),
          'fallback_body_template',
          coalesce(
            nullif(elem ->> 'body_template', ''),
            '지금 바로 입장 가능한 매장을 확인해보세요' || chr(10) || '확인하러 가기 >'
          )
        )
        || jsonb_build_object(
          'title_template', '{restaurant}에서 대기없이 식사할 수 있어요',
          'body_template', '다른 매장도 확인해보기 >'
        )
    end
    order by ord
  )
  from jsonb_array_elements(c.peak_schedules) with ordinality as t(elem, ord)
)
where id = 1
  and c.peak_schedules is not null
  and exists (
    select 1 from jsonb_array_elements(c.peak_schedules) e
    where not (e ? 'fallback_title_template')
  );

select 'peak_push_personalized.sql ok' as status;
