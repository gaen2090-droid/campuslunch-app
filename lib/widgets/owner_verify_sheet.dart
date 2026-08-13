import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../constants/app_colors.dart';
import '../models/restaurant.dart';
import '../providers/app_provider.dart';
import '../services/fcm_push_service.dart';
import '../services/push_notification_service.dart';

/// 사장님 인증 플로우: 가게 선택 → 사업자등록증/연락처 제출 → 심사중 안내.
/// 진입 시 기존 신청 상태(pending/rejected/approved)를 먼저 확인해 알맞은 화면을 보여준다.
class OwnerVerifyScreen extends StatefulWidget {
  const OwnerVerifyScreen({super.key});

  static Future<bool?> show(BuildContext context) {
    return Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const OwnerVerifyScreen()),
    );
  }

  @override
  State<OwnerVerifyScreen> createState() => _OwnerVerifyScreenState();
}

enum _Step { loading, pickRestaurant, form, pending, rejected }

class _OwnerVerifyScreenState extends State<OwnerVerifyScreen> {
  _Step _step = _Step.loading;
  String? _rejectReason;

  @override
  void initState() {
    super.initState();
    _loadStatus();
  }

  Future<void> _loadStatus() async {
    final app = await context.read<AppProvider>().fetchMyOwnerApplication();
    if (!mounted) return;
    final status = app?['status'] as String?;
    if (status == 'pending') {
      setState(() => _step = _Step.pending);
    } else if (status == 'rejected') {
      setState(() {
        _rejectReason = app?['reject_reason'] as String?;
        _step = _Step.rejected;
      });
    } else {
      setState(() => _step = _Step.pickRestaurant);
    }
  }

  void _onRestaurantPicked(Restaurant r) {
    setState(() {
      _pickedRestaurant = r;
      _step = _Step.form;
    });
  }

  Restaurant? _pickedRestaurant;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 18, color: Color(0xFF000000)),
          onPressed: () => Navigator.pop(context),
        ),
        titleSpacing: 0,
        title: const Text(
          '사장님 인증',
          style: TextStyle(
            fontFamily: 'Pretendard',
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: Color(0xFF000000),
            letterSpacing: -0.5,
          ),
        ),
        centerTitle: false,
      ),
      body: switch (_step) {
        _Step.loading => const Center(child: CircularProgressIndicator(color: Color(0xFF000000))),
        _Step.pickRestaurant => _RestaurantPickStep(onPicked: _onRestaurantPicked),
        _Step.form => _ApplicationFormStep(
            restaurant: _pickedRestaurant!,
            onBack: () => setState(() => _step = _Step.pickRestaurant),
            onSubmitted: () => setState(() => _step = _Step.pending),
          ),
        _Step.pending => const _StatusMessage(
            emoji: '🕓',
            title: '심사 중이에요',
            body: '제출해주신 내용을 관리자가 확인하고 있어요.\n승인되면 사장님 기능을 바로 사용할 수 있어요.',
          ),
        _Step.rejected => _RejectedStep(
            reason: _rejectReason,
            onRetry: () => setState(() => _step = _Step.pickRestaurant),
          ),
      },
    );
  }
}

class _StatusMessage extends StatelessWidget {
  final String emoji;
  final String title;
  final String body;

