-- ── 리워드/스탬프/기프티콘 스키마 ──
-- 실행 순서: schema.sql 목록에서 13번으로 추가
-- 의존: users_auth.sql (public.users)

-- 1. 기프티콘 상태 enum
do $$ begin
  if not exists (select 1 from pg_type where typname = 'gifticon_status') then
    create type public.gifticon_status as enum ('unassigned', 'assigned', 'expired');
  end if;
end $$;

-- 2. 기프티콘 테이블
create table if not exists public.gifticons (
  id             uuid primary key default gen_random_uuid(),
  brand          text not null,
  product_name   text not null,
  image_url      text not null,
  expires_at     date,
  status         public.gifticon_status not null default 'unassigned',
  assigned_user_id uuid references public.users(id) on delete set null,
  assigned_at    timestamptz,
  created_at     timestamptz not null default now(),
  updated_at     timestamptz not null default now()
);

-- 3. 유저 리워드 테이블 (public.users 와 1:1)
create table if not exists public.user_rewards (
  user_id            uuid primary key references public.users(id) on delete cascade,
  total_stamps       int not null default 0,
  today_stamps       int not null default 0,
  last_stamp_date    date,           -- KST 날짜 (일일 초기화 기준)
  created_at         timestamptz not null default now(),
  updated_at         timestamptz not null default now()
);

-- 4. 업데이트 트리거 (updated_at 자동 갱신)
create or replace function public.set_updated_at()
returns trigger language plpgsql as $$
begin
  new.updated_at := now();
  return new;
end;
$$;

drop trigger if exists trg_gifticons_updated_at on public.gifticons;
create trigger trg_gifticons_updated_at
  before update on public.gifticons
  for each row execute function public.set_updated_at();

drop trigger if exists trg_user_rewards_updated_at on public.user_rewards;
create trigger trg_user_rewards_updated_at
  before update on public.user_rewards
  for each row execute function public.set_updated_at();

-- 5. RLS 설정
alter table public.gifticons enable row level security;
alter table public.user_rewards enable row level security;

-- gifticons RLS:
--   - 인증 유저: 자기에게 배정된 것만 SELECT (이미지 URL 포함)
--   - admin: 전체 SELECT / INSERT / UPDATE
drop policy if exists "gifticons_select_own" on public.gifticons;
create policy "gifticons_select_own" on public.gifticons
  for select using (
    assigned_user_id = auth.uid()
    or exists (
      select 1 from public.users u
      where u.id = auth.uid() and u.role = 'admin'
    )
  );

drop policy if exists "gifticons_admin_all" on public.gifticons;
create policy "gifticons_admin_all" on public.gifticons
  for all using (
    exists (
      select 1 from public.users u
      where u.id = auth.uid() and u.role = 'admin'
    )
  );

-- user_rewards RLS:
--   - 인증 유저: 자기 행만 SELECT/UPDATE
--   - admin: 전체 SELECT
drop policy if exists "user_rewards_select_own" on public.user_rewards;
create policy "user_rewards_select_own" on public.user_rewards
  for select using (
    user_id = auth.uid()
    or exists (
      select 1 from public.users u
      where u.id = auth.uid() and u.role = 'admin'
    )
  );

drop policy if exists "user_rewards_update_own" on public.user_rewards;
create policy "user_rewards_update_own" on public.user_rewards
  for update using (user_id = auth.uid());

drop policy if exists "user_rewards_insert_own" on public.user_rewards;
create policy "user_rewards_insert_own" on public.user_rewards
  for insert with check (user_id = auth.uid());

-- 6. 스탬프 지급 함수 (submit_crowd_report trigger에서 호출)
--    source='user' 제보 성공 시 호출됨
--    KST 기준 하루 최대 999개 (테스트용, 출시 전 3으로 복구)
create or replace function public.grant_stamp(p_user_id uuid, p_count int default 1)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_today      date := (now() at time zone 'Asia/Seoul')::date;
  v_today_stamps int;
  v_total_stamps int;
  v_granted    int := 0;
  v_row        public.user_rewards;
  v_room       int;
