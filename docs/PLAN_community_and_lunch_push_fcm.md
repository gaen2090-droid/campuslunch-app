# 커뮤니티 댓글 원격 푸시(FCM) 구현 기획

## 목표
내 글에 댓글이 달리거나, 내가 알림 설정(구독)한 글에 댓글이 달렸을 때, **앱이 완전히 꺼져 있어도**
OS 상태바에 푸시 알림이 뜨도록 한다. 마이페이지 → 설정 → 푸시 알림 설정 화면에 "점심 피크 추천 알림"
토글 아래 "커뮤니티 댓글 알림" 토글을 추가한다.

## 현재 상태 (조사 결과)
- 인앱 알림은 실시간 알림 레코드가 아니라 **조회 시점에 JOIN해서 계산**하는 구조
  (`community_inbox_notifications()` RPC — 댓글+좋아요, `supabase/community_push_v2.sql`).
  댓글이 insert되는 순간 아무 훅도 없음 — 이번에 신규로 붙여야 함.
- 글 단위 "알림 구독"은 이미 있음: `community_post_subscriptions` 테이블(post_id, user_id),
  `lib/screens/community_post_detail_screen.dart`의 종 아이콘 버튼으로 on/off.
- 로컬 예약 알림(`flutter_local_notifications`, `lib/services/push_notification_service.dart`)은
  "점심 피크 추천"에만 쓰이고 있고, `zonedSchedule()`로 최대 14일치를 미리 예약하는 방식이라
  이벤트 기반(댓글) 알림에는 애초에 맞지 않음. 원격 푸시(FCM) 인프라는 전혀 없음
  (`firebase_*` 패키지 없음, Edge Function 없음, 디바이스 토큰 테이블 없음).
- 알림 on/off 설정은 지금까지 전부 **SharedPreferences(로컬)** 에 저장(`AppProvider`,
  `_kLunchPush` 등). 이번 토글은 이 패턴을 그대로 따를 수 없음(아래 참고).
- 설정 화면: `lib/screens/push_notification_settings_screen.dart`의 `_ToggleRow` 위젯
  (L64-89 부근에 "점심 피크 추천 알림" 토글) — 동일 위젯을 재사용해 그 아래 추가.

## 핵심 설계 결정: 데이터 흐름
**댓글 INSERT → 서버가 반응 → FCM 발송 → 기기**

발송은 반드시 서버에서 일어나야 한다 — 수신자 목록(글 작성자 + 구독자, 나 자신 제외)은 DB 관계로
계산해야 하고, FCM 인증정보(서비스 계정 키)는 클라이언트에 절대 노출하면 안 되기 때문. 클라이언트가
직접 FCM을 호출하는 방식은 채택하지 않는다.

- Supabase **Database Webhook**(pg_net 기반)을 `community_comments` 테이블 INSERT에 걸어
  Edge Function을 호출.
- Edge Function이 (a) 수신자 계산 (b) 각 수신자의 푸시 설정 확인 (c) 디바이스 토큰 조회
  (d) FCM HTTP v1 API 호출을 수행.
- **FCM 레거시 서버 키는 폐지됨 — HTTP v1 + 서비스 계정 JSON(Supabase Secret)** 사용.
  OAuth 토큰은 Edge Function 내부에서 발급, 리포지토리/클라이언트에 절대 노출 금지.

## ⚠️ 가장 중요한 제약: 토글은 로컬 저장 불가
"점심 피크" 토글은 **일정이 클라이언트에서 결정**되므로 로컬 SharedPreferences로 충분했다.
하지만 커뮤니티 댓글 푸시는 **서버가 발송 여부를 결정**하므로, 로컬에만 저장된 플래그는 서버가
볼 수 없어 꺼도 무시하고 계속 발송된다. 따라서:

- **디바이스 토큰 = 신원 식별자** → 신규 테이블 `device_tokens`.
- **커뮤니티 댓글 푸시 수신 여부 = 서버 사이드 플래그** → `users`(또는 `profiles`) 테이블에
  컬럼 추가(예: `community_comment_push_enabled boolean default true`).
