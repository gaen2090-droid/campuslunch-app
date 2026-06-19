-- 일일 스탬프 상한 3개 복구 (Supabase SQL Editor에서 실행)
-- rewards_v2가 이미 배포된 경우: 아래 grant_stamp만 실행하면 됩니다.

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

  if v_total_stamps >= 20 then
    v_auto_redeem := public._perform_gifticon_redeem(p_user_id);
    if (v_auto_redeem ->> 'status') = 'ok' then
      v_total_stamps := coalesce((v_auto_redeem ->> 'total_stamps')::int, 0);
    end if;
  else
    v_daily_room := 3 - v_today_stamps;
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
