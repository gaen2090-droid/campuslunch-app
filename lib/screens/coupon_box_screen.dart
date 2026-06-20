import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/reward.dart';
import '../providers/app_provider.dart';
import 'gifticon_detail_screen.dart';

class CouponBoxScreen extends StatefulWidget {
  const CouponBoxScreen({super.key});

  @override
  State<CouponBoxScreen> createState() => _CouponBoxScreenState();
}

class _CouponBoxScreenState extends State<CouponBoxScreen> {
  bool _editMode = false;
  final Set<String> _removingIds = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AppProvider>().fetchMyReward();
    });
  }

  bool _isExpired(Gifticon g) {
    if (g.expiresAt == null) return false;
    return g.expiresAt!.isBefore(DateTime.now());
  }

  void _openDetail(Gifticon g) {
    if (_editMode) return;
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => GifticonDetailScreen(gifticon: g)),
    );
  }

  Future<void> _removeGifticon(Gifticon g) async {
    if (_removingIds.contains(g.id)) return;
    setState(() => _removingIds.add(g.id));

    final err = await context.read<AppProvider>().removeGifticonFromBox(g);
    if (!mounted) return;

    setState(() => _removingIds.remove(g.id));
    if (err != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
      return;
    }
    if (_editMode && context.read<AppProvider>().visibleMyGifticons.isEmpty) {
      setState(() => _editMode = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final gifticons = provider.visibleMyGifticons;
    final usable = gifticons
        .where((g) => g.status == 'assigned' && !_isExpired(g))
        .toList();
    final used = gifticons.where((g) => g.status == 'used').toList();
    final expired = gifticons
        .where((g) => g.status == 'assigned' && _isExpired(g))
        .toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF3F8F0),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF3F8F0),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 18, color: Color(0xFF111827)),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          '쿠폰함',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w900,
            color: Color(0xFF5E8C4A),
            letterSpacing: -0.5,
          ),
        ),
        centerTitle: false,
        actions: [
          if (gifticons.isNotEmpty)
            TextButton(
              onPressed: () => setState(() => _editMode = !_editMode),
              child: Text(
                _editMode ? '완료' : '편집',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFFEF4444),
                ),
              ),
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => provider.fetchMyReward(),
        color: const Color(0xFF5E8C4A),
        child: gifticons.isEmpty
            ? ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  SizedBox(height: MediaQuery.of(context).size.height * 0.25),
                  const Center(
                    child: Column(
                      children: [
                        Text('🎁', style: TextStyle(fontSize: 40)),
                        SizedBox(height: 12),
                        Text(
                          '아직 받은 쿠폰이 없어요.',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF9CA3AF),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              )
            : ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.fromLTRB(
                  20,
                  12,
                  20,
                  MediaQuery.of(context).padding.bottom + 32,
                ),
                children: [
                  if (_editMode)
                    const Padding(
                      padding: EdgeInsets.only(bottom: 12),
                      child: Text(
                        '삭제할 쿠폰을 선택하세요.',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF6B7280),
                        ),
                      ),
                    ),
                  if (usable.isNotEmpty) ...[
                    ...usable.map(
                      (g) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _GifticonCard(
                          gifticon: g,
                          expired: false,
                          editMode: _editMode,
                          removing: _removingIds.contains(g.id),
                          onView: () => _openDetail(g),
                          onRemove: () => _removeGifticon(g),
                        ),
                      ),
                    ),
                  ],
                  if (used.isNotEmpty) ...[
                    if (usable.isNotEmpty) const SizedBox(height: 12),
                    Text(
                      '사용 완료 (${used.length})',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF9CA3AF),
                      ),
                    ),
                    const SizedBox(height: 12),
                    ...used.map(
                      (g) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _GifticonCard(
                          gifticon: g,
                          expired: true,
                          editMode: _editMode,
                          removing: _removingIds.contains(g.id),
                          onView: () => _openDetail(g),
                          onRemove: () => _removeGifticon(g),
                        ),
                      ),
                    ),
                  ],
                  if (expired.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text(
                      '만료됨 (${expired.length})',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF9CA3AF),
                      ),
                    ),
                    const SizedBox(height: 12),
                    ...expired.map(
                      (g) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _GifticonCard(
                          gifticon: g,
                          expired: true,
                          editMode: _editMode,
                          removing: _removingIds.contains(g.id),
                          onView: () => _openDetail(g),
                          onRemove: () => _removeGifticon(g),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
      ),
    );
  }
}

class _GifticonCard extends StatelessWidget {
  final Gifticon gifticon;
  final bool expired;
  final bool editMode;
  final bool removing;
  final VoidCallback onView;
  final VoidCallback onRemove;

  const _GifticonCard({
    required this.gifticon,
    required this.expired,
    required this.editMode,
    required this.removing,
    required this.onView,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: expired ? 0.5 : 1.0,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFE5E7EB)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(6),
              blurRadius: 6,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Row(
          children: [
            if (editMode) ...[
              GestureDetector(
                onTap: removing ? null : onRemove,
                child: Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEE2E2),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: removing
                      ? const Padding(
                          padding: EdgeInsets.all(6),
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Color(0xFFEF4444),
                          ),
                        )
                      : const Icon(Icons.remove, size: 18, color: Color(0xFFEF4444)),
                ),
              ),
              const SizedBox(width: 12),
            ],
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: const Color(0xFFFFFBEB),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Center(child: Text('🎁', style: TextStyle(fontSize: 24))),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    gifticon.productName,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF111827),
                    ),
                  ),
                  const SizedBox(height: 4),
                  if (gifticon.expiresLabel.isNotEmpty)
                    Text(
                      expired
                          ? '유효기간 만료 (${gifticon.expiresLabel})'
                          : '유효기간 ${gifticon.expiresLabel}',
                      style: TextStyle(
                        fontSize: 11,
                        color: expired
                            ? const Color(0xFFEF4444)
                            : const Color(0xFF9CA3AF),
                      ),
                    ),
                ],
              ),
            ),
            if (!editMode) ...[
              const SizedBox(width: 10),
              GestureDetector(
                onTap: expired ? null : onView,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF3F8F0),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFBFE0B0)),
                  ),
                  child: const Text(
                    '쿠폰 보기',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF5E8C4A),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
