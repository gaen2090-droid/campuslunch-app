import 'package:flutter/material.dart';

/// 코치마크 한 스텝의 정의 — 가리킬 대상(key 후보들)과 말풍선 문구
/// targetKeys는 우선순위 순서. 화면에 실제로 존재하는(마운트된) 첫 번째 key를 사용한다.
/// 예: "화면에 뜨는 첫 카드"처럼 상황에 따라 다른 위젯이 나타날 수 있는 경우 후보를 여러 개 넣는다.
class CoachMarkStep {
  final List<GlobalKey> targetKeys;
  final String title;
  final String subtitle;
  /// 스포트라이트 모양: 사각형(둥근 모서리) or 원형(아이콘 버튼용)
  final bool circleShape;

  const CoachMarkStep({
    required this.targetKeys,
    required this.title,
    required this.subtitle,
    this.circleShape = false,
  });
}