begin
  -- upsert 후 잠금
  insert into public.user_rewards (user_id)
  values (p_user_id)
  on conflict (user_id) do nothing;

  select * into v_row
  from public.user_rewards
  where user_id = p_user_id
  for update;

  -- KST 날짜 기준 일일 초기화
  if v_row.last_stamp_date is distinct from v_today then
    v_today_stamps := 0;
  else
    v_today_stamps := v_row.today_stamps;
  end if;

  v_total_stamps := v_row.total_stamps;

  v_room := 999 - v_today_stamps;
  if v_room > 0 then
    v_granted := least(p_count, v_room);
    v_today_stamps := v_today_stamps + v_granted;
    v_total_stamps := v_total_stamps + v_granted;

    update public.user_rewards
    set today_stamps    = v_today_stamps,
        total_stamps    = v_total_stamps,
        last_stamp_date = v_today
    where user_id = p_user_id;
  end if;

  return jsonb_build_object(
    'granted',       v_granted > 0,
    'granted_count', v_granted,
    'today_stamps',  v_today_stamps,
    'total_stamps',  v_total_stamps
  );
end;
$$;

-- 7. submit_crowd_report를 returns jsonb로 변경 (스탬프 결과 포함)
create or replace function public.submit_crowd_report(
  p_restaurant_id uuid,
  p_status        text,
  p_source        text default 'user',
  p_lat           double precision default null,
  p_lng           double precision default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid        uuid := auth.uid();
  v_level      public.crowd_level;
  v_source     public.crowd_source;
  v_ui_level   int;
  v_stamp_result jsonb;
  v_description jsonb;
  v_session_start timestamptz;
  v_had_report_this_session boolean;
  v_stamp_count int;
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

  v_level  := public.ui_level_to_crowd_level(v_ui_level);
  v_source := public.text_to_crowd_source(p_source);

  if p_source = 'owner' then
    if not exists (
      select 1 from public.restaurants r
      where r.id = p_restaurant_id
        and r.is_active = true
        and r.owner_id = v_uid
    ) then
      raise exception '본인 매장만 변경할 수 있어요.';
    end if;
  end if;

  -- 위치/쿨다운 제한은 클라이언트(앱)에서 검사한다. (디버그 빌드는 우회)

  -- 영업 시작(이번 세션) 이후 기존 제보가 있었는지 확인 (최초 제보 보너스 판단)
  if p_source = 'user' then
    select r.description into v_description
    from public.restaurants r
    where r.id = p_restaurant_id;

    v_session_start := public.restaurant_current_session_start(v_description, now());

    select exists (
      select 1 from public.crowd_reports cr
      where cr.restaurant_id = p_restaurant_id
        and cr.created_at >= coalesce(v_session_start, '-infinity'::timestamptz)
    ) into v_had_report_this_session;
  end if;

  insert into public.crowd_reports (
    restaurant_id, level, source, user_id, metadata
  ) values (
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

  -- 사용자 제보에만 스탬프 지급. 영업 시작 후 최초 제보면 2개, 그 외엔 1개.
  if p_source = 'user' then
    v_stamp_count := case when v_had_report_this_session then 1 else 2 end;
    v_stamp_result := public.grant_stamp(v_uid, v_stamp_count);
  else
    v_stamp_result := jsonb_build_object(
      'granted', false,
      'today_stamps', 0,
      'total_stamps', 0
    );
  end if;

  return v_stamp_result;
end;
$$;

grant execute on function public.submit_crowd_report(uuid, text, text, double precision, double precision)
  to authenticated;
grant execute on function public.grant_stamp(uuid, int) to authenticated;
drop function if exists public.grant_stamp(uuid);

-- 8. 쿠폰 교환 RPC (atomic, FOR UPDATE SKIP LOCKED)
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

  -- 리워드 행 잠금
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

  -- 미배정 기프티콘 잠금 (SKIP LOCKED = 동시 요청에 중복 배정 방지)
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

  -- 스탬프 20개 차감
  -- KST 날짜 기준 today_stamps 계산
  if v_reward.last_stamp_date is distinct from v_today then
    v_today_stamps := 0;
  else
    v_today_stamps := v_reward.today_stamps;
  end if;

  update public.user_rewards
  set total_stamps    = total_stamps - 20,
      today_stamps    = v_today_stamps,
      last_stamp_date = v_today
  where user_id = v_uid;

  -- 기프티콘 배정
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

-- 9. 유저 리워드 조회 RPC (KST 날짜 보정 포함)
create or replace function public.get_my_rewards()
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid     uuid := auth.uid();
  v_today   date := (now() at time zone 'Asia/Seoul')::date;
  v_row     public.user_rewards;
  v_today_stamps int;
begin
  if v_uid is null then
    raise exception '로그인이 필요해요.';
  end if;

  select * into v_row
  from public.user_rewards
  where user_id = v_uid;

  if not found then
    return jsonb_build_object(
      'total_stamps', 0,
      'today_stamps', 0,
      'last_stamp_date', null
    );
  end if;

  -- KST 날짜 기준 일일 초기화 (읽기 경로)
  if v_row.last_stamp_date is distinct from v_today then
    v_today_stamps := 0;
  else
    v_today_stamps := v_row.today_stamps;
  end if;

  return jsonb_build_object(
    'total_stamps',    v_row.total_stamps,
    'today_stamps',    v_today_stamps,
    'last_stamp_date', v_row.last_stamp_date
  );
end;
$$;

grant execute on function public.get_my_rewards() to authenticated;

-- 10. 어드민: 기프티콘 등록 RPC (이미지는 앱에서 Storage에 업로드 후 URL 전달)
create or replace function public.admin_register_gifticon(
  p_brand        text,
  p_product_name text,
  p_image_url    text,
  p_expires_at   date default null
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

  insert into public.gifticons (brand, product_name, image_url, expires_at)
  values (p_brand, p_product_name, p_image_url, p_expires_at)
  returning id into v_id;

  return jsonb_build_object('id', v_id);
end;
$$;

grant execute on function public.admin_register_gifticon(text, text, text, date) to authenticated;

-- 11. 어드민: 기프티콘 목록 조회 (RLS bypass용 함수)
create or replace function public.admin_list_gifticons()
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
begin
  if not exists (
    select 1 from public.users u
    where u.id = v_uid and u.role = 'admin'
  ) then
    raise exception '관리자만 조회할 수 있어요.';
  end if;

  return (
    select jsonb_agg(row_to_json(g.*) order by g.created_at desc)
    from public.gifticons g
  );
end;
$$;

grant execute on function public.admin_list_gifticons() to authenticated;

comment on table public.gifticons is '기프티콘 목록. image_url은 배정된 유저에게만 RLS로 노출.';
comment on table public.user_rewards is '유저별 스탬프 현황. today_stamps는 KST 날짜 기준 get_my_rewards()에서 보정됨.';

-- 12. Storage 버킷 정책 (Supabase Dashboard에서 "gifticons" 버킷을 private으로 생성 후 실행)
-- 배정된 유저만 자기 기프티콘 이미지를 다운로드/signed URL 생성 가능
-- 어드민은 전체 접근

-- 기존 정책 정리 (재실행 안전)
drop policy if exists "gifticons_storage_select_own" on storage.objects;
drop policy if exists "gifticons_storage_insert_admin" on storage.objects;
drop policy if exists "gifticons_storage_delete_admin" on storage.objects;

-- 배정된 유저: image_url(storage path)이 자신의 기프티콘에 있는 경우만 SELECT
create policy "gifticons_storage_select_own" on storage.objects
  for select using (
    bucket_id = 'gifticons'
    and (
      -- 어드민은 전체 접근
      exists (
        select 1 from public.users u
        where u.id = auth.uid() and u.role = 'admin'
      )
      or
      -- 배정된 유저: 이 storage path가 자신에게 배정된 기프티콘의 image_url과 일치
      exists (
        select 1 from public.gifticons g
        where g.image_url = (bucket_id || '/' || name)
          and g.assigned_user_id = auth.uid()
          and g.status = 'assigned'
      )
    )
  );

-- 어드민만 이미지 업로드 허용
create policy "gifticons_storage_insert_admin" on storage.objects
  for insert with check (
    bucket_id = 'gifticons'
    and exists (
      select 1 from public.users u
      where u.id = auth.uid() and u.role = 'admin'
    )
  );

-- 어드민만 이미지 삭제 허용
create policy "gifticons_storage_delete_admin" on storage.objects
  for delete using (
    bucket_id = 'gifticons'
    and exists (
      select 1 from public.users u
      where u.id = auth.uid() and u.role = 'admin'
    )
  );
