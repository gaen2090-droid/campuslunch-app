-- 사장님 매장 관리(사진/메뉴/영업시간/공지 수정) — Dashboard → SQL Editor → Run
--
-- restaurants 테이블은 지금까지 owner가 직접 UPDATE할 수 있는 RLS 정책이 없었다
-- (restaurants_update_admin은 is_admin()만 허용). 그래서 security definer RPC로
-- owner_id = auth.uid() 소유 매장만, 아래 화이트리스트 필드만 쓸 수 있게 한다.
--
-- description(text, 내부적으로 JSON 문자열)은 manual_rank/reports_snapshot/
-- hours_periods/google_place_id 등 여러 키를 담는 catch-all이라, 여기서 절대
-- 건드리지 않고 사장님이 쓸 수 있는 키만 명시적으로 merge한다:
--   image_source ('owner'|'google'), menu_photo_urls(최대 3), menu({name,price}),
--   owner_notice(최대 500자), hours/hours_display
-- hours를 바꿀 때는 hours_periods(구글 요일별 캐시)를 함께 지운다 — 안 지우면
-- BusinessHoursData.fromDescription이 여전히 구글 캐시를 우선 사용해서 새로
-- 입력한 영업시간이 화면에 반영되지 않는다.
--
-- "구글맵 사진으로 되돌리기": 앱은 런타임에 Google Places를 다시 호출하지
-- 않으므로, 사장님이 처음 대표사진을 교체하는 시점에 그때의 image_url(구글
-- 사진)을 description.google_image_url에 한 번만 보존해둔다. p_image_source
-- ='google'로 호출하면 이 보존값으로 image_url을 되돌린다.

drop function if exists public.owner_update_restaurant(uuid, text, text, text[], jsonb, text, text, text);

create or replace function public.owner_update_restaurant(
  p_restaurant_id uuid,
  p_image_url text default null,
  p_image_source text default null,
  p_menu_photo_urls text[] default null,
  p_menu jsonb default null,
  p_hours text default null,
  p_hours_display text default null,
  p_owner_notice text default null
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_desc jsonb;
  v_current_image_url text;
  v_next_image_url text;
begin
  if v_uid is null then
    raise exception '로그인이 필요해요.';
  end if;

  select
    case when coalesce(trim(description), '') ~ '^\{'
         then description::jsonb else '{}'::jsonb end,
    image_url
  into v_desc, v_current_image_url
  from public.restaurants
  where id = p_restaurant_id and owner_id = v_uid and is_active = true;

  if not found then
    raise exception '본인 매장만 수정할 수 있어요.';
  end if;

  if p_menu_photo_urls is not null and array_length(p_menu_photo_urls, 1) > 3 then
    raise exception '메뉴 사진은 최대 3장까지예요.';
  end if;
  if p_owner_notice is not null and char_length(p_owner_notice) > 500 then
    raise exception '공지는 500자를 넘을 수 없어요.';
  end if;
  if p_image_source is not null and p_image_source not in ('owner', 'google') then
    raise exception '유효하지 않은 이미지 출처예요.';
  end if;

  v_next_image_url := p_image_url;

  if p_image_source = 'owner' then
    -- 사장님이 처음 교체하는 순간의 구글 사진을 한 번만 보존
    if coalesce(v_desc->>'image_source', 'google') <> 'owner'
       and not (v_desc ? 'google_image_url') then
      v_desc := jsonb_set(v_desc, '{google_image_url}', to_jsonb(coalesce(v_current_image_url, '')));
    end if;
    v_desc := jsonb_set(v_desc, '{image_source}', to_jsonb('owner'::text));
  elsif p_image_source = 'google' then
    -- 되돌리기: 보존해둔 구글 사진으로 복원 (보존값이 없으면 현재값 유지)
    if v_desc ? 'google_image_url' then
      v_next_image_url := coalesce(nullif(v_desc->>'google_image_url', ''), v_current_image_url);
    end if;
    v_desc := jsonb_set(v_desc, '{image_source}', to_jsonb('google'::text));
  end if;

  if p_menu_photo_urls is not null then
    v_desc := jsonb_set(v_desc, '{menu_photo_urls}', to_jsonb(p_menu_photo_urls));
  end if;
  if p_menu is not null then
    v_desc := jsonb_set(v_desc, '{menu}', p_menu);
  end if;
  if p_owner_notice is not null then
    v_desc := jsonb_set(v_desc, '{owner_notice}', to_jsonb(p_owner_notice));
  end if;
  if p_hours is not null then
    v_desc := jsonb_set(v_desc, '{hours}', to_jsonb(p_hours));
    v_desc := jsonb_set(
      v_desc, '{hours_display}',
      to_jsonb(coalesce(nullif(p_hours_display, ''), p_hours))
    );
    v_desc := v_desc - 'hours_periods';
  end if;

  update public.restaurants
  set image_url = coalesce(v_next_image_url, image_url),
      description = v_desc::text
  where id = p_restaurant_id;
end;
$$;

revoke all on function public.owner_update_restaurant(uuid, text, text, text[], jsonb, text, text, text) from public;
grant execute on function public.owner_update_restaurant(uuid, text, text, text[], jsonb, text, text, text) to authenticated;

select 'owner_update_restaurant ok' as status;
