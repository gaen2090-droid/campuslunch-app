import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/reward.dart';
import '../providers/app_provider.dart';
import '../services/supabase_service.dart';

class CouponBoxScreen extends StatefulWidget {
  const CouponBoxScreen({super.key});

  @override
  State<CouponBoxScreen> createState() => _CouponBoxScreenState();
}

class _CouponBoxScreenState extends State<CouponBoxScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AppProvider>().fetchMyReward();
    });
  }

  void _showGifticonDetail(Gifticon g) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _GifticonDetailSheet(gifticon: g),
    );
  }

  bool _isExpired(Gifticon g) {
    if (g.expiresAt == null) return false;
    return g.expiresAt!.isBefore(DateTime.now());
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final gifticons = provider.myGifticons;
    final active = gifticons.where((g) => !_isExpired(g)).toList();
    final expired = gifticons.where(_isExpired).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF0FDF4),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF0FDF4),
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
            color: Color(0xFF16A34A),
            letterSpacing: -0.5,
          ),
        ),
        centerTitle: false,
      ),
      body: RefreshIndicator(
        onRefresh: () => provider.fetchMyReward(),
        color: const Color(0xFF16A34A),
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
                padding: EdgeInsets.fromLTRB(20, 12, 20, MediaQuery.of(context).padding.bottom + 32),
                children: [
                  if (active.isNotEmpty) ...[
                    ...active.map(
                      (g) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _GifticonCard(
                          gifticon: g,
                          expired: false,
                          onView: () => _showGifticonDetail(g),
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
                          onView: () => _showGifticonDetail(g),
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
  final VoidCallback onView;

  const _GifticonCard({required this.gifticon, required this.expired, required this.onView});

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
            BoxShadow(color: Colors.black.withAlpha(6), blurRadius: 6, offset: const Offset(0, 1)),
          ],
        ),
        child: Row(
          children: [
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
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: Color(0xFF111827)),
                  ),
                  const SizedBox(height: 4),
                  if (gifticon.expiresLabel.isNotEmpty)
                    Text(
                      expired ? '유효기간 만료 (${gifticon.expiresLabel})' : '유효기간 ${gifticon.expiresLabel}',
                      style: TextStyle(
                        fontSize: 11,
                        color: expired ? const Color(0xFFEF4444) : const Color(0xFF9CA3AF),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            GestureDetector(
              onTap: expired ? null : onView,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0FDF4),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF86EFAC)),
                ),
                child: const Text(
                  '쿠폰 보기',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: Color(0xFF16A34A)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GifticonDetailSheet extends StatefulWidget {
  final Gifticon gifticon;
  const _GifticonDetailSheet({required this.gifticon});

  @override
  State<_GifticonDetailSheet> createState() => _GifticonDetailSheetState();
}

class _GifticonDetailSheetState extends State<_GifticonDetailSheet> {
  String? _freshImageUrl;
  bool _loadingUrl = true;

  @override
  void initState() {
    super.initState();
    _refreshImageUrl();
  }

  Future<void> _refreshImageUrl() async {
    final raw = widget.gifticon.imageUrl;
    if (raw.isEmpty) {
      setState(() { _freshImageUrl = ''; _loadingUrl = false; });
      return;
    }
    if (!raw.startsWith('http') && SupabaseService.isReady) {
      try {
        final url = await SupabaseService.client.storage
            .from('gifticons')
            .createSignedUrl(raw, 3600);
        if (mounted) setState(() { _freshImageUrl = url; _loadingUrl = false; });
        return;
      } catch (_) {}
    }
    if (mounted) setState(() { _freshImageUrl = raw; _loadingUrl = false; });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.fromLTRB(12, 0, 12, MediaQuery.of(context).padding.bottom + 12),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.all(Radius.circular(28)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 6,
                decoration: BoxDecoration(
                  color: const Color(0xFFE5E7EB),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              widget.gifticon.brand,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF9CA3AF)),
            ),
            const SizedBox(height: 4),
            Text(
              widget.gifticon.productName,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Color(0xFF111827)),
            ),
            const SizedBox(height: 6),
            if (widget.gifticon.expiresLabel.isNotEmpty)
              Text(
                '유효기간 ${widget.gifticon.expiresLabel}',
                style: const TextStyle(fontSize: 13, color: Color(0xFF9CA3AF)),
              ),
            const SizedBox(height: 20),
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: _loadingUrl
                  ? const SizedBox(
                      width: double.infinity,
                      height: 200,
                      child: Center(child: CircularProgressIndicator(color: Color(0xFF16A34A))),
                    )
                  : (_freshImageUrl?.isNotEmpty == true
                      ? Image.network(
                          _freshImageUrl!,
                          width: double.infinity,
                          height: 260,
                          fit: BoxFit.contain,
                          errorBuilder: (_, __, ___) => _imageError(),
                        )
                      : _imageError()),
            ),
            const SizedBox(height: 20),
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF3F4F6),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Center(
                  child: Text(
                    '닫기',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: Color(0xFF374151)),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _imageError() => Container(
    width: double.infinity,
    height: 200,
    decoration: BoxDecoration(
      color: const Color(0xFFF3F4F6),
      borderRadius: BorderRadius.circular(16),
    ),
    child: const Center(
      child: Text('이미지를 불러올 수 없어요', style: TextStyle(color: Color(0xFF9CA3AF))),
    ),
  );
}
