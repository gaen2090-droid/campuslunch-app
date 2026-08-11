import 'package:campus_lunch/utils/korean_particle.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('받침 없는 이름 → 는', () {
    expect(eunNeun('터방내'), '는');
    expect(eunNeun('맘스터치'), '는');
  });

  test('받침 있는 이름 → 은', () {
    expect(eunNeun('김밥천국'), '은');
    expect(eunNeun('맛있는집'), '은');
  });

  test('한글이 아닌 이름 → 기본값 는', () {
    expect(eunNeun('BBQ'), '는');
    expect(eunNeun(''), '는');
  });
}