- Edge Function이 발송 직전에 이 플래그를 확인 후 스킵/발송 결정.
- UI는 기존 `_ToggleRow`를 그대로 재사용해 룩앤필은 "점심 피크"와 동일하게 유지하되,
  저장 경로만 Supabase RPC(UPDATE)로 다르게 구현.

## 수신자 규칙 (정책 확정 — Edge Function 필터 기준)
`community_comment_notifications()` RPC의 "내 글 + 구독한 글" 로직을 그대로 반영하되 방향만 반전:
- 댓글 작성자 ≠ 수신자
- 수신자 = (글 작성자, 글 작성자가 댓글 작성자가 아닌 경우) ∪ (그 글을 구독한 유저들, 댓글 작성자 제외)
- **전역 토글과 글별 구독의 우선순위**: 전역 토글 OFF면 어떤 경우에도 푸시 없음(내 글이든 구독한 글이든).
  전역 토글 ON이면 기존 규칙(내 글 작성자 여부 + 구독 여부)을 그대로 따른다.

## 클라이언트 작업
1. `pubspec.yaml`에 `firebase_core`, `firebase_messaging` 추가.
2. Firebase 프로젝트 생성(Android 앱 등록) → `google-services.json` → `android/app/`,
   Gradle 플러그인 설정.
3. 앱 시작 시 FCM 토큰 발급 → 로그인 성공 시 Supabase에 upsert(`device_tokens`: user_id, token,
   platform, updated_at), 로그아웃 시 해당 토큰 삭제(다른 계정으로 안 새게).
4. **포그라운드 알림 브릿지**: FCM은 앱이 포그라운드일 때 시스템 알림을 자동으로 안 띄우므로,
   `FirebaseMessaging.onMessage` 콜백에서 기존 `push_notification_service.dart`의
   `flutter_local_notifications`로 즉시 표시 — 새 Android 채널 `community_comment` 추가
   (기존 `peak_recommendation` 채널과 병행).
5. 알림 탭 → 딥링크: 기존 `fetchPostById` + 게시글 상세화면 네비게이션 재사용
   (알림 목록 화면의 탭 핸들러와 동일 패턴). **두 가지 진입 경로 모두 처리**:
   - 앱 실행 중에 탭 → `FirebaseMessaging.onMessageOpenedApp`
   - 앱이 완전히 종료된 상태에서 트레이 알림 탭으로 콜드스타트 → `onMessageOpenedApp`은 발화하지
     않으므로 앱 시작 시 `FirebaseMessaging.instance.getInitialMessage()`로 별도 처리 필요.
6. Android 13+ 런타임 권한(`POST_NOTIFICATIONS`)은 **이미 구현되어 있음**
   (`push_notification_service.dart:80-98`, `requestPermission()`이 `requestNotificationsPermission()`
   호출) — 새로 만들지 말고, 커뮤니티 댓글 푸시 옵트인 진입 경로(토글 ON 시점)에서 동일 함수가
   호출되는지만 확인.
7. `push_notification_settings_screen.dart`: "점심 피크 추천 알림" `_ToggleRow` 바로 아래
   "커뮤니티 댓글 알림" `_ToggleRow` 추가. 값은 `AppProvider`가 아니라 Supabase에서 읽고 쓰는
   새 경로(RPC) 사용. **서버 값이라 로컬 prefs와 달리 비동기 초기 로딩이 필요** — 화면 진입 시
   토글이 깜빡이지 않도록 `AppProvider`에 캐시해두고, 값 로딩 전에는 스위치를 비활성/스켈레톤 처리.

## 서버 작업
1. 신규 테이블 `device_tokens` (user_id, token unique, platform, updated_at), RLS: 본인 것만
   insert/update/delete, select.
2. `users`(or `profiles`) 테이블에 `community_comment_push_enabled boolean not null default true`
   컬럼 추가 + 본인만 수정 가능한 RPC(`set_community_comment_push_enabled(bool)`).
3. `community_comments` INSERT에 대한 Database Webhook 설정 (Supabase 대시보드 또는 마이그레이션
   SQL로 `net.http_post` 트리거 구성) → Edge Function 엔드포인트 호출.
