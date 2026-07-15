-- ── 스탬프북 사이클(쿠폰 발급마다 리셋) 기준 리퍼럴 히스토리 ──
-- 실행 순서: referral_program.sql 이후

alter table public.user_rewards add column if not exists cycle_started_at timestamptz not null default now();

-- 기프티콘 자동 배정(20개 도달) 시 다음 사이클 시작 시점 갱신
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
  set total_stamps     = v_new_total,
      today_stamps     = v_today_stamps,
      last_stamp_date  = v_today,
      cycle_started_at = now()
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

-- 수동 교환(redeem_gifticon)도 동일하게 갱신
create or replace function public.redeem_gifticon()
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid      uuid := auth.uid();
  v_reward   public.user_rewards;
  v_today    date := (now() at time zone 'Asia/Seoul')::date;
  v_today_stamps int;
  v_gift     public.gifticons;
begin
  if v_uid is null then
    raise exception '로그인이 필요해요.';
  end if;

  select * into v_reward
  from public.user_rewards
  where user_id = v_uid
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

  update public.user_rewards
  set total_stamps     = total_stamps - 20,
      today_stamps     = v_today_stamps,
      last_stamp_date  = v_today,
      cycle_started_at = now()
  where user_id = v_uid;

  update public.gifticons
  set status           = 'assigned',
      assigned_user_id = v_uid,
      assigned_at      = now()
  where id = v_gift.id;

  return jsonb_build_object(
    'status',       'ok',
    'gifticon_id',  v_gift.id,
    'brand',        v_gift.brand,
    'product_name', v_gift.product_name,
    'image_url',    v_gift.image_url,
    'expires_at',   v_gift.expires_at
  );
end;
$$;

grant execute on function public.redeem_gifticon() to authenticated;

-- 스탬프북(현재 사이클) 카드용: 이번 사이클 시작 이후 발생한 것만 count
-- 친구초대 페이지(누적)용: 전체 count
drop function if exists public.get_my_referral_history();
create or replace function public.get_my_referral_history()
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_cycle_started_at timestamptz;
begin
  if v_uid is null then
    raise exception '로그인이 필요해요.';
  end if;

  select cycle_started_at into v_cycle_started_at
  from public.user_rewards
  where user_id = v_uid;

  return jsonb_build_object(
    'my_referral_code', (select referral_code from public.users where id = v_uid),
    'events', (
      select coalesce(jsonb_agg(jsonb_build_object(
        'id', r.id,
        'created_at', r.created_at,
        'role', case when r.referrer_user_id = v_uid then 'referrer' else 'referred' end,
        'in_current_cycle', r.created_at >= coalesce(v_cycle_started_at, '-infinity'::timestamptz)
      ) order by r.created_at desc), '[]'::jsonb)
      from public.referrals r
      where r.referrer_user_id = v_uid or r.referred_user_id = v_uid
    )
  );
end;
$$;

grant execute on function public.get_my_referral_history() to authenticated;

comment on column public.user_rewards.cycle_started_at is '현재 스탬프북 사이클 시작 시각. 20개 채워 쿠폰 발급될 때마다 now()로 갱신됨.';
