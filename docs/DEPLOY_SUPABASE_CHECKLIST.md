# Supabase 배포 전 체크리스트

## 필수 SQL 실행 순서

`supabase/schema.sql` 1~14번 실행 후:

```text
15. supabase/deploy_prelaunch_security.sql   ← 배포 전 반드시
    (같은 세션에서 push_analytics.sql 66~312행 admin_dashboard_metrics 도 실행)
16. supabase/users_nickname_unique.sql       (미실행 시)
```

## 테이블별 RLS · CRUD (앱 anon/authenticated 기준)

| 테이블 | SELECT | INSERT | UPDATE | DELETE |
|--------|--------|--------|--------|--------|
| `users` | 본인만 | 본인 (트리거 생성) | 본인 (`role` 변경 불가) | RPC `delete_own_account` |
| `restaurants` | `is_active=true` (+ admin 전체) | admin | admin | admin |
| `crowd_reports` | 전체 | authenticated (`user`/`owner`) | — | admin RPC |
| `crowd_status` | 전체 | 트리거/RPC | 트리거/RPC | admin |
| `gifticons` | 본인 배정분 + admin | admin RPC | admin | admin RPC |
| `user_rewards` | 본인 + admin | RPC만 | RPC만 | cascade |
| `analytics_events` | — | authenticated (본인) | — | admin |
| `owner_seat_updates` | 전체 | owner RPC | — | — |
| `app_feedback` | admin | authenticated | — | — |

제보·스탬프·기프티콘은 **직접 테이블 쓰기보다 RPC** (`submit_crowd_report`, `redeem_gifticon` 등) 사용.

## Dashboard에서 수동 확인

1. **Authentication → Policies**: 위 테이블 RLS `enabled`
2. **API Keys**: 앱에는 **anon(publishable) 키만** — `service_role` 절대 포함 금지
3. **Storage `gifticons`**: private 버킷 + `rewards.sql` storage policy 적용
4. **관리자 계정**: `public.users.role = 'admin'` 은 Dashboard SQL로만 부여

```sql
update public.users set role = 'admin' where email = 'your-admin@example.com';
```

5. **Realtime**: 필요 시 `crowd_status.sql` publication 확인

## 배포 패치가 막는 취약점

- JWT `user_metadata.role` 로 admin 승격
- `grant_stamp` RPC 직접 호출로 스탬프 조작
- `user_rewards` 직접 UPDATE로 스탬프 조작
- `admin_dashboard_metrics` anon 호출로 지표 유출
- 가입 시 metadata `role=admin` 반영
- `app_feedback` RLS 없음
