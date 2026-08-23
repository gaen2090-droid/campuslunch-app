-- 점심/저녁 피크 알림 개인화 - 정리 단계
-- Dashboard → SQL Editor → Run
-- ⚠️ 반드시 peak_push_personalized.sql 실행 + send-peak-push Edge Function 재배포
--    이후에 실행할 것. 먼저 실행하면 아직 새 함수로 안 바뀐 Edge Function이
--    존재하지 않는 함수를 호출해 피크 푸시가 실패한다.
--
-- send-peak-push가 더 이상 pick_peak_push_restaurant() / list_peak_push_tokens(text)를
-- 호출하지 않으므로(list_peak_push_targets(text)로 대체) 구 함수를 정리한다.

drop function if exists public.pick_peak_push_restaurant();
drop function if exists public.list_peak_push_tokens(text);

select 'peak_push_personalized_cleanup.sql ok' as status;
