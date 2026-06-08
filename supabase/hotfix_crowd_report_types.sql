-- 혼잡도 제보 RPC 타입 수정 (한 번 Run)
-- 증상: column "level" is of type crowd_level but expression is of type text
--        type "report_source" does not exist
--
-- 실제 DB enum:
--   crowd_reports.level  → crowd_level  (closed|relaxed|normal|full)
--   crowd_reports.source → crowd_source (user|owner|system)  ← report_source 아님

create or replace function public.ui_level_to_crowd_level(p_ui_level int)
returns public.crowd_level
language sql
immutable
as $$
  select case greatest(1, least(3, coalesce(p_ui_level, 1)))
    when 1 then 'normal'::public.crowd_level
    when 2 then 'full'::public.crowd_level
    else 'full'::public.crowd_level
  end;
$$;

create or replace function public.text_to_crowd_source(p_source text)
returns public.crowd_source
language sql
immutable
as $$
  select case trim(coalesce(p_source, ''))
    when 'owner' then 'owner'::public.crowd_source
    when 'system' then 'system'::public.crowd_source
    else 'user'::public.crowd_source
  end;
$$;

create or replace function public.submit_crowd_report(
  p_restaurant_id uuid,
  p_status text,
  p_source text default 'user',
  p_lat double precision default null,
  p_lng double precision default null
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_lat double precision;
  v_lng double precision;
  v_distance double precision;
  v_level public.crowd_level;
  v_source public.crowd_source;
  v_ui_level int;
begin
  if v_uid is null then
    raise exception '로그인이 필요해요.';
  end if;

  if p_status not in ('여유로움', '약간혼잡', '자리없음') then
    raise exception '유효하지 않은 혼잡도예요.';
  end if;

  v_ui_level := public.ui_status_to_level(p_status);

  if p_source not in ('user', 'owner') then
    raise exception '유효하지 않은 제보 유형이에요.';
  end if;

  v_level := public.ui_level_to_crowd_level(v_ui_level);
  v_source := public.text_to_crowd_source(p_source);

  if p_source = 'owner' then
    if not exists (
      select 1
      from public.restaurants r
      where r.id = p_restaurant_id
        and r.is_active = true
        and r.owner_id = v_uid
    ) then
      raise exception '본인 매장만 변경할 수 있어요.';
    end if;
  end if;

  if p_source = 'user' then
    if p_lat is null or p_lng is null then
      raise exception '현재 위치를 확인할 수 없어요. 위치 권한을 확인해주세요.';
    end if;

    if exists (
      select 1
      from public.crowd_reports cr
      where cr.restaurant_id = p_restaurant_id
        and cr.user_id = v_uid
        and cr.source = 'user'::public.crowd_source
        and cr.created_at >= now() - interval '5 minutes'
    ) then
      raise exception E'방금 제보한 식당이에요.\n잠시 후 다시 제보해주세요.';
    end if;

    select r.latitude, r.longitude
    into v_lat, v_lng
    from public.restaurants r
    where r.id = p_restaurant_id;

    if v_lat is null or v_lng is null then
      raise exception '식당 위치 정보가 없어요.';
    end if;

    v_distance := public.haversine_meters(p_lat, p_lng, v_lat, v_lng);
    if v_distance > 80 then
      raise exception '식당 근처에서만 혼잡도를 제보할 수 있어요.';
    end if;
  end if;

  insert into public.crowd_reports (
    restaurant_id,
    level,
    source,
    user_id,
    metadata
  )
  values (
    p_restaurant_id,
    v_level,
    v_source,
    v_uid,
    jsonb_build_object(
      'status', public.level_to_ui_status(v_ui_level),
      'user_id', v_uid::text,
      'lat', p_lat,
      'lng', p_lng
    )
  );
end;
$$;

grant execute on function public.ui_level_to_crowd_level(int) to anon, authenticated;
grant execute on function public.text_to_crowd_source(text) to anon, authenticated;
grant execute on function public.submit_crowd_report(uuid, text, text, double precision, double precision)
  to authenticated;

-- RLS: crowd_source enum 명시
drop policy if exists "crowd_reports_insert_auth" on public.crowd_reports;
create policy "crowd_reports_insert_auth" on public.crowd_reports
  for insert
  to authenticated
  with check (
    source in (
      'user'::public.crowd_source,
      'owner'::public.crowd_source
    )
  );
