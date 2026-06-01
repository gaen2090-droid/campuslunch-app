import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';

Future<void> showLocationPermissionDialog(BuildContext context, {VoidCallback? onGranted}) {
  return showDialog(
    context: context,
    barrierColor: const Color(0x59000000),
    barrierDismissible: true,
    builder: (ctx) {
      final provider = ctx.read<AppProvider>();
      void grant() {
        Navigator.pop(ctx);
        provider.enableLocation();
        onGranted?.call();
      }
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Material(
            color: Colors.transparent,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(26),
                boxShadow: const [
                  BoxShadow(color: Color(0x40000000), blurRadius: 40),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Padding(
                    padding: EdgeInsets.fromLTRB(24, 28, 24, 20),
                    child: Text(
                      '캠퍼스런치가 사용자의 위치에\n접근하도록 허용하시겠습니까?',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                        height: 1.45,
                        color: Color(0xFF111827),
                      ),
                    ),
                  ),
                  const Divider(height: 1, color: Color(0xFFE5E7EB)),
                  _PermBtn(label: '앱을 사용하는 동안 허용', onTap: grant),
                  const Divider(height: 1, color: Color(0xFFE5E7EB)),
                  _PermBtn(label: '한 번 허용', onTap: grant),
                  const Divider(height: 1, color: Color(0xFFE5E7EB)),
                  _PermBtn(label: '허용 안 함', onTap: () => Navigator.pop(ctx)),
                ],
              ),
            ),
          ),
        ),
      );
    },
  );
}

class LocationPermissionScreen extends StatelessWidget {
  const LocationPermissionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.read<AppProvider>();

    return Scaffold(
      backgroundColor: const Color(0x59000000),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(26),
              boxShadow: const [
                BoxShadow(color: Color(0x40000000), blurRadius: 40),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 제목
                const Padding(
                  padding: EdgeInsets.fromLTRB(24, 28, 24, 20),
                  child: Text(
                    '캠퍼스런치가 사용자의 위치에\n접근하도록 허용하시겠습니까?',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                      height: 1.45,
                      color: Color(0xFF111827),
                    ),
                  ),
                ),

                // 버튼 목록
                const Divider(height: 1, color: Color(0xFFE5E7EB)),
                _PermBtn(
                  label: '앱을 사용하는 동안 허용',
                  onTap: () => provider.setLocationMode(true),
                ),
                const Divider(height: 1, color: Color(0xFFE5E7EB)),
                _PermBtn(
                  label: '한 번 허용',
                  onTap: () => provider.setLocationMode(true),
                ),
                const Divider(height: 1, color: Color(0xFFE5E7EB)),
                _PermBtn(
                  label: '허용 안 함',
                  onTap: () => provider.setLocationMode(false),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PermBtn extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _PermBtn({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: double.infinity,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w600,
              color: Color(0xFF3B82F6),
            ),
          ),
        ),
      ),
    );
  }
}
