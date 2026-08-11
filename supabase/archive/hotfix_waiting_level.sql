-- 핫픽스: "웨이팅이 많아요" 제보가 레벨 1(여유로움)로 잘못 반영되는 문제
-- 원인: ui_status_to_level()이 crowd_status.sql에만 정의돼 있고,
--       '웨이팅많음' 토큰을 몰라서 기본값(1)으로 떨어짐.
-- crowd_status.sql 전체를 재실행하면 submit_crowd_report(void 버전)가
-- rewards.sql의 jsonb 버전을 덮어써서 충돌하므로, 이 함수만 단독 실행한다.
--
-- 추가: 여유로움/약간혼잡/자리없음/웨이팅많음을 4단계 독립 동급 레벨로 분리
-- (이전엔 '웨이팅많음'이 '자리없음'과 같은 레벨 3으로 합쳐져 있었음)

create or replace function public.ui_status_to_level(p_input text)
returns int
language sql
immutable
as $$
  select case trim(coalesce(p_input, ''))
    when '1' then 1
    when '2' then 2
    when '3' then 3
    when '4' then 4
    when '여유로움' then 1
    when '약간혼잡' then 2
    when '자리없음' then 3
    when '웨이팅많음' then 4
    when 'normal' then 1
    when 'relaxed' then 1
    when 'full' then 2
    when 'moderate' then 2
    when 'closed' then 1
    else greatest(1, least(4, coalesce(
      nullif(regexp_replace(trim(coalesce(p_input, '')), '[^0-9]', '', 'g'), '')::int,
      1
    )))
  end;
$$;

create or replace function public.level_to_ui_status(p_level int)
returns text
language sql
immutable
as $$
  select case greatest(1, least(4, coalesce(p_level, 1)))
    when 1 then '여유로움'
    when 2 then '약간혼잡'
    when 3 then '자리없음'
    else '웨이팅많음'
  end;
$$;

create or replace function public.ui_level_to_crowd_level(p_ui_level int)
returns public.crowd_level
language sql
immutable
as $$
  select case greatest(1, least(4, coalesce(p_ui_level, 1)))
    when 1 then 'normal'::public.crowd_level
    when 2 then 'full'::public.crowd_level
    else 'full'::public.crowd_level
  end;
$$;
