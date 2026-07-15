import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/reward.dart';
import '../providers/app_provider.dart';
import '../services/supabase_service.dart';
import '../widgets/load_error_view.dart';
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
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final provider = context.read<AppProvider>();
      await provider.fetchMyReward();
      if (!mounted) return;
      await provider.markCouponBoxSeen();
    });
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
    final gifticons =
        provider.visibleMyGifticons.where((g) => g.status == 'assigned').toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF3F8F0),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF3F8F0),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 18, color: Color(0xFF111827)),
          onPressed: () => Navigator.pop(context),
        ),
        titleSpacing: 0,
        title: const Text(
          '내 쿠폰함',
          style: TextStyle(
            fontFamily: 'OkDanDan',
            fontSize: 20,
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
        child: provider.rewardLoadFailed && gifticons.isEmpty
            ? ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  LoadErrorView(
                    onRetry: () => provider.fetchMyReward(),
                  ),
                ],
              )
            : gifticons.isEmpty
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
                            fontFamily: 'OkDanDan',
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
            : GridView.builder(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.fromLTRB(
                  16,
                  12,
                  16,
                  MediaQuery.of(context).padding.bottom + 32,
                ),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 0.78,
                ),
                itemCount: gifticons.length,
                itemBuilder: (context, i) {
                  final g = gifticons[i];
                  return _GifticonTile(
                    gifticon: g,
                    editMode: _editMode,
                    removing: _removingIds.contains(g.id),
                    onView: () => _openDetail(g),
                    onRemove: () => _removeGifticon(g),
                  );
                },
              ),
      ),
    );
  }
}

class _GifticonTile extends StatefulWidget {
  final Gifticon gifticon;
  final bool editMode;
  final bool removing;
  final VoidCallback onView;
  final VoidCallback onRemove;

  const _GifticonTile({
    required this.gifticon,
    required this.editMode,
    required this.removing,
    required this.onView,
    required this.onRemove,
  });

  @override
  State<_GifticonTile> createState() => _GifticonTileState();
}

class _GifticonTileState extends State<_GifticonTile> {
  String? _thumbUrl;

  @override
  void initState() {
    super.initState();
    _resolveThumb();
  }

  Future<void> _resolveThumb() async {
    final raw = widget.gifticon.imageUrl;
    if (raw.isEmpty) return;
    if (!raw.startsWith('http') && SupabaseService.isReady) {
      try {
        final url = await SupabaseService.client.storage
            .from('gifticons')
            .createSignedUrl(raw, 3600);
        if (mounted) setState(() => _thumbUrl = url);
        return;
      } catch (_) {}
    }
    if (mounted) setState(() => _thumbUrl = raw);
  }

  @override
  Widget build(BuildContext context) {
    final g = widget.gifticon;
    return GestureDetector(
      onTap: widget.editMode ? widget.onRemove : widget.onView,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFE5E7EB)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(6),
              blurRadius: 6,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Container(
                    color: const Color(0xFFFFFBEB),
                    child: _thumbUrl != null && _thumbUrl!.isNotEmpty
                        ? Image.network(
                            _thumbUrl!,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) =>
                                const Center(child: Text('🎁', style: TextStyle(fontSize: 32))),
                          )
                        : const Center(child: Text('🎁', style: TextStyle(fontSize: 32))),
                  ),
                  if (widget.editMode)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        width: 26,
                        height: 26,
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEE2E2),
                          borderRadius: BorderRadius.circular(13),
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                        child: widget.removing
                            ? const Padding(
                                padding: EdgeInsets.all(5),
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Color(0xFFEF4444),
                                ),
                              )
                            : const Icon(Icons.remove, size: 16, color: Color(0xFFEF4444)),
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    g.brand,
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF9CA3AF),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    g.productName,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF111827),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
