-- 점심/저녁 2슬롯 → 단일 "점심시간 알림" 슬롯으로 정리
-- Dashboard → SQL Editor → Run (peak_push_personalized.sql 이후)
--
-- 어드민 UI가 이제 슬롯 1개(id='lunch')만 편집하도록 단순화됨. 기존에 저장된
-- peak_schedules 배열에 dinner 슬롯이 남아있으면 cron이 여전히 그 시각에도
-- 발송을 시도하므로, DB에서도 lunch 슬롯 하나만 남기고 나머지는 제거한다.

update public.push_notification_config c
set peak_schedules = (
  select jsonb_agg(elem)
  from jsonb_array_elements(c.peak_schedules) elem
  where elem ->> 'id' = 'lunch'
)
where id = 1
  and c.peak_schedules is not null
  and jsonb_array_length(c.peak_schedules) > 1;

-- lunch 슬롯이 아예 없던 예외 상황 대비: 비어 있으면 기본값으로 채움
update public.push_notification_config c
set peak_schedules = jsonb_build_array(
  jsonb_build_object(
    'id', 'lunch',
    'label', '점심시간 알림',
    'enabled', true,
    'hour', 12,
    'minute', 0,
    'title_template', '{restaurant}에서 대기없이 식사할 수 있어요',
    'body_template', '다른 매장도 확인해보기 >',
    'fallback_title_template', '대기 없이 식사할 수 있어요',
    'fallback_body_template', '지금 바로 입장 가능한 매장을 확인해보세요' || chr(10) || '확인하러 가기 >'
  )
)
where id = 1
  and (c.peak_schedules is null or jsonb_array_length(c.peak_schedules) = 0);

-- 점심시간 알림은 어드민에서 켜고 끌 수 있는 옵션이 아니라 항상 사장님 계정을
-- 제외하고 나간다 (어드민 UI에서 "사장님 제외" 체크박스 제거, 기본값으로 고정).
update public.push_notification_config
set peak_exclude_owners = true, updated_at = now()
where id = 1;

select peak_schedules, peak_exclude_owners from public.push_notification_config where id = 1;
