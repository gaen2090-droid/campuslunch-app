-- 기프티쇼 비즈 교환 발급 (스탬프 20개 → 상품 1종)
-- Dashboard → SQL Editor → Run
--
-- 상품 코드·표시 정보는 giftishow_reward_product 한 행이 정본.
-- 인증키는 DB에 두지 않는다. Edge Function issue-giftishow 시크릿:
--   GIFTISHOW_AUTH_CODE, GIFTISHOW_AUTH_TOKEN, GIFTISHOW_USER_ID, GIFTISHOW_CALLBACK_NO
-- 키·계약 전에는 is_enabled=false 로 두고 기존 unassigned 재고를 사용한다.
-- is_enabled=true 인데 키가 없으면 발급 함수가 스탬프 20개를 되돌린다.
-- gifticon_status 에 새 값을 추가하지 않는다. 핀이 확정된 뒤에만 gifticons 행을 만든다.

alter table public.gifticons
  add column if not exists face_value integer;

create table if not exists public.giftishow_reward_product (
  id boolean primary key default true check (id),
  goods_code text not null default '',
  brand text not null default '',
  product_name text not null default '',
  face_value integer,
  image_url text not null default '',
  is_enabled boolean not null default false,
  updated_at timestamptz not null default now()
);

insert into public.giftishow_reward_product (id)
values (true)
on conflict (id) do nothing;

comment on table public.giftishow_reward_product is
  '스탬프 교환 기프티쇼 상품 1종. is_enabled 이고 goods_code 가 있을 때만 API 발급.';

create table if not exists public.giftishow_issuances (
  id uuid primary key default gen_random_uuid(),
  tr_id text not null unique,
  user_id uuid not null references public.users (id) on delete cascade,
  gifticon_id uuid references public.gifticons (id) on delete set null,
  goods_code text not null,
  status text not null default 'pending',
  order_no text,
  error_message text,
  cycle_started_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint giftishow_issuances_status_chk
    check (status in ('pending', 'sending', 'issued', 'failed'))
);

create index if not exists giftishow_issuances_user_status_idx
  on public.giftishow_issuances (user_id, status, created_at desc);

alter table public.giftishow_reward_product enable row level security;
alter table public.giftishow_issuances enable row level security;

drop policy if exists "giftishow_product_admin_all" on public.giftishow_reward_product;
create policy "giftishow_product_admin_all"
  on public.giftishow_reward_product
  for all to authenticated
  using (public.is_admin())
  with check (public.is_admin());

-- issuances: 클라이언트 직접 조회 없음. RPC/service role 만.

create or replace function public.admin_get_giftishow_product()
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_row public.giftishow_reward_product;
begin
  if not public.is_admin() then
    raise exception '관리자만 볼 수 있어요.';
  end if;
  select * into v_row from public.giftishow_reward_product where id = true;
  return jsonb_build_object(
    'goods_code', v_row.goods_code,
    'brand', v_row.brand,
    'product_name', v_row.product_name,
    'face_value', v_row.face_value,
    'image_url', v_row.image_url,
    'is_enabled', v_row.is_enabled
  );
end;
$$;