4. **신규 Edge Function** (`supabase/functions/` 디렉토리 자체가 없음 — 이번이 최초):
   - 요청으로 받은 comment_id로 댓글/글/작성자/구독자 조회
   - 전역 토글 + 위 수신자 규칙 적용해 최종 수신자 목록 계산
   - 수신자별 `device_tokens` 조회
   - FCM HTTP v1로 발송 (서비스 계정 JSON은 Supabase Function Secret으로 저장)
   - **Supabase 클라이언트는 service-role 키로 초기화**(다른 유저의 `device_tokens`/구독 정보를
     읽어야 하는데, RLS가 "본인만 select"로 걸려 있어 caller JWT로는 조회 불가 — 반드시 service-role).
5. FCM 서비스 계정 키 발급(Firebase 콘솔) → Supabase Edge Function 환경변수(secret)로 등록.
6. **사전 확인(구현 착수 전 필수)**: 이 프로젝트의 Supabase 요금제에서 Database Webhooks(pg_net
   기반)가 실제로 활성화되어 있는지 Dashboard → Database → Webhooks에서 확인. 안 되어 있으면
   트리거 전달 메커니즘 자체를 다시 설계해야 하므로 Edge Function 작성보다 먼저 점검.

## 구현 순서 (Android 우선, iOS는 후속)
1. Firebase 프로젝트 생성 + Android 앱 등록, `google-services.json` 반영, Gradle 설정.
2. DB: `device_tokens` 테이블 + `community_comment_push_enabled` 컬럼 + RPC 마이그레이션 SQL 작성.
3. Edge Function 작성/배포 (`supabase/functions/community-comment-push/`), 로컬 테스트.
4. Database Webhook 연결 (`community_comments` INSERT → Edge Function).
5. 클라이언트: firebase_messaging 연동, 토큰 upsert/삭제, 포그라운드 브릿지, 알림 탭 딥링크.
6. 설정 화면에 토글 추가 (서버 RPC로 읽기/쓰기).
7. 실기기(안드로이드)로 종단 테스트: 앱 완전 종료 상태에서 다른 계정으로 댓글 → 푸시 도착 확인.

## 범위 밖 (후속 작업으로 명시)
- iOS 연동: Apple Developer Program 계정, APNs 인증 키를 Firebase에 업로드, `GoogleService-Info.plist`
  반영 — 이번 v1에는 포함하지 않고, 안드로이드 완료 후 별도로 진행.

## 추가: 점심 피크 알림 — "설정 변경 즉시 반영" 개선 (FCM 인프라 재사용)
**배경**: 관리자가 어드민 웹에서 `push_notification_config`(시간/문구)를 바꿔도, 유저 단말에는
앱을 다시 켜서 `refreshSchedules()`가 재실행될 때까지 반영되지 않음. 점심 피크 알림 자체는
**로컬 예약 방식을 그대로 유지**한다(오프라인에서도 정시 발송되는 안정성이 핵심 장점이라 이 부분은
바꾸지 않기로 확정 — pg_cron 등으로 매일 서버가 직접 쏘는 방식은 채택하지 않음).

**바꾸는 것은 "재예약을 트리거하는 신호"뿐**:
- 커뮤니티 댓글 푸시용으로 구축하는 FCM 인프라(디바이스 토큰 테이블, Edge Function, Firebase 프로젝트)를
  그대로 재사용.
- 관리자가 `admin_update_push_notification_config()` RPC로 설정을 저장하면, 그 직후 서버가
  **"설정이 바뀌었다"는 초경량 FCM data-only 메시지**를 전체 기기(또는 점심 피크 알림을 켜둔
  `device_tokens` 대상)에 발송.
- 클라이언트는 이 data 메시지를 수신하면(포그라운드/백그라운드 모두 `FirebaseMessaging.onMessage`
  / `onBackgroundMessage` 핸들러에서) **알림을 띄우지 않고** 조용히
  `PushNotificationService.instance.refreshSchedules()`를 호출해 기존 예약을 최신 설정으로 갱신.
- 이렇게 하면: 알림이 뜨는 "발송" 경로는 여전히 로컬(오프라인 안정성 유지), "최신 설정 반영"만
  즉시성이 생김. 서버 장애 시에도 최악의 경우 반영이 늦어질 뿐 그날 알림 자체가 안 가는 일은 없음.

