import 'package:flutter/material.dart';

import '../models/reward.dart';
import '../services/supabase_service.dart';
import '../utils/gifticon_image_saver.dart';

class GifticonDetailScreen extends StatefulWidget {
  final Gifticon gifticon;

  const GifticonDetailScreen({super.key, required this.gifticon});

  @override
  State<GifticonDetailScreen> createState() => _GifticonDetailScreenState();
}

class _GifticonDetailScreenState extends State<GifticonDetailScreen> {
  String? _freshImageUrl;
  bool _loadingUrl = true;
  bool _downloading = false;

  @override
  void initState() {
    super.initState();
    _refreshImageUrl();
  }

  Future<void> _refreshImageUrl() async {
    final raw = widget.gifticon.imageUrl;
    if (raw.isEmpty) {
      setState(() {
        _freshImageUrl = '';
        _loadingUrl = false;
      });
      return;
    }
    if (!raw.startsWith('http') && SupabaseService.isReady) {
      try {
        final url = await SupabaseService.client.storage
            .from('gifticons')
            .createSignedUrl(raw, 3600);
        if (mounted) {
          setState(() {
            _freshImageUrl = url;
            _loadingUrl = false;
          });
        }
        return;
      } catch (_) {}
    }
    if (mounted) {
      setState(() {
        _freshImageUrl = raw;
        _loadingUrl = false;
      });
    }
  }

  bool get _hasImage =>
      !_loadingUrl && (_freshImageUrl?.isNotEmpty == true);

  Future<void> _downloadImage() async {
    final url = _freshImageUrl;
    if (url == null || url.isEmpty || _downloading) return;

    setState(() => _downloading = true);
    String? err;
    try {
      err = await GifticonImageSaver.saveFromUrl(url);
    } finally {
      if (mounted) setState(() => _downloading = false);
    }
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          err ?? '사진 앨범에 저장했어요.',
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
        backgroundColor: err != null ? const Color(0xFF111827) : const Color(0xFF5E8C4A),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final g = widget.gifticon;
    final expired = g.expiresAt != null && g.expiresAt!.isBefore(DateTime.now());

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
          '쿠폰 보기',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w900,
            color: Color(0xFF5E8C4A),
            letterSpacing: -0.5,
          ),
        ),
        centerTitle: false,
        actions: [
          IconButton(
            onPressed: _hasImage && !_downloading ? _downloadImage : null,
            icon: _downloading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Color(0xFF5E8C4A),
                    ),
                  )
                : Icon(
                    Icons.download_rounded,
                    size: 22,
                    color: _hasImage
                        ? const Color(0xFF5E8C4A)
                        : const Color(0xFFD1D5DB),
                  ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(20, 8, 20, MediaQuery.of(context).padding.bottom + 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              g.brand,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: Color(0xFF9CA3AF),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              g.productName,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: Color(0xFF111827),
                height: 1.3,
              ),
            ),
            if (g.expiresLabel.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                expired
                    ? '유효기간 만료 (${g.expiresLabel})'
                    : '유효기간 ${g.expiresLabel}',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: expired ? const Color(0xFFEF4444) : const Color(0xFF6B7280),
                ),
              ),
            ],
            const SizedBox(height: 24),
            ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Container(
                width: double.infinity,
                color: Colors.white,
                child: _loadingUrl
                    ? const SizedBox(
                        height: 420,
                        child: Center(
                          child: CircularProgressIndicator(color: Color(0xFF5E8C4A)),
                        ),
                      )
                    : (_freshImageUrl?.isNotEmpty == true
                        ? Image.network(
                            _freshImageUrl!,
                            width: double.infinity,
                            fit: BoxFit.contain,
                            errorBuilder: (_, __, ___) => _imageError(),
                          )
                        : _imageError()),
              ),
            ),
            const SizedBox(height: 16),
            GestureDetector(
              onTap: _hasImage && !_downloading ? _downloadImage : null,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: _hasImage && !_downloading
                      ? const Color(0xFF5E8C4A)
                      : const Color(0xFFE5E7EB),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (_downloading)
                      const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    else
                      Icon(
                        Icons.download_rounded,
                        size: 18,
                        color: _hasImage ? Colors.white : const Color(0xFF9CA3AF),
                      ),
                    const SizedBox(width: 8),
                    Text(
                      _downloading ? '저장 중...' : '사진 저장',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        color: _hasImage ? Colors.white : const Color(0xFF9CA3AF),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE5E7EB)),
              ),
              child: const Text(
                '매장에서 쿠폰 이미지를 보여주세요.\n사용 후에는 쿠폰함 우측 상단 편집에서 목록을 정리할 수 있어요.',
                style: TextStyle(
                  fontSize: 13,
                  color: Color(0xFF6B7280),
                  height: 1.5,
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
        height: 320,
        color: const Color(0xFFF3F4F6),
        child: const Center(
          child: Text(
            '이미지를 불러올 수 없어요',
            style: TextStyle(color: Color(0xFF9CA3AF)),
          ),
        ),
      );
}
