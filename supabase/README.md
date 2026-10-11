# Supabase SQL

앱이 실행할 때 이 폴더를 읽지 않는다. Dashboard SQL Editor에서 필요한 파일만 실행한다.

`supabase/*.sql` 이 현재 정본이다. 기능별로 파일이 나뉜 것은 그때그때 추가한 마이그레이션이라, 한 파일로 합치면 이미 적용된 함수가 옛 본문으로 덮인다. 그래서 정본은 루트에 그대로 둔다.

`archive/` 는 이미 적용됐거나 정본에 흡수된 스크립트다. 다시 Run 하지 않는다. 목록은 `archive/README.md`.

## 어디를 고치나

| 고칠 것 | 파일 |
|---------|------|
| 제보 RPC | `submit_crowd_report.sql` 와 `crowd_enabled_two_tier.sql` 을 같이 |
| 혼잡도 계산 | `crowd_status_v2_compute.sql` |
| 스탬프 한도 | `rewards_daily_cap_to_3.sql` (`archive/rewards_v2_daily_cap_fix.sql` 은 999, 금지) |
| 사장님 매장 수정 | `rpc_owner_update_restaurant.sql` |
| 회원/Auth | `users_auth.sql` |
| RLS | `policies.sql` |

빈 데이터베이스를 처음부터 만들 때의 순서는 `schema.sql` 과 `docs/CODEBASE_DEBUG_GUIDE.pdf` 6장이다. `schema.sql` 자체는 실행하지 않는다.

## 루트 파일 묶음

이름 접두로 찾으면 된다.

- `users_` `rpc_email_` `rpc_oauth_` `rpc_nickname_` `nickname_` `user_` — 회원, 닉네임, 약관, 정지
- `rpc_claim_owner` `rpc_release_owner` `rpc_owner_` `owner_` — 사장님
- `crowd_` `submit_crowd_report` `stats_excluded_users` `trust_abuse_` — 혼잡도 제보
- `rewards` `giftishow_` `referral_` `stamp_hours_` — 스탬프, 기프티콘, 초대
- `community_` `collection_` `comment_` `reply_push_` — 커뮤니티, 컬렉션
- `fcm_` `push_` `news_push` `peak_push_` `reward_push` — 푸시
- `admin_` `rpc_admin_` `rpc_purge_` `dev_purge_` — 어드민, 회원 삭제
- `analytics_events` `policies` `restaurant_` — 공통 스키마
