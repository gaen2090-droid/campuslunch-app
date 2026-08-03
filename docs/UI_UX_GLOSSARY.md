# 캠퍼스런치 UI/UX 용어 정리

참고: [UI/UX 디자인 용어 정리](https://uiuxloveself.tistory.com/3)

일반적인 UI/UX 용어를 캠퍼스런치 앱 코드에서 실제로 어떻게 부르고, 어디에 구현되어 있는지 정리한 문서.
팀 내 커뮤니케이션(기획/디자인/개발) 시 같은 대상을 가리키는 용어를 통일하는 목적.

## UX 용어

| 용어 | 정의 | 이 앱에서의 대응 |
|---|---|---|
| 와이어프레임 | 색상 없이 레이아웃 뼈대만 잡는 설계 단계 | 별도 산출물 없음 (기획 단계 참고용 용어) |
| 스토리보드 | 작업 과정을 최종 확인하는 기획 문서 | `docs/PLAN_*.md` 문서들이 유사 역할 |
| 플로우차트 | 서비스 동작 흐름을 시각화한 것 | 별도 산출물 없음 |
| 목업 | 디자인을 이미지로 시뮬레이션하는 단계 | 피그마 등 외부 툴 사용 (코드 외 영역) |
| 프로토타입 | 기능 테스트용 시뮬레이션 모형 | 디버그 빌드가 이 역할을 겸함 |
| 유저빌리티(사용성) | 사용자가 얼마나 쉽게 쓸 수 있는가 | 코치마크, 온보딩 안내로 개선 시도 |
| 어포던스 | 특정 행동을 유도하는 디자인 | 필터칩 활성/비활성 색상, CTA 버튼 등 |
| 반응형 | 화면 크기에 따라 레이아웃이 자동으로 변함 | `lib/main.dart`의 393pt 기준 텍스트 스케일 보정 |
| 적응형 | 웹/모바일용 화면을 별도 제작 | 해당 없음 (단일 Flutter 코드베이스) |
| 네이티브앱 | OS별로 각각 제작된 앱 | 이 앱의 형태 (Flutter → iOS/Android 네이티브 빌드) |
| 하이브리드앱 | 웹 기반으로 여러 OS 대응 | 해당 없음 |
| 모바일 웹앱 | 브라우저 기반, 다운로드 불필요 | `admin-web`, `share-web`, `legal-site`가 이 형태 |
| AB 테스트 | 사용자 선호도 비교 테스트 | 별도 인프라 없음 |
| 뎁스(depth) | 사이트 계층 구조 단위 | 홈(1뎁스) → 상세(2뎁스) → 리뷰/제보(3뎁스) 등 |
| 디자인 QA | 구현된 화면이 디자인대로 동작하는지 검증 | `/run` 스킬로 실기기 확인하는 과정이 이에 해당 |

## UI 용어 — 앱 코드 매칭

| 용어 | 정의 | 존재 | 이 앱에서의 이름/위치 |
|---|---|---|---|
| 헤더 | 상단 로고·메뉴·검색창 영역 | 존재 | 각 화면 상단 커스텀 헤더 (예: `home_screen.dart` 검색바 영역) |
| GNB (하단 내비게이션) | 최상위 메뉴 이동 영역 | 존재 | `main_screen.dart`의 `_BottomNav`/`_NavTab`. 일반 사용자: 홈·지도·커뮤니티·MY 4탭 / 사장님: 제보·매장관리·커뮤니티·MY 4탭 (Material `BottomNavigationBar` 미사용, 완전 커스텀) |
| 탭바/탭메뉴 | 한 화면 내 섹션 전환 메뉴 | 존재 | `community_screen.dart`의 `_segmentControl()` (자유게시판/맛집 컬렉션 전환). Material `TabBar` 미사용 |
| 필터칩(칩) | 선택/필터링용 알약 모양 버튼 | 존재 | `home_screen.dart`의 `HomeFilterChip`, `HomeCafeFilterChip`. Material `Chip` 미사용, 완전 커스텀 |
| 드롭다운 리스트 | 화살표 클릭 시 선택지가 내려오는 요소 | 이름만 존재 | `owner_restaurant_dropdown.dart`의 `OwnerRestaurantDropdown` — 이름은 드롭다운이지만 실제 동작은 바텀시트 |
| 셀렉트 박스 | 커스텀 제한이 있는 드롭다운 | 없음 | — |
| 라디오 버튼 / 체크박스 | 단일/다중 선택 요소 | 필터 시트 내 사용 | `home_screen.dart` 필터 시트(`_openSimpleSheet`)의 단일/다중 선택 로직 |
| 토글 | On/Off 스위치 | 없음 | Material `Switch` 미사용. 알림 설정 등은 다른 UI(버튼형)로 대체 구현 |
| 아코디언 | 클릭 시 하위 요소가 펼쳐지는 UI | 미확인 | — |
| 브레드크럼 | 현재 위치·경로 표시 | 없음 | 뎁스가 얕아 별도 구현 없음 |
| 페이징/무한스크롤 | 목록을 나눠서 불러오는 방식 | 존재 | `ScrollController` 기반 무한스크롤. `home_screen.dart`, `community_screen.dart`, `map_screen.dart`, `restaurant_list_screen.dart` 등. `PageView` 방식은 미사용 |
| 캐러셀/슬라이더 | 슬라이드쇼형 콘텐츠 표현 | 없음 | — |
| 프로그레스바/로더/스피너 | 로딩 표시 | 존재 | `CircularProgressIndicator` (`community_screen.dart`, `detail_screen.dart` 등) |
| 스켈레톤 | 로딩 중 임시 레이아웃 표시 | 없음 | shimmer 등 미도입, 스피너로 대체 |
| 툴팁 | 커서를 올리면 뜨는 정보 박스 | 존재 | `home_screen.dart`의 정보 팝업(`CompositedTransformFollower` 기반 안내창, 예: 혼잡도 설명) |
| 팝업 / 모달 | 브라우저/화면 위에 별도 레이어를 띄우는 것 | 존재 | `showDialog`/`AlertDialog` — 확인·삭제·권한 안내 등 (`settings_screen.dart`, `owner_stats_screen.dart` 등) |
| 바텀시트 | 화면 하단에서 올라오는 모달 | 존재 | `showModalBottomSheet` 다수. `report_sheet.dart`, `share_sheet.dart`, `collection_comments_sheet.dart`, `restaurant_picker_sheet.dart`, `feedback_sheet.dart` 등 |
| 토스트 팝업/스낵바 | 잠깐 뜨는 간단 메시지 | 존재 | `SnackBar` + `ScaffoldMessenger`. `report_feedback.dart`에 공용 헬퍼, 회원가입 완료 메시지 등(`main_screen.dart`) |
| 딤(Dim) | 특정 영역을 어둡게 해 주목시키는 기법 | 존재 | 코치마크의 스포트라이트 오버레이(`coach_mark_overlay.dart`)에서 배경을 어둡게 처리 |
| 코치마크 | 최초 실행 시 사용법 안내 | 존재 | `coach_mark_overlay.dart`(`CoachMarkOverlay`), `coach_mark_step.dart`. `main_screen.dart`에서 홈 화면 4단계 코치마크 실행 |
| 온보딩 | 서비스 이해를 돕는 안내 화면 | 존재 | `usage_guide_screen.dart`(일반 사용자), `owner_usage_guide_screen.dart`(사장님) |
| 스플래시 스크린 | 앱 로드 중 표시되는 이미지 | 존재 | `splash_screen.dart` — 브랜드 풀스크린 이미지, 로드 실패 시 로고만 표시하는 폴백 포함 |
| 상태바 | 시간·와이파이·배터리 표시 영역 | 존재(커스터마이징) | `main.dart`의 `SystemChrome.setSystemUIOverlayStyle` — 투명 배경 + 어두운 아이콘 |
| 검색 필드 | 검색 입력창 | 존재 | `home_screen.dart` 홈 검색바("매장명, 위치, 음식종류 검색"), `map_search_screen.dart`, `community_search_screen.dart` |
| 카드 디자인 | 콘텐츠를 사각형으로 구분해 표현 | 존재 | `restaurant_card.dart`(`RestaurantCard`), `community_post_card.dart`, `collection_restaurant_card.dart` 등 |
| 뱃지 | 알림·상태를 시각적으로 강조 | 존재 | `status_badge.dart`(`StatusBadge`, 혼잡도 상태), `circle_count_badge.dart`(보유 개수), `owner_badge.dart`(사장님 표시) |
| 엠프티 화면 | 콘텐츠가 없는 빈 화면 | 존재 | 에러 시: `load_error_view.dart`(`LoadErrorView`, 공용 위젯). 단순 빈 목록: 화면별 인라인 문구(예: "검색 결과가 없어요.") |
| 플로팅 버튼(FAB) | 다른 요소 위에 떠 있는 고정 버튼 | 없음 | — |
| CTA | 행동을 유도하는 버튼/메시지 | 존재 | 각 화면의 주요 액션 버튼("제보하기", "자세히 보기" 등) |
| 디폴트 | 기본값/초기값 | — | 예: 정렬 기본값 "최신순", 필터 기본값 "전체" |

## 특이사항 메모

- **Material 기본 위젯 대신 커스텀 구현이 많음**: 탭바, 필터칩, 드롭다운, GNB 모두 Material 기본 위젯(`TabBar`, `Chip`, `DropdownButton`, `BottomNavigationBar`)을 쓰지 않고 자체 위젯으로 구현되어 있음. 새 컴포넌트 논의 시 "Material 기본 Chip"이 아니라 "우리 앱의 `HomeFilterChip`"처럼 구체적으로 지칭할 것.
- **"드롭다운"이라는 이름이 실제 동작과 다름**: `OwnerRestaurantDropdown`은 이름과 달리 바텀시트로 열림. 헷갈리지 않도록 대화 시 "매장 선택 시트"처럼 부르는 게 명확함.
- **캐러셀/슬라이더, 스켈레톤, 플로팅 버튼, 브레드크럼, 토글 스위치는 앱에 없음**: 향후 추가 논의 시 참고.
