-- Google Places로만 등록된 매장 삭제 (카카오 전환 후 재등록용)
-- Dashboard → SQL Editor에서 실행
--
-- 대상: description에 google_place_id 있고 kakao_place_id 없는 행
-- (하이브리드 등록: kakao + google 둘 다 있음 → 유지)

begin;

-- 삭제 대상 확인 (실행 전 미리보기)
-- select id, name, description from public.restaurants
-- where description is not null
--   and description::jsonb ? 'google_place_id'
--   and not (description::jsonb ? 'kakao_place_id');

delete from public.crowd_reports cr
where cr.restaurant_id in (
  select r.id from public.restaurants r
  where r.description is not null
    and r.description::jsonb ? 'google_place_id'
    and not (r.description::jsonb ? 'kakao_place_id')
);

delete from public.owner_seat_updates osu
where osu.restaurant_id in (
  select r.id from public.restaurants r
  where r.description is not null
    and r.description::jsonb ? 'google_place_id'
    and not (r.description::jsonb ? 'kakao_place_id')
);

delete from public.crowd_status cs
where cs.restaurant_id in (
  select r.id from public.restaurants r
  where r.description is not null
    and r.description::jsonb ? 'google_place_id'
    and not (r.description::jsonb ? 'kakao_place_id')
);

delete from public.analytics_events ae
where ae.restaurant_id in (
  select r.id from public.restaurants r
  where r.description is not null
    and r.description::jsonb ? 'google_place_id'
    and not (r.description::jsonb ? 'kakao_place_id')
);

delete from public.restaurants r
where r.description is not null
  and r.description::jsonb ? 'google_place_id'
  and not (r.description::jsonb ? 'kakao_place_id');

commit;
