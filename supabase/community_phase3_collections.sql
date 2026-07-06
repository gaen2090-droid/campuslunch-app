-- 커뮤니티 Phase 3: 맛집 컬렉션 (Dashboard → SQL Editor → Run)
-- docs/PLAN_community_and_collections.md §C 반영

create table if not exists public.collections (
  id           uuid primary key default gen_random_uuid(),
  title        text not null,
  subtitle     text,
  sort_order   int not null default 0,
  is_published boolean not null default false,
  created_at   timestamptz not null default now()
);

create table if not exists public.collection_items (
  id            uuid primary key default gen_random_uuid(),
  collection_id uuid not null references public.collections(id) on delete cascade,
  restaurant_id uuid not null references public.restaurants(id) on delete cascade,
  note          text,
  sort_order    int not null default 0,
  unique (collection_id, restaurant_id)
);
create index if not exists collection_items_collection_idx
  on public.collection_items (collection_id, sort_order);

alter table public.collections      enable row level security;
alter table public.collection_items enable row level security;

drop policy if exists "collections read published" on public.collections;
create policy "collections read published" on public.collections
  for select to authenticated using (is_published or public.is_admin());

drop policy if exists "collections admin write" on public.collections;
create policy "collections admin write" on public.collections
  for all to authenticated
  using (public.is_admin())
  with check (public.is_admin());

-- collection_items: 부모 컬렉션이 게시됐거나 관리자일 때만 읽기 허용 (핵심: 비게시 컬렉션의
-- 아이템이 개별적으로 새지 않도록 부모 상태를 반드시 함께 확인)
drop policy if exists "collection items read via parent" on public.collection_items;
create policy "collection items read via parent" on public.collection_items
  for select to authenticated using (
    exists (
      select 1 from public.collections c
      where c.id = collection_items.collection_id
        and (c.is_published or public.is_admin())
    )
  );

drop policy if exists "collection items admin write" on public.collection_items;
create policy "collection items admin write" on public.collection_items
  for all to authenticated
  using (public.is_admin())
  with check (public.is_admin());
