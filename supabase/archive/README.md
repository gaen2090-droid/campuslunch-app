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

제보 RPC를 고칠 때는 **`supabase/submit_crowd_report.sql`만** 수정·실행한다.
