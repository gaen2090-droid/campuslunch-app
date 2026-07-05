-- 매장 App Link 번호 (추가 순서대로 1, 2, 3… 자동 배정)
-- Dashboard → SQL Editor → Run (restaurants 테이블 존재 후)
--
-- 링크 형식: https://campuslunch.shop/r/{link_no}

alter table public.restaurants
  add column if not exists link_no integer;

create sequence if not exists public.restaurants_link_no_seq;

create or replace function public.restaurants_assign_link_no()
returns trigger
language plpgsql
as $$
begin
  if new.link_no is null then
    new.link_no := nextval('public.restaurants_link_no_seq');
  end if;
  return new;
end;
$$;

drop trigger if exists trg_restaurants_assign_link_no on public.restaurants;
create trigger trg_restaurants_assign_link_no
  before insert on public.restaurants
  for each row execute function public.restaurants_assign_link_no();

-- 기존 매장 백필 (created_at 순)
with numbered as (
  select
    id,
    row_number() over (order by created_at asc nulls last, id asc) as rn
  from public.restaurants
  where link_no is null
)
update public.restaurants r
set link_no = n.rn
from numbered n
where r.id = n.id;

select setval(
  'public.restaurants_link_no_seq',
  coalesce((select max(link_no) from public.restaurants), 0) + 1,
  false
);

create unique index if not exists restaurants_link_no_unique_idx
  on public.restaurants (link_no)
  where link_no is not null;

comment on column public.restaurants.link_no is
  'App Link 경로 번호 (/r/{link_no}). INSERT 시 시퀀스 자동 배정.';
