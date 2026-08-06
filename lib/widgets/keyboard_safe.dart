import 'package:flutter/material.dart';

/// [base] 패딩에 키보드 높이를 더해 스크롤 폼 overflow 를 방지한다.
EdgeInsetsGeometry keyboardAwarePadding(
  BuildContext context,
  EdgeInsetsGeometry base,
) {
  return base.add(EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom));
}

/// 탭·드래그 시 키보드를 닫는 스크롤 래퍼.
class KeyboardDismissScroll extends StatelessWidget {
  const KeyboardDismissScroll({
    super.key,
    required this.child,
    this.padding = EdgeInsets.zero,
    this.physics,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final ScrollPhysics? physics;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
      behavior: HitTestBehavior.translucent,
      child: SingleChildScrollView(
        physics: physics,
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: padding.add(
          EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
        ),
        child: child,
      ),
    );
  }
}

/// 숫자 키패드 등 키보드에 완료가 없을 때, 키보드 바로 위에 표시한다.
/// [Stack]의 자식으로 둔다.
class KeyboardDoneBar extends StatelessWidget {
  const KeyboardDoneBar({super.key});

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    if (bottom <= 0) return const SizedBox.shrink();

    return Positioned(
      left: 0,
      right: 0,
      bottom: bottom,
      child: Material(
        elevation: 1,
        color: const Color(0xFFF2F2F7),
        child: SizedBox(
          height: 44,
          child: Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () => FocusManager.instance.primaryFocus?.unfocus(),
              child: const Text(
                '완료',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF007AFF),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
