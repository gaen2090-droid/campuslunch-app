-- 기프티콘 전체 초기화 (테스트 데이터 정리용, 1회성 스크립트)
-- 대상: public.gifticons 테이블만. public.user_rewards(스탬프)는 절대 건드리지 않음.
-- 실행: Supabase Dashboard → SQL Editor에서 아래를 위에서부터 순서대로 실행

-- ── 0) 실행 전 확인: 지금 상태별 개수 ──
select status, count(*) as cnt
from public.gifticons
group by status
order by status;

-- ── 1) 삭제될 이미지 storage 경로 확인 (참고용, 실행 후에도 남아있으면 아래 2번으로 정리) ──
select id, brand, product_name, status, image_url
from public.gifticons
order by created_at;

-- ── 2) gifticons 테이블 전체 삭제 ──
-- user_rewards(스탬프)는 이 테이블과 무관하므로 영향 없음.
delete from public.gifticons;

-- ── 3) 삭제 후 확인 (0건이어야 정상) ──
select count(*) as remaining from public.gifticons;

-- ── 4) storage의 기프티콘 이미지 파일 정리 (선택) ──
-- 위 1번 쿼리에서 나온 image_url이 "gifticons/xxx" 형태라면
-- Dashboard → Storage → gifticons 버킷에서 해당 파일들을 수동 삭제하거나,
-- 버킷 안의 모든 파일을 지워도 무방함 (기프티콘 레코드가 이미 없으므로 참조 문제 없음).
-- SQL로는 storage.objects를 아래처럼 지울 수 있음 (버킷 전체 비우기):
-- delete from storage.objects where bucket_id = 'gifticons';

-- ── 참고: user_rewards(스탬프)는 전혀 건드리지 않았음을 재확인 ──
select count(*) as users_with_stamps, sum(total_stamps) as total_stamps_sum
from public.user_rewards;
