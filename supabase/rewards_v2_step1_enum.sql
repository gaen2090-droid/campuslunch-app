-- 기프티콘 v2 — 1단계: enum 'used' 추가
-- ⚠️ 이 파일만 먼저 실행하고, 성공 확인 후 2단계(rewards_v2_gifticon_flow.sql) 실행
-- (PostgreSQL: enum 새 값은 커밋된 뒤에만 같은 세션에서 사용 가능)

alter type public.gifticon_status add value if not exists 'used';
