-- 기프티콘 리워드 v2: 자동 지급, 원자적 교환, used 상태, CSV 일괄 등록
-- Dashboard → SQL Editor (rewards.sql 이후)
--
-- ⚠️ 실행 순서 (Supabase는 한 번에 실행하면 enum 오류 55P04 발생)
--   1) rewards_v2_step1_enum.sql  ← 먼저 이것만 실행
--   2) rewards_v2_gifticon_flow.sql  ← 성공 후 실행
--
-- ⚠️⚠️ 주의: _perform_gifticon_redeem / grant_stamp 함수는 이제 rewards.sql에
-- 정식으로 통합되었습니다 (둘이 같은 함수를 다르게 정의해 충돌하던 버그 수정).
-- 이 파일을 다시 실행하면 rewards.sql의 grant_stamp(자동 기프티콘 배정 포함)가
-- 다시 덮어써져 버그가 재발하니, 아래 _perform_gifticon_redeem / grant_stamp
-- 블록은 재실행하지 말 것. redeem_gifticon / mark_gifticon_used /
-- admin_bulk_register_gifticons 등 나머지 함수만 필요시 재실행하면 됩니다.

-- 1) 쿠폰 코드(선택) — CSV 업로드용
alter table public.gifticons
  add column if not exists coupon_code text;

create index if not exists gifticons_status_created_idx
  on public.gifticons (status, created_at)
  where status = 'unassigned';

-- 3) 원자적 교환 코어 (포인트 차감 + 기프티콘 배정, 실패 시 전체 롤백)
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
begin
  select * into v_reward
  from public.user_rewards
  where user_id = p_user_id
  for update;

  if not found then
    return jsonb_build_object('status', 'not_enough');
  end if;

  if v_reward.total_stamps < 20 then
    return jsonb_build_object('status', 'not_enough');
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

  if v_reward.last_stamp_date is distinct from v_today then
    v_today_stamps := 0;
  else
    v_today_stamps := v_reward.today_stamps;
  end if;

  v_new_total := v_reward.total_stamps - 20;

  update public.user_rewards
  set total_stamps    = v_new_total,
      today_stamps    = v_today_stamps,
      last_stamp_date = v_today
  where user_id = p_user_id;

  update public.gifticons
  set status           = 'assigned',
      assigned_user_id = p_user_id,
      assigned_at      = now()
  where id = v_gift.id;

  return jsonb_build_object(
    'status',       'ok',
    'gifticon_id',  v_gift.id,
    'brand',        v_gift.brand,
    'product_name', v_gift.product_name,
    'image_url',    v_gift.image_url,
    'expires_at',   v_gift.expires_at,
    'coupon_code',  v_gift.coupon_code,
    'total_stamps', v_new_total
  );
end;
$$;

-- 4) 스탬프 지급 — 누적 20 상한, 20 달성 시 자동 기프티콘 지급, 초과분 이월
-- 예: 19개 + 2스탬프 제보 → 20에서 자동 지급 후 1/20 이월
create or replace function public.grant_stamp(p_user_id uuid, p_count int default 1)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_today        date := (now() at time zone 'Asia/Seoul')::date;
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

  -- 이미 20개: 추가 적립 없이 자동 지급만 재시도 (재고 들어온 경우)
  if v_total_stamps >= 20 then
    v_auto_redeem := public._perform_gifticon_redeem(p_user_id);
    if (v_auto_redeem ->> 'status') = 'ok' then
      v_total_stamps := coalesce((v_auto_redeem ->> 'total_stamps')::int, 0);
    end if;
  else
    v_daily_room := 999 - v_today_stamps;
    v_intended := least(p_count, v_daily_room);

    if v_intended > 0 then
      v_to_add := least(v_intended, 20 - v_total_stamps);
      v_overflow := v_intended - v_to_add;

      v_today_stamps := v_today_stamps + v_intended;
      v_total_stamps := v_total_stamps + v_to_add;
      v_granted := v_intended;

      update public.user_rewards
      set today_stamps    = v_today_stamps,
          total_stamps    = v_total_stamps,
          last_stamp_date = v_today
      where user_id = p_user_id;

      if v_total_stamps >= 20 then
        v_auto_redeem := public._perform_gifticon_redeem(p_user_id);
        if (v_auto_redeem ->> 'status') = 'ok' then
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
    'granted',       v_granted > 0,
    'granted_count', v_granted,
    'today_stamps',  v_today_stamps,
    'total_stamps',  v_total_stamps,
    'auto_redeem',   v_auto_redeem
  );
end;
$$;

-- 5) 수동 쿠폰 신청 (동일 원자적 코어 사용)
create or replace function public.redeem_gifticon()
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_result jsonb;
begin
  if v_uid is null then
    raise exception '로그인이 필요해요.';
  end if;

  v_result := public._perform_gifticon_redeem(v_uid);
  return v_result;
end;
$$;

-- 6) 사용 완료 처리 (assigned → used)
create or replace function public.mark_gifticon_used(p_gifticon_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_row public.gifticons;
begin
  if v_uid is null then
    raise exception '로그인이 필요해요.';
  end if;

  select * into v_row
  from public.gifticons
  where id = p_gifticon_id
    and assigned_user_id = v_uid
    and status = 'assigned'
  for update;

  if not found then
    return jsonb_build_object('status', 'not_found');
  end if;

  update public.gifticons
  set status = 'used'
  where id = p_gifticon_id;

  return jsonb_build_object('status', 'ok');
end;
$$;

-- 7) 어드민 CSV 일괄 등록
-- rows: [{brand, product_name, image_url, expires_at?, coupon_code?}, ...]
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

    insert into public.gifticons (
      brand,
      product_name,
      image_url,
      expires_at,
      coupon_code
    ) values (
      trim(v_item ->> 'brand'),
      trim(v_item ->> 'product_name'),
      trim(v_item ->> 'image_url'),
      v_expires,
      nullif(trim(coalesce(v_item ->> 'coupon_code', '')), '')
    );

    v_count := v_count + 1;
  end loop;

  return jsonb_build_object('inserted', v_count);
end;
$$;

grant execute on function public.mark_gifticon_used(uuid) to authenticated;
grant execute on function public.admin_bulk_register_gifticons(jsonb) to authenticated;

comment on function public._perform_gifticon_redeem(uuid) is
  '스탬프 20개 차감 + 미배정 기프티콘 1건 배정. 단일 트랜잭션 — 실패 시 롤백.';
comment on function public.admin_bulk_register_gifticons(jsonb) is
  'CSV 파싱 결과 JSON 배열로 기프티콘 일괄 등록.';

-- Storage: 사용 완료(used) 쿠폰도 이미지 조회 가능
drop policy if exists "gifticons_storage_select_own" on storage.objects;
create policy "gifticons_storage_select_own" on storage.objects
  for select using (
    bucket_id = 'gifticons'
    and (
      exists (
        select 1 from public.users u
        where u.id = auth.uid() and u.role = 'admin'
      )
      or exists (
        select 1 from public.gifticons g
        where g.image_url = (bucket_id || '/' || name)
          and g.assigned_user_id = auth.uid()
          and g.status in ('assigned', 'used')
      )
    )
  );
