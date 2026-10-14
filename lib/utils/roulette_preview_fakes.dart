import '../models/restaurant.dart';

// ─────────────────────────────────────────────────────────────────────────
// 임시 미리보기용 가짜 매장. 룰렛 화면을 영업 중인 매장이 적은 시간대에도 확인하려고
// 디버그 빌드에서만 룰렛 후보에 섞어 넣는다 (운영 DB에는 아무것도 쓰지 않는다).
//
// 지울 때: 이 파일을 삭제하고 lunch_roulette_screen.dart 의 `_all` getter에서
// `rouletteFakeStores` 사용 부분(그리고 import)을 제거하면 된다.
// ─────────────────────────────────────────────────────────────────────────

/// false로 바꾸면 디버그 빌드에서도 가짜 매장을 넣지 않는다.
const bool kRoulettePreviewFakes = false;

Restaurant _fake(
  String name,
  String category,
  String area, {
  bool freshRelaxed = false,
  bool freshBusy = false,
  List<String> signatures = const [],
}) {
  final now = DateTime.now();
  final fresh = freshRelaxed || freshBusy;
  return Restaurant(
    id: 'fake-$name',
    name: name,
    category: category,
    area: area,
    address: '(테스트 데이터)',
    status: freshRelaxed ? '여유로움' : (freshBusy ? '약간혼잡' : '제보필요'),
    updated: fresh ? 3 : 0,
    imageUrl: '',
    distance: 200,
    latitude: 37.50699,
    longitude: 126.95707,
    x: 0,
    y: 0,
    hours: '00:00 - 23:59',
    reports: const {},
    menu: const [],
    hasCrowdUpdate: fresh,
    updatedAt: fresh ? now.subtract(const Duration(minutes: 3)) : null,
    crowdEnabled: true,
    signatureMenus: signatures,
  );
}

/// 영업 중인 가짜 매장. 한식·일식·중식은 넉넉하고, 양식·분식·아시아는 일부러 적게 둬서
/// "매장 수 부족" 안내(3~7곳 / 2곳 이하)도 확인할 수 있다.
List<Restaurant> rouletteFakeStores() => [
      _fake('[테스트] 한식집 A', '한식', '정문',
          freshRelaxed: true, signatures: ['김치찌개', '제육볶음']),
      _fake('[테스트] 한식집 B', '한식', '정문', freshRelaxed: true),
      _fake('[테스트] 한식집 C', '한식', '후문'),
      _fake('[테스트] 한식집 D', '한식', '후문', freshBusy: true),
      _fake('[테스트] 일식집 A', '일식', '정문', freshRelaxed: true),
      _fake('[테스트] 일식집 B', '일식', '중문'),
      _fake('[테스트] 일식집 C', '일식', '후문'),
      _fake('[테스트] 중식집 A', '중식', '정문', freshRelaxed: true),
      _fake('[테스트] 중식집 B', '중식', '후문'),
      _fake('[테스트] 양식집 A', '양식', '정문'),
      _fake('[테스트] 양식집 B', '양식', '중문'),
      _fake('[테스트] 분식집 A', '분식', '후문'),
      _fake('[테스트] 아시아 식당 A', '아시아', '정문'),
    ];