**서버 작업 추가분**:
- `admin_update_push_notification_config()` RPC 성공 후, Database Webhook 또는 함수 내부에서
  바로 "설정 변경 알림" Edge Function(혹은 기존 댓글 푸시 Edge Function에 타입 분기 추가)을 호출해
  `device_tokens` 전체에 data-only FCM 발송.
- FCM 메시지에 `notification` 페이로드 없이 `data: {"type": "config_refresh"}`만 채워 보내서
  OS가 시스템 알림을 자동으로 띄우지 않게 한다(사용자에게 보일 필요 없는 내부 신호이므로).

**클라이언트 작업 추가분 — 포그라운드 한정 (v1 범위)**:
- `refreshSchedules()`는 `restaurants`, `useAlgorithmRanking`, `lunchEnabled`, `dinnerEnabled`까지
  5개 인자가 필요한 **앱 상태 의존 함수**다(`push_notification_service.dart:100`). 이 상태는
  `AppProvider`가 들고 있으므로, 재실행은 그 상태에 접근 가능한 컨텍스트에서만 가능하다.
- **따라서 v1은 `FirebaseMessaging.onMessage`(포그라운드) + 앱 resume 시점에서만 처리한다.**
  백그라운드/완전 종료 상태에서의 자동 재예약은 이번 범위에서 뺀다 — 별도 isolate에서 매장 목록
  재조회, 랭킹/토글 prefs 재로드, config 재조회까지 다시 부트스트랩해야 하고, 강제 종료 상태에선
  전달 자체가 보장되지 않아 신뢰성 대비 구현 난이도가 크다.
- 요구사항은 "관리자가 누르자마자 즉시"가 아니라 "다음 점심/저녁 발송 전에 반영"이므로, admin이
  바꾼 뒤 다음 발송 시각 사이에 유저가 한 번이라도 앱을 열면(포그라운드/resume) 충분히 반영된다.
  이 전제로 범위를 좁힌다.
- data 메시지 핸들러: `data['type'] == 'config_refresh'`면 최신 `push_notification_config`를
  다시 fetch 후 `AppProvider`의 기존 상태(매장 목록/토글/랭킹 설정)와 합쳐 `refreshSchedules()` 재호출.

**우선순위**: 댓글 푸시(신규 기능)가 먼저이고, 이 개선은 같은 인프라 위에 붙는 후속 작업으로
구현 순서 마지막에 배치.

## 비용 메모
FCM 발송 자체는 무료(트래픽 무관). 트리거 역할을 하는 Supabase Edge Function 호출 횟수만 무료 티어
한도(월 약 50만 회)가 있음 — 현재 캠퍼스 앱 규모에서는 사실상 문제 되지 않음.

---

## 구현 반영 메모 (develop 병합 · 2026-07-14)

기획과 실제 구현을 합친 결과:

| 기획 항목 | 구현 |
|-----------|------|
| `device_tokens` | `user_push_tokens` + 뷰 `device_tokens` 별칭 (`admin_push_control.sql`) |
| `community_comment_push_enabled` | `user_notification_prefs.community_comments` + `users.community_comment_push_enabled` 동기 트리거 |
| 커뮤니티 댓글 FCM | `send-community-push` + INSERT 웹훅/트리거 |
| 피크 알림 | **기본: 서버 FCM** (`send-peak-push` cron). 앱 종료 시에도 최신 매장 반영 |
| 로컬 zonedSchedule | 어드민 **「피크 로컬 예약」** ON일 때만 (`peak_local_schedule_enabled`) |
| config_refresh data-only | `send-config-refresh` + 어드민 「설정 전파」버튼. 포그라운드에서 로컬 스케줄 재동기화 |
| 설정 UI | 앱 `push_notification_settings_screen` (점심/저녁/커뮤니티) + **어드민 푸시 탭 전체 통제** |
| 지도 클러스터링 | 파트너 커밋 그대로 유지 (`marker_clustering` 등) |

배포 SQL 순서: `fcm_push.sql` → `admin_push_control.sql`  
가이드: `docs/FCM_PUSH_SETUP.md`