  const _StatusMessage({
    required this.emoji,
    required this.title,
    required this.body,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 40)),
            const SizedBox(height: 16),
            Text(
              title,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w900,
                color: Colors.black,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              body,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                height: 1.6,
                color: Colors.black,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RejectedStep extends StatelessWidget {
  final String? reason;
  final VoidCallback onRetry;

  const _RejectedStep({required this.reason, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('😔', style: TextStyle(fontSize: 40)),
                  const SizedBox(height: 16),
                  const Text(
                    '이번 신청은 반려되었어요',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: Colors.black),
                  ),
                  if (reason != null && reason!.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Text(
                      '사유: $reason',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, height: 1.6, color: Colors.black),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: GestureDetector(
            onTap: onRetry,
            child: Container(
              height: 56,
              decoration: BoxDecoration(
                color: AppColors.primaryCta,
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Center(
                child: Text(
                  '다시 신청하기',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: Colors.white),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _RestaurantPickStep extends StatefulWidget {
  final void Function(Restaurant) onPicked;
  const _RestaurantPickStep({required this.onPicked});

  @override
  State<_RestaurantPickStep> createState() => _RestaurantPickStepState();
}

class _RestaurantPickStepState extends State<_RestaurantPickStep> {
  final _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final all = context.watch<AppProvider>().restaurants;
    final unclaimed = all.where((r) => r.ownerId == null).toList();
    final query = _searchCtrl.text.trim().toLowerCase();
    final results = query.isEmpty
        ? unclaimed
        : unclaimed.where((r) => r.name.toLowerCase().contains(query)).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '인증할 매장을 선택해주세요.',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: Color(0xFF000000)),
              ),
              const SizedBox(height: 4),
              const Text(
                '이미 사장님이 등록된 매장은 목록에 나오지 않아요.',
                style: TextStyle(fontSize: 12, color: Color(0xFF9CA3AF)),
              ),
              const SizedBox(height: 12),
              Container(
                height: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFFF3F4F6),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const SizedBox(width: 12),
                    const Icon(Icons.search, size: 18, color: Color(0xFF9CA3AF)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _searchCtrl,
                        onChanged: (_) => setState(() {}),
                        decoration: const InputDecoration(
                          hintText: '매장명 검색',
                          border: InputBorder.none,
                          isDense: true,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: results.isEmpty
              ? const Center(
                  child: Text('검색 결과가 없어요.', style: TextStyle(color: Color(0xFF9CA3AF))),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  itemCount: results.length,
                  itemBuilder: (context, i) {
                    final r = results[i];
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(r.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                      subtitle: Text(
                        r.area == r.category ? r.area : '${r.area} · ${r.category}',
                        style: const TextStyle(fontSize: 12, color: Color(0xFF9CA3AF)),
                      ),
                      trailing: const Icon(Icons.chevron_right, color: Color(0xFFD1D5DB)),
                      onTap: () => widget.onPicked(r),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _PickedLicenseImage {
  final Uint8List bytes;
  final String ext;
  const _PickedLicenseImage({required this.bytes, required this.ext});
}

class _ApplicationFormStep extends StatefulWidget {
  final Restaurant restaurant;
  final VoidCallback onBack;
  final VoidCallback onSubmitted;

  const _ApplicationFormStep({
    required this.restaurant,
    required this.onBack,
    required this.onSubmitted,
  });

  @override
  State<_ApplicationFormStep> createState() => _ApplicationFormStepState();
}

class _ApplicationFormStepState extends State<_ApplicationFormStep> {
  static const _maxImages = 3;
  final _phoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final List<_PickedLicenseImage> _images = [];
  bool _submitting = false;
  String? _error;
  bool _notifyPush = false;
  bool _notifySms = false;
  bool _requestingPushPermission = false;
  String? _pushPermissionDeniedNotice;

  static final _emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  @override
  void dispose() {
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    super.dispose();
  }

  Future<void> _toggleNotifyPush(bool value) async {
    if (!value) {
      setState(() {
        _notifyPush = false;
        _pushPermissionDeniedNotice = null;
      });
      return;
    }

    setState(() {
      _requestingPushPermission = true;
      _pushPermissionDeniedNotice = null;
    });
    var granted = false;
    try {
      granted = await PushNotificationService.instance.requestPermission();
      if (granted) {
        await FcmPushService.instance.requestPermissionAndRegister();
      }
    } catch (_) {
      granted = false;
    }
    if (!mounted) return;
    setState(() {
      _requestingPushPermission = false;
      _notifyPush = granted;
      _pushPermissionDeniedNotice =
          granted ? null : '알림 권한이 꺼져 있어 앱 푸시를 받을 수 없어요.\n기기 설정에서 알림을 허용해주세요.';
    });
  }

  Future<void> _pickImages() async {
    if (_images.length >= _maxImages) return;
    final remaining = _maxImages - _images.length;
    final picker = ImagePicker();
    final List<XFile> picked;
    if (remaining == 1) {
      final single = await picker.pickImage(source: ImageSource.gallery);
      picked = single == null ? const [] : [single];
    } else {
      picked = await picker.pickMultiImage(limit: remaining);
    }
    if (picked.isEmpty) return;
    final loaded = <_PickedLicenseImage>[];
    for (final file in picked.take(remaining)) {
      final bytes = await file.readAsBytes();
      final ext = file.name.contains('.') ? file.name.split('.').last : 'jpg';
      loaded.add(_PickedLicenseImage(bytes: bytes, ext: ext));
    }
    if (!mounted) return;
    setState(() => _images.addAll(loaded));
  }

  void _removeImage(int index) => setState(() => _images.removeAt(index));

  bool get _canSubmit =>
      _phoneCtrl.text.trim().isNotEmpty &&
      _emailRegex.hasMatch(_emailCtrl.text.trim()) &&
      _images.isNotEmpty &&
      !_submitting;

  Future<void> _submit() async {
    if (!_canSubmit) return;
    setState(() {
      _submitting = true;
      _error = null;
    });

    final provider = context.read<AppProvider>();
    try {
      final paths = <String>[];
      for (final img in _images) {
        paths.add(await provider.uploadOwnerLicenseImage(img.bytes, img.ext));
      }
      final err = await provider.submitOwnerApplication(
        restaurantId: widget.restaurant.id,
        phone: _phoneCtrl.text.trim(),
        email: _emailCtrl.text.trim(),
        licensePaths: paths,
        notifyPush: _notifyPush,
        notifySms: _notifySms,
      );
      if (!mounted) return;
      if (err != null) {
        setState(() {
          _error = err;
          _submitting = false;
        });
        return;
      }
      widget.onSubmitted();
    } catch (e) {
      debugPrint('[OwnerVerify] submit failed: $e');
      if (!mounted) return;
      setState(() {
        _error = '제출 중 오류가 발생했어요. 다시 시도해주세요.';
        _submitting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(20, 16, 20, MediaQuery.of(context).padding.bottom + 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              IconButton(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: widget.onBack,
                icon: const Icon(Icons.arrow_back, size: 18, color: Color(0xFF9CA3AF)),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  widget.restaurant.name,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Color(0xFF000000)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Text('사업자등록증', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: Color(0xFF000000))),
          const SizedBox(height: 4),
          const Text('최대 3장까지 첨부할 수 있어요.', style: TextStyle(fontSize: 12, color: Color(0xFF9CA3AF))),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (var i = 0; i < _images.length; i++)
                Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.memory(_images[i].bytes, width: 84, height: 84, fit: BoxFit.cover),
                    ),
                    Positioned(
                      top: 4,
                      right: 4,
                      child: GestureDetector(
                        onTap: () => _removeImage(i),
                        child: Container(
                          padding: const EdgeInsets.all(2),
                          decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                          child: const Icon(Icons.close, size: 14, color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                ),
              if (_images.length < _maxImages)
                GestureDetector(
                  onTap: _pickImages,
                  child: Container(
                    width: 84,
                    height: 84,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF9FAFB),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE5E7EB)),
                    ),
                    child: const Icon(Icons.add_a_photo_outlined, color: Color(0xFF9CA3AF)),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 20),
          const Text('전화번호', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: Color(0xFF000000))),
          const SizedBox(height: 8),
          TextField(
            controller: _phoneCtrl,
            keyboardType: TextInputType.phone,
            textInputAction: TextInputAction.next,
            onChanged: (_) => setState(() {}),
            decoration: _fieldDecoration('010-1234-5678'),
          ),
          const SizedBox(height: 16),
          const Text('이메일', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: Color(0xFF000000))),
          const SizedBox(height: 8),
          TextField(
            controller: _emailCtrl,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.done,
            onEditingComplete: () =>
                FocusManager.instance.primaryFocus?.unfocus(),
            onChanged: (_) => setState(() {}),
            decoration: _fieldDecoration('example@email.com'),
          ),
          const SizedBox(height: 20),
          const Text(
            '승인되면 알림을 보내드릴게요!',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: Color(0xFF000000)),
          ),
          const SizedBox(height: 10),
          _NotifyMethodCheckbox(
            label: '앱 푸시로 받기',
            checked: _notifyPush,
            loading: _requestingPushPermission,
            onChanged: _toggleNotifyPush,
          ),
          const SizedBox(height: 8),
          _NotifyMethodCheckbox(
            label: '문자로 받기',
            checked: _notifySms,
            onChanged: (v) => setState(() => _notifySms = v),
          ),
          if (_pushPermissionDeniedNotice != null) ...[
            const SizedBox(height: 8),
            Text(
              _pushPermissionDeniedNotice!,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFFEF4444), height: 1.4),
            ),
          ],
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFFEF4444))),
          ],
          const SizedBox(height: 24),
          Opacity(
            opacity: _canSubmit ? 1.0 : 0.4,
            child: GestureDetector(
              onTap: _canSubmit ? _submit : null,
              child: Container(
                height: 56,
                decoration: BoxDecoration(
                  color: AppColors.primaryCta,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Center(
                  child: _submitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : const Text(
                          '제출하기',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: Colors.white),
                        ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration _fieldDecoration(String hint) => InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Color(0xFFD1D5DB)),
        filled: true,
        fillColor: const Color(0xFFF9FAFB),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFF000000), width: 1.5),
        ),
      );
}

class _NotifyMethodCheckbox extends StatelessWidget {
  final String label;
  final bool checked;
  final bool loading;
  final ValueChanged<bool> onChanged;

  const _NotifyMethodCheckbox({
    required this.label,
    required this.checked,
    this.loading = false,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: loading ? null : () => onChanged(!checked),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: checked ? const Color(0xFFF3F4F6) : const Color(0xFFF9FAFB),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: checked ? AppColors.primaryCta : const Color(0xFFE5E7EB),
          ),
        ),
        child: Row(
          children: [
            if (loading)
              const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF000000)),
              )
            else
              Icon(
                checked ? Icons.check_box : Icons.check_box_outline_blank,
                size: 20,
                color: checked ? AppColors.primaryCta : const Color(0xFF9CA3AF),
              ),
            const SizedBox(width: 10),
            Text(
              label,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF000000)),
            ),
          ],
        ),
      ),
    );
  }
}
