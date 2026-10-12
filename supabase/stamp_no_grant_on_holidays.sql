-- 공휴일에는 스탬프를 지급하지 않는다 (주말과 동일) — Dashboard → SQL Editor → Run
--
-- 1) 공휴일 목록 테이블(public.korean_public_holidays)을 만들고 2026~2027년을 채운다.
--    매년 다음 해 공휴일을 이 테이블에 insert 해야 한다. (앱 쪽 목록은
--    lib/utils/korean_holidays.dart — 두 곳을 같이 갱신할 것)
-- 2) grant_stamp 를 공휴일(KST 기준 오늘)이면 지급 없이 반환하도록 다시 정의한다.
--    * 이 파일이 grant_stamp 의 최신 버전이다. 이후 수정은 이 파일 기준으로 할 것.
--      (stamp_hours_weekday_11_to_19.sql / giftishow_issue.sql 은 이전 버전)
--    * 응답: reason='out_of_hours' + is_holiday=true.
--      이전 앱은 out_of_hours 문구("지금은 스탬프 제공 시간이 아니에요")로 안내하고,
--      새 앱은 is_holiday 로 "공휴일에는 스탬프를 제공하지 않아요"를 보여준다.

create table if not exists public.korean_public_holidays (
  day  date primary key,
  name text not null default ''
);

alter table public.korean_public_holidays enable row level security;
-- 정책 없음: 앱/클라이언트는 직접 읽지 않고, security definer 함수만 조회한다.

insert into public.korean_public_holidays (day, name) values
  ('2026-01-01', '신정'),
  ('2026-02-16', '설날 연휴'), ('2026-02-17', '설날'), ('2026-02-18', '설날 연휴'),
  ('2026-03-01', '삼일절'), ('2026-03-02', '삼일절 대체공휴일'),
  ('2026-05-05', '어린이날'),
  ('2026-05-24', '부처님오신날'), ('2026-05-25', '부처님오신날 대체공휴일'),
  ('2026-06-03', '전국동시지방선거'),
  ('2026-08-15', '광복절'), ('2026-08-17', '광복절 대체공휴일'),
  ('2026-09-24', '추석 연휴'), ('2026-09-25', '추석'), ('2026-09-26', '추석 연휴'),
  ('2026-10-03', '개천절'), ('2026-10-05', '개천절 대체공휴일'),
  ('2026-10-09', '한글날'),
  ('2026-12-25', '성탄절'),
  ('2027-01-01', '신정'),
  ('2027-02-06', '설날 연휴'), ('2027-02-07', '설날'), ('2027-02-08', '설날 연휴'),
  ('2027-02-09', '설날 대체공휴일'),
  ('2027-03-01', '삼일절'),
  ('2027-05-05', '어린이날'),
  ('2027-05-13', '부처님오신날'),
  ('2027-08-15', '광복절'), ('2027-08-16', '광복절 대체공휴일'),
  ('2027-09-14', '추석 연휴'), ('2027-09-15', '추석'), ('2027-09-16', '추석 연휴'),
  ('2027-10-03', '개천절'), ('2027-10-04', '개천절 대체공휴일'),
  ('2027-10-09', '한글날'), ('2027-10-11', '한글날 대체공휴일'),
  ('2027-12-25', '성탄절'), ('2027-12-27', '성탄절 대체공휴일')
on conflict (day) do nothing;

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

  -- 공휴일(대체공휴일 포함)은 주말처럼 지급하지 않는다. 제보 자체는 영향 없음.
  if exists (select 1 from public.korean_public_holidays h where h.day = v_today) then
    return jsonb_build_object(
      'granted', false,
      'granted_count', 0,
      'today_stamps', v_today_stamps,
      'total_stamps', v_total_stamps,
      'auto_redeem', v_auto_redeem,
      'reason', 'out_of_hours',
      'is_holiday', true
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

revoke all on function public.grant_stamp(uuid, int) from public;
revoke all on function public.grant_stamp(uuid, int) from anon;
revoke all on function public.grant_stamp(uuid, int) from authenticated;

select 'stamp_no_grant_on_holidays.sql ok' as status;
