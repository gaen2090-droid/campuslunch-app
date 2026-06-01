-- 캠퍼스런치: 앱(Publishable 키)에서 restaurants / crowd_reports 읽기·쓰기 허용
-- Supabase Dashboard → SQL Editor 에 아래 전체를 붙여넣고 Run

alter table public.restaurants enable row level security;
alter table public.crowd_reports enable row level security;

-- 읽기
drop policy if exists "restaurants_select_public" on public.restaurants;
create policy "restaurants_select_public" on public.restaurants
  for select using (true);

drop policy if exists "crowd_reports_select_public" on public.crowd_reports;
create policy "crowd_reports_select_public" on public.crowd_reports
  for select using (true);

-- 혼잡도 제보
drop policy if exists "crowd_reports_insert_public" on public.crowd_reports;
create policy "crowd_reports_insert_public" on public.crowd_reports
  for insert with check (source in ('user', 'owner', 'system'));

-- 어드민 매장 등록/수정 (배포 전 서버·Edge Function으로 제한 권장)
drop policy if exists "restaurants_insert_public" on public.restaurants;
create policy "restaurants_insert_public" on public.restaurants
  for insert with check (true);

drop policy if exists "restaurants_update_public" on public.restaurants;
create policy "restaurants_update_public" on public.restaurants
  for update using (true) with check (true);
