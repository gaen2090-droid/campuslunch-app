-- 기프티콘 액면가(원) + 어드민 리워드 지출 집계
-- Dashboard → SQL Editor 에서 실행

alter table public.gifticons
  add column if not exists face_value integer;

comment on column public.gifticons.face_value is
  '기프티콘 액면가(원). 리워드 지출 지표·엑셀 내보내기에 사용.';

-- 구 시그니처 제거 후 face_value 포함 재생성
drop function if exists public.admin_register_gifticon(text, text, text, date);

create or replace function public.admin_register_gifticon(
  p_brand        text,
  p_product_name text,
  p_image_url    text,
  p_expires_at   date default null,
  p_face_value   integer default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_id  uuid;
begin
  if not exists (
    select 1 from public.users u
    where u.id = v_uid and u.role = 'admin'
  ) then
    raise exception '관리자만 기프티콘을 등록할 수 있어요.';
  end if;

  if p_face_value is not null and p_face_value < 0 then
    raise exception 'face_value는 0 이상이어야 해요.';
  end if;

  insert into public.gifticons (
    brand, product_name, image_url, expires_at, face_value
  ) values (
    p_brand, p_product_name, p_image_url, p_expires_at, p_face_value
  )
  returning id into v_id;

  return jsonb_build_object('id', v_id);
end;
$$;

grant execute on function public.admin_register_gifticon(text, text, text, date, integer)
  to authenticated;

-- 일괄 등록: face_value 선택 (CSV 컬럼 face_value)
create or replace function public.admin_bulk_register_gifticons(p_rows jsonb)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_item jsonb;
  v_count int := 0;
  v_expires date;
  v_face integer;
begin
  if not exists (
    select 1 from public.users u
    where u.id = v_uid and u.role = 'admin'
  ) then
    raise exception '관리자만 기프티콘을 등록할 수 있어요.';
  end if;

  if p_rows is null or jsonb_typeof(p_rows) <> 'array' then
    raise exception 'INVALID_ROWS';
  end if;

  for v_item in select * from jsonb_array_elements(p_rows)
  loop
    if coalesce(trim(v_item ->> 'brand'), '') = ''
       or coalesce(trim(v_item ->> 'product_name'), '') = ''
       or coalesce(trim(v_item ->> 'image_url'), '') = '' then
      continue;
    end if;

    v_expires := null;
    if coalesce(trim(v_item ->> 'expires_at'), '') <> '' then
      v_expires := (v_item ->> 'expires_at')::date;
    end if;

    v_face := null;
    if coalesce(trim(v_item ->> 'face_value'), '') <> '' then
      v_face := (v_item ->> 'face_value')::integer;
      if v_face < 0 then
        raise exception 'face_value는 0 이상이어야 해요.';
      end if;
    end if;

    insert into public.gifticons (
      brand,
      product_name,
      image_url,
      expires_at,
      coupon_code,
      face_value
    ) values (
      trim(v_item ->> 'brand'),
      trim(v_item ->> 'product_name'),
      trim(v_item ->> 'image_url'),
      v_expires,
      nullif(trim(coalesce(v_item ->> 'coupon_code', '')), ''),
      v_face
    );

    v_count := v_count + 1;
  end loop;

  return jsonb_build_object('inserted', v_count);
end;
$$;

grant execute on function public.admin_bulk_register_gifticons(jsonb) to authenticated;

-- 유저별 리워드 수령·액수 원본 (엑셀에서 face_value 없으면 상품명에서 원 단위 파싱)
create or replace function public.admin_reward_spend_report()
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_gifts jsonb;
begin
  if not exists (
    select 1 from public.users u
    where u.id = v_uid and u.role = 'admin'
  ) then
    raise exception '관리자만 조회할 수 있어요.';
  end if;

  select coalesce(jsonb_agg(row_to_json(t) order by t.assigned_at desc nulls last), '[]'::jsonb)
  into v_gifts
  from (
    select
      g.id,
      g.assigned_user_id as user_id,
      coalesce(u.nickname, '') as nickname,
      coalesce(u.email, '') as email,
      g.brand,
      g.product_name,
      g.face_value,
      g.status,
      g.assigned_at
    from public.gifticons g
    left join public.users u on u.id = g.assigned_user_id
    where g.assigned_at is not null
  ) t;

  return jsonb_build_object(
    'gifts', v_gifts,
    'note', 'face_value 우선. 없으면 product_name의 N원 패턴으로 추정.'
  );
end;
$$;

grant execute on function public.admin_reward_spend_report() to authenticated;

comment on function public.admin_reward_spend_report() is
  '어드민 리워드 지출 원본: 배정된 기프티콘 + 유저 식별 정보';
