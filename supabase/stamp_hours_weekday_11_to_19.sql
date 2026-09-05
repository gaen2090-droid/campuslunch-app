-- 스탬프 지급 조건 변경 (Dashboard → SQL Editor → Run)
--   1) 지급 시간대: KST 10:00~19:00 -> 11:00~19:00
--   2) 주말(토·일)에는 시간대와 무관하게 스탬프 미지급
--
-- 그 밖의 시간/요일에도 제보(submit_crowd_report) 자체는 그대로 가능하지만,
-- grant_stamp 안에서 주말이거나 KST 현재 시각이 11:00~19:00(19:00 정각 포함,
-- 19:00 이후 제외) 범위를 벗어나면 스탬프를 지급하지 않고 granted=false를 반환한다.
-- reason은 주말이면 'weekend', 평일 시간대 밖이면 'out_of_hours'.
--
-- 참고: grant_stamp의 이전 버전은 stamp_hours_10_to_19.sql 이었으나, 이 파일이 이후
-- 최신 버전이므로 grant_stamp를 다시 수정할 때는 반드시 이 파일을 갱신해서 실행할 것.

create or replace function public.grant_stamp(p_user_id uuid, p_count int default 1)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_today        date := (now() at time zone 'Asia/Seoul')::date;
  v_kst_time     time := (now() at time zone 'Asia/Seoul')::time;
  v_kst_dow      int  := extract(isodow from (now() at time zone 'Asia/Seoul'))::int; -- 1=월 .. 7=일
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

  -- 주말(토=6, 일=7)에는 시간대와 무관하게 지급 없이 반환. 제보 자체는 영향 없음.
  if v_kst_dow in (6, 7) then
    return jsonb_build_object(
      'granted',       false,
      'granted_count', 0,
      'today_stamps',  v_today_stamps,
      'total_stamps',  v_total_stamps,
      'auto_redeem',   v_auto_redeem,
      'reason',        'weekend'
    );
  end if;

  -- 스탬프 지급 시간대(KST 11:00~19:00) 밖이면 지급 없이 반환. 제보 자체는 영향 없음.
  if v_kst_time < time '11:00' or v_kst_time >= time '19:00' then
    return jsonb_build_object(
      'granted',       false,
      'granted_count', 0,
      'today_stamps',  v_today_stamps,
      'total_stamps',  v_total_stamps,
      'auto_redeem',   v_auto_redeem,
      'reason',        'out_of_hours'
    );
  end if;

  if v_total_stamps >= 20 then
    v_auto_redeem := public._perform_gifticon_redeem(p_user_id);
    if (v_auto_redeem ->> 'status') = 'ok' then
      v_total_stamps := coalesce((v_auto_redeem ->> 'total_stamps')::int, 0);
    end if;
  else
    -- 출시: 하루 최대 3개
    v_daily_room := 3 - v_today_stamps;
    v_intended := least(p_count, greatest(v_daily_room, 0));

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

revoke all on function public.grant_stamp(uuid, int) from public;
revoke all on function public.grant_stamp(uuid, int) from anon;
revoke all on function public.grant_stamp(uuid, int) from authenticated;

select 'stamp_hours_weekday_11_to_19.sql ok' as status;
