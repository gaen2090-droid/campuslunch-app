# 실행하지 말 것 (이력 보관)

여기 파일은 **이미 운영에 적용됐거나, 정본에 흡수된 일회성 패치**다.
Dashboard에서 다시 Run하면 `submit_crowd_report` 등 함수를 옛 본문으로 덮어쓴다.

| 파일 | 당시 용도 | 지금 |
|------|-----------|------|
| `submit_crowd_report_merge_stamp_and_location.sql` | 스탬프+50m 합본 | `../submit_crowd_report.sql` |
| `owner_report_location_limit.sql` | 사장 제보 50m (스탬프 없음) | 정본에 포함 |
| `hotfix_crowd_report_types.sql` | enum 타입 오류 | `crowd_status.sql` 헬퍼 |
| `hotfix_waiting_level.sql` | 4단계(웨이팅) 도입 | 폐기됨 |
| `hotfix_revert_waiting_level.sql` | 3단계 복원 | 적용 완료 |
| `hotfix_new_user_nickname_conflict.sql` | `'사용자'` UNIQUE | `users_auth.sql` + 출시 핫픽스 |
| `hotfix_community_push_hardcode_url.sql` | 푸시 URL 하드코딩 | **시크릿 유출. 재실행 금지** |
| `admin_db_direct_edit.sql` | 어드민이 restaurants를 직접 고치던 RPC | 롤백됨. `restaurant_tier_tables.sql`이 정본 |
| `owner_map_click_stats.sql` | 지도 클릭 통계 | `owner_detail_view_stats.sql`이 대체 |
| `owner_search_click_stats.sql` | 검색 클릭 통계 | `owner_detail_view_stats.sql`이 대체 |
| `admin_reset_gifticons.sql` | 기프티콘 테스트 데이터 전체 삭제 | 1회성. 재실행하면 발급 데이터가 지워짐 |
| `clear_stale_hours_periods.sql` | 어드민 영업시간과 구글 캐시가 어긋난 매장 정리 | 2026-10-06 적용 완료 |
| `rewards_v2_daily_cap_fix.sql` | 스탬프 일일 한도 999 | 테스트용. 운영 한도는 `rewards_daily_cap_to_3.sql` |

제보 RPC를 고칠 때는 **`supabase/submit_crowd_report.sql`만** 수정·실행한다.
