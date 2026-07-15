-- ── 유저 작성 맛집 컬렉션 (Dashboard → SQL Editor → Run) ──
-- 실행 순서: community_phase3_collections.sql, collection_likes.sql 이후
--
-- 기존 collections는 관리자 전용 큐레이션이었음. user_id 컬럼을 추가해
-- 유저도 직접 작성 가능하게 하고, 작성 즉시 공개(게시글과 동일한 모더레이션 정책 —
-- is_hidden으로 신고 시 숨김 처리, 삭제 아님).

alter table public.collections add column if not exists user_id uuid references public.users(id) on delete cascade;
alter table public.collections add column if not exists is_hidden boolean not null default false;

create index if not exists collections_user_idx on public.collections (user_id);

-- 유저 작성 컬렉션 아이템 최대 20개 제한 (관리자 큐레이션은 예외 없이 동일 적용)
create or replace function public._check_collection_item_limit()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_count int;
begin
  select count(*) into v_count
  from public.collection_items
  where collection_id = new.collection_id;

  if v_count >= 20 then
    raise exception '컬렉션에는 매장을 최대 20개까지 등록할 수 있어요.';
  end if;

  return new;
end;
$$;

drop trigger if exists trg_collection_item_limit on public.collection_items;
create trigger trg_collection_item_limit
  before insert on public.collection_items
  for each row execute function public._check_collection_item_limit();

-- ── RLS: 기존 "관리자만 전체 쓰기" 정책에 "본인 컬렉션 쓰기" 추가 ──

drop policy if exists "collections admin write" on public.collections;
drop policy if exists "collections owner write" on public.collections;
create policy "collections owner write" on public.collections
  for all to authenticated
  using (public.is_admin() or user_id = auth.uid())
  with check (public.is_admin() or user_id = auth.uid());

-- select 정책: 관리자 큐레이션(is_published) 또는 유저 작성(숨김 아님) 또는 본인 것
drop policy if exists "collections read published" on public.collections;
create policy "collections read published" on public.collections
  for select to authenticated using (
    public.is_admin()
    or user_id = auth.uid()
    or (user_id is null and is_published)
    or (user_id is not null and not is_hidden)
  );

drop policy if exists "collection items admin write" on public.collection_items;
drop policy if exists "collection items owner write" on public.collection_items;
create policy "collection items owner write" on public.collection_items
  for all to authenticated
  using (
    public.is_admin()
    or exists (
      select 1 from public.collections c
      where c.id = collection_items.collection_id and c.user_id = auth.uid()
    )
  )
  with check (
    public.is_admin()
    or exists (
      select 1 from public.collections c
      where c.id = collection_items.collection_id and c.user_id = auth.uid()
    )
  );

drop policy if exists "collection items read via parent" on public.collection_items;
create policy "collection items read via parent" on public.collection_items
  for select to authenticated using (
    exists (
      select 1 from public.collections c
      where c.id = collection_items.collection_id
        and (
          public.is_admin()
          or c.user_id = auth.uid()
          or (c.user_id is null and c.is_published)
          or (c.user_id is not null and not c.is_hidden)
        )
    )
  );

-- ── 신고 (게시글과 동일 패턴) ──

create table if not exists public.collection_reports (
  id            uuid primary key default gen_random_uuid(),
  reporter_id   uuid not null references public.users(id) on delete cascade,
  collection_id uuid not null references public.collections(id) on delete cascade,
  reason        text,
  created_at    timestamptz not null default now()
);

alter table public.collection_reports enable row level security;

drop policy if exists "collection reports insert own" on public.collection_reports;
create policy "collection reports insert own" on public.collection_reports
  for insert to authenticated with check (reporter_id = auth.uid());

drop policy if exists "collection reports select admin" on public.collection_reports;
create policy "collection reports select admin" on public.collection_reports
  for select to authenticated using (public.is_admin());

-- ── 유저 컬렉션 작성 RPC (제목/부제목 + 매장 id 목록을 한 번에, 원자적으로) ──

drop function if exists public.create_user_collection(text, text, uuid[]);
create or replace function public.create_user_collection(
  p_title      text,
  p_subtitle   text,
  p_restaurant_ids uuid[]
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_collection_id uuid;
  v_restaurant_id uuid;
  v_idx int := 0;
begin
  if v_uid is null then
    raise exception '로그인이 필요해요.';
  end if;

  if p_title is null or char_length(trim(p_title)) = 0 then
    raise exception '제목을 입력해주세요.';
  end if;

  if p_restaurant_ids is null or array_length(p_restaurant_ids, 1) is null then
    raise exception '매장을 1개 이상 선택해주세요.';
  end if;

  if array_length(p_restaurant_ids, 1) > 20 then
    raise exception '컬렉션에는 매장을 최대 20개까지 등록할 수 있어요.';
  end if;

  insert into public.collections (title, subtitle, user_id, is_published)
  values (trim(p_title), nullif(trim(coalesce(p_subtitle, '')), ''), v_uid, true)
  returning id into v_collection_id;

  foreach v_restaurant_id in array p_restaurant_ids loop
    insert into public.collection_items (collection_id, restaurant_id, sort_order)
    values (v_collection_id, v_restaurant_id, v_idx);
    v_idx := v_idx + 1;
  end loop;

  return v_collection_id;
end;
$$;

grant execute on function public.create_user_collection(text, text, uuid[]) to authenticated;

-- ── 컬렉션 신고 RPC ──

drop function if exists public.report_collection(uuid, text);
create or replace function public.report_collection(p_collection_id uuid, p_reason text)
returns void
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

  insert into public.collection_reports (reporter_id, collection_id, reason)
  values (v_uid, p_collection_id, p_reason);
end;
$$;

grant execute on function public.report_collection(uuid, text) to authenticated;

-- ── 컬렉션 목록 조회 RPC 갱신 (작성자 닉네임 + 유저작성 포함) ──

drop function if exists public.collections_with_likes();
create or replace function public.collections_with_likes()
returns table (
  id uuid,
  title text,
  subtitle text,
  sort_order int,
  like_count int,
  liked_by_me boolean,
  comment_count int,
  author_nickname text,
  is_owner boolean,
  created_at timestamptz
)
language sql
stable
security definer
set search_path = public
as $$
  select
    c.id,
    c.title,
    c.subtitle,
    c.sort_order,
    (select count(*) from public.collection_likes l where l.collection_id = c.id)::int as like_count,
    exists (
      select 1 from public.collection_likes l
      where l.collection_id = c.id and l.user_id = auth.uid()
    ) as liked_by_me,
    (
      select count(*) from public.collection_comments cc
      where cc.collection_id = c.id and not cc.is_hidden
    )::int as comment_count,
    u.nickname as author_nickname,
    (c.user_id = auth.uid()) as is_owner,
    c.created_at
  from public.collections c
  left join public.users u on u.id = c.user_id
  where
    (c.user_id is null and c.is_published)
    or (c.user_id is not null and not c.is_hidden)
  order by
    case when c.user_id is null then c.sort_order else null end asc nulls last,
    c.created_at desc;
$$;

revoke all on function public.collections_with_likes() from public;
grant execute on function public.collections_with_likes() to authenticated;

comment on column public.collections.user_id is '유저 작성 컬렉션의 작성자. null이면 관리자 큐레이션.';
comment on column public.collections.is_hidden is '신고 등으로 관리자가 숨김 처리(유저 작성 컬렉션 전용). 삭제와 별개.';
