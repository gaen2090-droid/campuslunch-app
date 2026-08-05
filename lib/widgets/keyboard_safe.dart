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

/// iOS 숫자 키패드에는 Done이 없어, 필드에서 키보드를 닫을 수 있게 한다.
Widget keyboardHideButton() {
  return IconButton(
    tooltip: '키보드 닫기',
    icon: const Icon(
      Icons.keyboard_hide_outlined,
      size: 20,
      color: Color(0xFF6B7280),
    ),
    onPressed: () => FocusManager.instance.primaryFocus?.unfocus(),
  );
}
