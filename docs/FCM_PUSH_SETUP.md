# FCM 원격 푸시 배포 · 시크릿 설정

앱은 Firebase Messaging으로 FCM 토큰을 받아 Supabase에 저장합니다.
피크/커뮤니티 알림은 Edge Function이 FCM HTTP v1으로 발송합니다.

## 1. SQL

Supabase Dashboard → SQL Editor **순서대로**:

1. `supabase/fcm_push.sql`
2. `supabase/admin_push_control.sql` (전역 ON/OFF · 운영 스냅샷 · device_tokens 뷰)
3. `supabase/community_push_v2.sql` (커뮤니티 문구 템플릿 · 좋아요 인박스/FCM · 피크 로컬 기본)

## 2. Firebase 서비스 계정

1. Firebase Console → 프로젝트 설정 → 서비스 계정
2. 「새 비공개 키 생성」 → JSON 다운로드
3. Supabase → Project Settings → Edge Functions → Secrets:

| Secret | 값 |
|--------|-----|
| `FIREBASE_SERVICE_ACCOUNT_JSON` | 서비스 계정 JSON 전체 (한 줄/이스케이프 OK) |
| `EDGE_PUSH_SECRET` | 임의 긴 문자열 (cron·웹훅 Authorization) |

또는 분리:

- `FIREBASE_PROJECT_ID`
- `FIREBASE_CLIENT_EMAIL`
- `FIREBASE_PRIVATE_KEY` (줄바꿈은 `\n`)

`SUPABASE_URL` / `SUPABASE_SERVICE_ROLE_KEY` 는 플랫폼이 자동 주입합니다.

## 3. Edge Function 배포

```bash
supabase functions deploy send-peak-push
supabase functions deploy send-community-push
supabase functions deploy send-config-refresh
```

어드민 웹 **푸시 설정** 탭에서:

- **피크**: 로컬 예약(기본) + 시각·문구. 서버 FCM은 옵션
- **커뮤니티**: FCM ON/OFF + 댓글/좋아요 제목·본문 템플릿 (`{nickname}`, `{content}`, `{post_preview}`)
- 토큰·옵트인 현황, 테스트 FCM, 설정 전파(config_refresh)

## 4. 피크 스케줄 (매분 → 설정 시각에만 발송)

Dashboard → Edge Functions → Schedules, 또는 SQL (`pg_cron` + `pg_net`):

```sql
-- 프로젝트 URL / 시크릿을 바꿔 넣으세요
select cron.schedule(
  'campuslunch-peak-push',
  '* * * * *',
  $$
  select net.http_post(
    url := 'https://YOUR_PROJECT_REF.supabase.co/functions/v1/send-peak-push',
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'Authorization', 'Bearer YOUR_EDGE_PUSH_SECRET'
    ),
    body := '{}'::jsonb
  );
  $$
);
```

수동 테스트:

```bash
curl -X POST \
  'https://YOUR_PROJECT_REF.supabase.co/functions/v1/send-peak-push?force=lunch' \
  -H "Authorization: Bearer YOUR_EDGE_PUSH_SECRET"
```

## 5. 커뮤니티 댓글·좋아요 웹훅

대상 이벤트:

| 이벤트 | 수신자 | 어드민 템플릿 |
|--------|--------|---------------|
| 댓글 | 글 작성자 + 알림 켠 구독자 | `community_comment_*` |
| 좋아요 | 글 작성자만 | `community_like_*` |

### 방법 A — Database Webhook

Dashboard → Database → Webhooks (각각 INSERT):

- `community_comments` → `send-community-push`
- `community_likes` → `send-community-push`
- Header: `Authorization: Bearer YOUR_EDGE_PUSH_SECRET`

Edge는 `record` / `event` / `comment_id` / `post_id`+`liker_id` 모두 인식합니다.

### 방법 B — 트리거 + pg_net (`community_push_v2.sql`)

SQL에서 설정:

```sql
alter database postgres set app.settings.edge_community_push_url =
  'https://YOUR_PROJECT_REF.supabase.co/functions/v1/send-community-push';
alter database postgres set app.settings.edge_push_secret =
  'YOUR_EDGE_PUSH_SECRET';
```

`pg_net` 확장이 켜져 있어야 합니다. 댓글·좋아요 INSERT 트리거가 Edge를 호출합니다.

## 6. iOS APNs

Firebase Console → 프로젝트 설정 → Cloud Messaging → Apple 앱:

- APNs 인증 키(.p8) 업로드 (필수, 없으면 iOS 종료 상태 푸시 불가)

Xcode: Runner → Signing & Capabilities → **Push Notifications** 추가.

## 7. Android 디버그 빌드

`applicationIdSuffix = ".debug"` 이므로 Debug는 패키지 `com.campuslunch.app.debug`.
Firebase에 Debug용 Android 앱을 추가하고 `google-services.json`을 다시 받거나,
릴리스/`--release`로 테스트하세요.
