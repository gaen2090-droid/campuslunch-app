-- 스탬프 지급 시간대를 KST 10:00~19:00으로 제한 (Dashboard → SQL Editor → Run)
--
-- 그 밖의 시간대에도 제보(submit_crowd_report) 자체는 그대로 가능하지만,
-- grant_stamp 안에서 KST 현재 시각이 10:00~19:00(19:00 정각 포함, 19:00 이후 제외)
-- 범위를 벗어나면 스탬프를 지급하지 않고 granted=false, reason='out_of_hours'를 반환한다.
--
-- 참고: grant_stamp의 최신 정의는 rewards_daily_cap_to_3.sql / deploy_prelaunch_security.sql
-- 에 있었으나, 이 파일이 이후 최신 버전이므로 grant_stamp를 다시 수정할 때는
-- 반드시 이 파일을 갱신해서 실행할 것.

create or replace function public.grant_stamp(p_user_id uuid, p_count int default 1)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_today        date := (now() at time zone 'Asia/Seoul')::date;
  v_kst_time     time := (now() at time zone 'Asia/Seoul')::time;
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

  -- 스탬프 지급 시간대(KST 10:00~19:00) 밖이면 지급 없이 반환. 제보 자체는 영향 없음.
  if v_kst_time < time '10:00' or v_kst_time >= time '19:00' then
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
grant execute on function public.grant_stamp(uuid, int) to authenticated;

select 'stamp_hours_10_to_19.sql ok' as status;
