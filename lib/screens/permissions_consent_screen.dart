import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../constants/app_colors.dart';
import '../constants/app_permissions.dart';
import '../providers/app_provider.dart';
import '../widgets/consent_checklist.dart';
import 'permission_document_screen.dart';

/// 첫 앱 실행 시 — 기기 권한 안내 (OS 권한은 확인 버튼 시점)
class PermissionsConsentScreen extends StatefulWidget {
  const PermissionsConsentScreen({super.key});

  @override
  State<PermissionsConsentScreen> createState() =>
      _PermissionsConsentScreenState();
}

class _PermissionsConsentScreenState extends State<PermissionsConsentScreen> {
  bool _loading = false;
  late Map<String, bool> _agreed;

  @override
  void initState() {
    super.initState();
    _agreed = {
      for (final card in AppPermissions.permissionCards) card.id: false,
    };
  }

  List<ConsentCheckItem> get _checkItems => AppPermissions.permissionCards
      .map(
        (card) => ConsentCheckItem(
          id: card.id,
          label: card.title,
          required: card.required,
          subtitle: card.subtitle,
        ),
      )
      .toList();

  bool get _canProceed => AppPermissions.permissionCards
      .where((card) => card.required)
      .every((card) => _agreed[card.id] == true);

  void _openDocument(String id) {
    final card = AppPermissions.permissionCards
        .where((c) => c.id == id)
        .firstOrNull;
    if (card == null) return;
    PermissionDocumentScreen.open(
      context,
      title: card.title,
      body: card.documentBody,
      fullDocumentAssetPath: card.documentAssetPath,
      fullDocumentLinkLabel: card.documentLinkLabel,
    );
  }

  Future<void> _confirm() async {
    if (_loading || !_canProceed) return;
    setState(() => _loading = true);

    try {
      await context.read<AppProvider>().completePermissionsConsent(
            requestLocation: _agreed['location'] == true,
          );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final canProceed = _canProceed && !_loading;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 36, 24, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      AppPermissions.introTitle,
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF000000),
                        letterSpacing: -0.8,
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: 24),
                    ConsentChecklist(
                      agreeAllLabel: AppPermissions.agreeAllLabel,
                      items: _checkItems,
                      agreed: _agreed,
                      onChanged: (next) => setState(() => _agreed = next),
                      onViewDocument: _openDocument,
                    ),
                  ],
                ),
              ),
            ),
            _BottomBar(
              loading: _loading,
              canConfirm: canProceed,
              onConfirm: _confirm,
            ),
          ],
        ),
      ),
    );
  }
}

class _BottomBar extends StatelessWidget {
  const _BottomBar({
    required this.loading,
    required this.canConfirm,
    required this.onConfirm,
  });

  final bool loading;
  final bool canConfirm;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
      child: Column(
        children: [
          if (!canConfirm && !loading) ...[
            const Text(
              '필수 권한에 모두 동의해야 합니다.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11,
                color: Color(0xFFEF4444),
                height: 1.5,
              ),
            ),
            const SizedBox(height: 12),
          ],
          GestureDetector(
            onTap: canConfirm ? onConfirm : null,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              height: 56,
              decoration: BoxDecoration(
                color: canConfirm
                    ? AppColors.primaryCta
                    : const Color(0xFFE5E7EB),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Center(
                child: loading
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(
                        AppPermissions.confirmLabel,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          color: canConfirm ? Colors.white : const Color(0xFF9CA3AF),
                        ),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