create or replace function public.admin_set_giftishow_product(
  p_goods_code text,
  p_brand text,
  p_product_name text,
  p_face_value integer,
  p_image_url text,
  p_is_enabled boolean
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
begin
  if not public.is_admin() then
    raise exception '관리자만 바꿀 수 있어요.';
  end if;
  if p_face_value is not null and p_face_value < 0 then
    raise exception '액면가는 0 이상이어야 해요.';
  end if;
  if coalesce(p_is_enabled, false) and length(trim(coalesce(p_goods_code, ''))) = 0 then
    raise exception '켜려면 기프티쇼 상품코드(goods_code)가 필요해요.';
  end if;

  update public.giftishow_reward_product
  set goods_code = trim(coalesce(p_goods_code, '')),
      brand = trim(coalesce(p_brand, '')),
      product_name = trim(coalesce(p_product_name, '')),
      face_value = p_face_value,
      image_url = trim(coalesce(p_image_url, '')),
      is_enabled = coalesce(p_is_enabled, false),
      updated_at = now()
  where id = true;

  return public.admin_get_giftishow_product();
end;
$$;

revoke all on function public.admin_get_giftishow_product() from public;
revoke all on function public.admin_set_giftishow_product(text, text, text, integer, text, boolean) from public;
grant execute on function public.admin_get_giftishow_product() to authenticated;
grant execute on function public.admin_set_giftishow_product(text, text, text, integer, text, boolean) to authenticated;

-- 발급 확정/실패. service role(Edge)만.
create or replace function public.giftishow_claim_issuance(p_issuance_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_row public.giftishow_issuances;
  v_product public.giftishow_reward_product;
begin
  if auth.role() is distinct from 'service_role' then
    raise exception 'service role only';
  end if;

  update public.giftishow_issuances
  set status = 'sending',
      updated_at = now()
  where id = p_issuance_id
    and status = 'pending'
  returning * into v_row;

  if not found then
    select * into v_row from public.giftishow_issuances where id = p_issuance_id;
    if not found then
      return jsonb_build_object('status', 'missing');
    end if;
    return jsonb_build_object(
      'status', v_row.status,
      'claimed', false,
      'tr_id', v_row.tr_id,
      'goods_code', v_row.goods_code,
      'gifticon_id', v_row.gifticon_id,
      'user_id', v_row.user_id,
      'order_no', v_row.order_no
    );
  end if;

  select * into v_product from public.giftishow_reward_product where id = true;

  return jsonb_build_object(
    'status', 'sending',
    'claimed', true,
    'tr_id', v_row.tr_id,
    'goods_code', v_row.goods_code,
    'gifticon_id', v_row.gifticon_id,
    'user_id', v_row.user_id,
    'brand', v_product.brand,
    'product_name', v_product.product_name,
    'face_value', v_product.face_value,
    'image_url', v_product.image_url
  );
end;
$$;

create or replace function public.giftishow_complete_issuance(
  p_issuance_id uuid,
  p_pin_no text,
  p_order_no text,
  p_coupon_image_url text,
  p_expires_at date
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_row public.giftishow_issuances;
  v_product public.giftishow_reward_product;
  v_image text;
  v_gift_id uuid;
begin
  if auth.role() is distinct from 'service_role' then
    raise exception 'service role only';
  end if;

  select * into v_row
  from public.giftishow_issuances
  where id = p_issuance_id
  for update;

  if not found then
    raise exception '발급 건을 찾을 수 없어요.';
  end if;
  if v_row.status = 'issued' then
    return;
  end if;

  select * into v_product from public.giftishow_reward_product where id = true;
  v_image := nullif(trim(coalesce(p_coupon_image_url, '')), '');
  if v_image is null then
    v_image := nullif(trim(v_product.image_url), '');
  end if;
  if v_image is null then
    v_image := '';
  end if;

  if v_row.gifticon_id is null then
    insert into public.gifticons (
      brand, product_name, image_url, face_value, coupon_code, expires_at,
      status, assigned_user_id
    ) values (
      coalesce(nullif(trim(v_product.brand), ''), '기프티쇼'),
      coalesce(nullif(trim(v_product.product_name), ''), v_row.goods_code),
      v_image,
      v_product.face_value,
      nullif(trim(coalesce(p_pin_no, '')), ''),
      coalesce(p_expires_at, (now() at time zone 'Asia/Seoul')::date + 30),
      'unassigned',
      null
    )
    returning id into v_gift_id;

    update public.giftishow_issuances
    set gifticon_id = v_gift_id
    where id = p_issuance_id;
    v_row.gifticon_id := v_gift_id;
  end if;

  update public.gifticons
  set status = 'assigned',
      coupon_code = nullif(trim(coalesce(p_pin_no, '')), ''),
      image_url = v_image,
      expires_at = coalesce(p_expires_at, (now() at time zone 'Asia/Seoul')::date + 30),
      face_value = coalesce(face_value, v_product.face_value),
      assigned_user_id = v_row.user_id,
      assigned_at = now()
  where id = v_row.gifticon_id;

  update public.giftishow_issuances
  set status = 'issued',
      order_no = nullif(trim(coalesce(p_order_no, '')), ''),
      error_message = null,
      updated_at = now()
  where id = p_issuance_id;
end;
$$;

create or replace function public.giftishow_fail_issuance(
  p_issuance_id uuid,
  p_error text
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_row public.giftishow_issuances;
begin
  if auth.role() is distinct from 'service_role' then
    raise exception 'service role only';
  end if;

  select * into v_row
  from public.giftishow_issuances
  where id = p_issuance_id
  for update;

  if not found or v_row.status in ('issued', 'failed') then
    return;
  end if;

  update public.giftishow_issuances
  set status = 'failed',
      error_message = left(coalesce(p_error, 'failed'), 500),
      updated_at = now()
  where id = p_issuance_id;

  update public.user_rewards
  set total_stamps = total_stamps + 20,
      cycle_started_at = coalesce(v_row.cycle_started_at, cycle_started_at)
  where user_id = v_row.user_id;

  if v_row.gifticon_id is not null then
    delete from public.gifticons
    where id = v_row.gifticon_id
      and status <> 'assigned';
  end if;
end;
$$;

revoke all on function public.giftishow_claim_issuance(uuid) from public, anon, authenticated;
revoke all on function public.giftishow_complete_issuance(uuid, text, text, text, date) from public, anon, authenticated;
revoke all on function public.giftishow_fail_issuance(uuid, text) from public, anon, authenticated;
grant execute on function public.giftishow_claim_issuance(uuid) to service_role;
grant execute on function public.giftishow_complete_issuance(uuid, text, text, text, date) to service_role;
grant execute on function public.giftishow_fail_issuance(uuid, text) to service_role;

create or replace function public.my_pending_giftishow_issuance()
returns uuid
language sql
stable
security definer
set search_path = public
as $$
  select i.id
  from public.giftishow_issuances i
  where i.user_id = auth.uid()
    and i.status in ('pending', 'sending')
  order by i.created_at desc
  limit 1;
$$;

revoke all on function public.my_pending_giftishow_issuance() from public;
grant execute on function public.my_pending_giftishow_issuance() to authenticated;

-- 최신 재고 배정(_perform) + 기프티쇼 분기
create or replace function public._perform_gifticon_redeem(p_user_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_reward   public.user_rewards;
  v_today    date := (now() at time zone 'Asia/Seoul')::date;
  v_today_stamps int;
  v_gift     public.gifticons;
  v_new_total int;
  v_product  public.giftishow_reward_product;
  v_prev_cycle timestamptz;
  v_tr       text;
  v_issue_id uuid;
begin
  select * into v_reward
  from public.user_rewards
  where user_id = p_user_id
  for update;

  if not found or v_reward.total_stamps < 20 then
    return jsonb_build_object('status', 'not_enough');
  end if;

  select * into v_product
  from public.giftishow_reward_product
  where id = true
    and is_enabled = true
    and length(trim(goods_code)) > 0;

  if v_reward.last_stamp_date is distinct from v_today then
    v_today_stamps := 0;
  else
    v_today_stamps := v_reward.today_stamps;
  end if;

  v_new_total := v_reward.total_stamps - 20;
  v_prev_cycle := v_reward.cycle_started_at;

  if found then
    v_tr := 'cl'
      || to_char(now() at time zone 'Asia/Seoul', 'YYMMDDHH24MISS')
      || substr(replace(gen_random_uuid()::text, '-', ''), 1, 8);

    insert into public.giftishow_issuances (
      tr_id, user_id, goods_code, status, cycle_started_at
    ) values (
      v_tr, p_user_id, trim(v_product.goods_code), 'pending', v_prev_cycle
    )
    returning id into v_issue_id;

    update public.user_rewards
    set total_stamps = v_new_total,
        today_stamps = v_today_stamps,
        last_stamp_date = v_today,
        cycle_started_at = now()
    where user_id = p_user_id;

    return jsonb_build_object(
      'status', 'giftishow_pending',
      'issuance_id', v_issue_id,
      'brand', coalesce(nullif(trim(v_product.brand), ''), '기프티쇼'),
      'product_name', coalesce(nullif(trim(v_product.product_name), ''), v_product.goods_code),
      'total_stamps', v_new_total
    );
  end if;

  select * into v_gift
  from public.gifticons
  where status = 'unassigned'
    and (expires_at is null or expires_at >= v_today)
  order by created_at
  limit 1
  for update skip locked;

  if not found then
    return jsonb_build_object('status', 'sold_out');
  end if;

  update public.user_rewards
  set total_stamps = v_new_total,
      today_stamps = v_today_stamps,
      last_stamp_date = v_today,
      cycle_started_at = now()
  where user_id = p_user_id;

  update public.gifticons
  set status = 'assigned',
      assigned_user_id = p_user_id,
      assigned_at = now()
  where id = v_gift.id;

  return jsonb_build_object(
    'status', 'ok',
    'gifticon_id', v_gift.id,
    'brand', v_gift.brand,
    'product_name', v_gift.product_name,
    'image_url', v_gift.image_url,
    'expires_at', v_gift.expires_at,
    'coupon_code', v_gift.coupon_code,
    'total_stamps', v_new_total
  );
end;
$$;

create or replace function public.redeem_gifticon()
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
begin
  if v_uid is null then
    raise exception '로그인이 필요해요.';
  end if;
  return public._perform_gifticon_redeem(v_uid);
end;
$$;

revoke all on function public._perform_gifticon_redeem(uuid) from public, anon, authenticated;
grant execute on function public.redeem_gifticon() to authenticated;

-- grant_stamp: giftishow_pending 도 스탬프 차감 반영
create or replace function public.grant_stamp(p_user_id uuid, p_count int default 1)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_today        date := (now() at time zone 'Asia/Seoul')::date;
  v_kst_time     time := (now() at time zone 'Asia/Seoul')::time;
  v_kst_dow      int  := extract(isodow from (now() at time zone 'Asia/Seoul'))::int;
  v_today_stamps int;
  v_total_stamps int;
  v_granted      int := 0;
  v_row          public.user_rewards;
  v_daily_room   int;
  v_intended     int;
  v_to_add       int;
  v_overflow     int;
  v_auto_redeem  jsonb := jsonb_build_object('status', 'none');
begin
  insert into public.user_rewards (user_id)
  values (p_user_id)
  on conflict (user_id) do nothing;

  select * into v_row
  from public.user_rewards
  where user_id = p_user_id
  for update;

  if v_row.last_stamp_date is distinct from v_today then
    v_today_stamps := 0;
  else
    v_today_stamps := v_row.today_stamps;
  end if;

  v_total_stamps := v_row.total_stamps;

  if v_kst_dow in (6, 7) then
    return jsonb_build_object(
      'granted', false,
      'granted_count', 0,
      'today_stamps', v_today_stamps,
      'total_stamps', v_total_stamps,
      'auto_redeem', v_auto_redeem,
      'reason', 'weekend'
    );
  end if;

  if v_kst_time < time '11:00' or v_kst_time >= time '19:00' then
    return jsonb_build_object(
      'granted', false,
      'granted_count', 0,
      'today_stamps', v_today_stamps,
      'total_stamps', v_total_stamps,
      'auto_redeem', v_auto_redeem,
      'reason', 'out_of_hours'
    );
  end if;

  if v_total_stamps >= 20 then
    v_auto_redeem := public._perform_gifticon_redeem(p_user_id);
    if (v_auto_redeem ->> 'status') in ('ok', 'giftishow_pending') then
      v_total_stamps := coalesce((v_auto_redeem ->> 'total_stamps')::int, 0);
    end if;
  else
    v_daily_room := 3 - v_today_stamps;
    v_intended := least(p_count, greatest(v_daily_room, 0));

    if v_intended > 0 then
      v_to_add := least(v_intended, 20 - v_total_stamps);
      v_overflow := v_intended - v_to_add;

      v_today_stamps := v_today_stamps + v_intended;
      v_total_stamps := v_total_stamps + v_to_add;
      v_granted := v_intended;

      update public.user_rewards
      set today_stamps = v_today_stamps,
          total_stamps = v_total_stamps,
          last_stamp_date = v_today
      where user_id = p_user_id;

      if v_total_stamps >= 20 then
        v_auto_redeem := public._perform_gifticon_redeem(p_user_id);
        if (v_auto_redeem ->> 'status') in ('ok', 'giftishow_pending') then
          v_total_stamps :=
            coalesce((v_auto_redeem ->> 'total_stamps')::int, 0) + v_overflow;

          update public.user_rewards
          set total_stamps = v_total_stamps
          where user_id = p_user_id;

          v_auto_redeem := v_auto_redeem
            || jsonb_build_object('total_stamps', v_total_stamps);
        end if;
      end if;
    end if;
  end if;

  return jsonb_build_object(
    'granted', v_granted > 0,
    'granted_count', v_granted,
    'today_stamps', v_today_stamps,
    'total_stamps', v_total_stamps,
    'auto_redeem', v_auto_redeem
  );
end;
$$;

revoke all on function public.grant_stamp(uuid, int) from public, anon, authenticated;

create or replace function public.grant_referral_stamp(p_user_id uuid, p_count int default 3)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_total_stamps int;
  v_redeem jsonb;
begin
  insert into public.user_rewards (user_id)
  values (p_user_id)
  on conflict (user_id) do nothing;

  update public.user_rewards
  set total_stamps = total_stamps + p_count
  where user_id = p_user_id
  returning total_stamps into v_total_stamps;

  while v_total_stamps >= 20 loop
    v_redeem := public._perform_gifticon_redeem(p_user_id);
    if (v_redeem ->> 'status') not in ('ok', 'giftishow_pending') then
      exit;
    end if;
    v_total_stamps := (v_redeem ->> 'total_stamps')::int;
    -- 기프티쇼 발급은 앱/Edge가 한 건씩 마무리한다. 연속 발급은 다음 진입에서 잇는다.
    if (v_redeem ->> 'status') = 'giftishow_pending' then
      exit;
    end if;
  end loop;

  return jsonb_build_object(
    'granted_count', p_count,
    'total_stamps', v_total_stamps,
    'auto_redeem', coalesce(v_redeem, jsonb_build_object('status', 'none'))
  );
end;
$$;

revoke all on function public.grant_referral_stamp(uuid, int) from public, anon, authenticated;
