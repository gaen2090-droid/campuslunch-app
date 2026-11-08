import 'dart:convert';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../utils/photo_saver.dart';

/// 전체 화면 사진 뷰어. 두 손가락으로 확대/축소, 더블탭으로 확대 토글,
/// 확대하지 않은 상태에서는 좌우로 넘겨 다음 사진을 본다.
/// 커뮤니티 게시글·매장 상세에서 공통으로 쓴다.
class FullScreenImageViewer extends StatefulWidget {
  final List<String> urls;
  final int initialIndex;

  const FullScreenImageViewer({
    super.key,
    required this.urls,
    this.initialIndex = 0,
  });

  /// 닫을 때 마지막으로 보던 사진 index를 돌려준다.
  static Future<int?> show(
    BuildContext context, {
    required List<String> urls,
    int initialIndex = 0,
  }) {
    return Navigator.of(context).push<int>(
      PageRouteBuilder(
        opaque: true,
        pageBuilder: (_, __, ___) =>
            FullScreenImageViewer(urls: urls, initialIndex: initialIndex),
        transitionsBuilder: (_, animation, __, child) =>
            FadeTransition(opacity: animation, child: child),
      ),
    );
  }

  @override
  State<FullScreenImageViewer> createState() => _FullScreenImageViewerState();
}

class _FullScreenImageViewerState extends State<FullScreenImageViewer> {
  late final PageController _controller;
  late int _index;
  bool _zoomed = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex.clamp(0, widget.urls.length - 1);
    _controller = PageController(initialPage: _index);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _close() => Navigator.of(context).pop(_index);

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    final messenger = ScaffoldMessenger.of(context);
    final err = await PhotoSaver.save(widget.urls[_index]);
    if (!mounted) return;
    setState(() => _saving = false);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(err ?? '사진을 저장했어요.')));
  }

  @override
  Widget build(BuildContext context) {
    final urls = widget.urls;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _close();
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            PageView.builder(
              controller: _controller,
              itemCount: urls.length,
              // 확대 중에는 드래그가 사진 이동에 쓰이도록 페이지 넘김을 잠근다.
              physics: _zoomed
                  ? const NeverScrollableScrollPhysics()
                  : const PageScrollPhysics(),
              onPageChanged: (i) => setState(() {
                _index = i;
                _zoomed = false;
              }),
              itemBuilder: (context, i) => _ZoomablePage(
                url: urls[i],
                onZoomChanged: (zoomed) {
                  if (i == _index && zoomed != _zoomed) {
                    setState(() => _zoomed = zoomed);
                  }
                },
              ),
            ),
            SafeArea(
              child: SizedBox(
                height: 56,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: IconButton(
                        onPressed: _close,
                        icon: const Icon(Icons.close, color: Colors.white, size: 28),
                      ),
                    ),
                    if (urls.length > 1)
                      Text(
                        '${_index + 1} / ${urls.length}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    Align(
                      alignment: Alignment.centerRight,
                      child: IconButton(
                        tooltip: '사진 저장',
                        onPressed: _saving ? null : _save,
                        icon: _saving
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.file_download_outlined,
                                color: Colors.white, size: 28),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ZoomablePage extends StatefulWidget {
  final String url;
  final ValueChanged<bool> onZoomChanged;

  const _ZoomablePage({required this.url, required this.onZoomChanged});

  @override
  State<_ZoomablePage> createState() => _ZoomablePageState();
}

class _ZoomablePageState extends State<_ZoomablePage> {
  static const _doubleTapScale = 2.5;
  final _transform = TransformationController();
  Offset _doubleTapAt = Offset.zero;

  @override
  void initState() {
    super.initState();
    _transform.addListener(_onTransform);
  }

  @override
  void dispose() {
    _transform.removeListener(_onTransform);
    _transform.dispose();
    super.dispose();
  }

  void _onTransform() {
    widget.onZoomChanged(_transform.value.getMaxScaleOnAxis() > 1.01);
  }

  void _toggleZoom() {
    if (_transform.value.getMaxScaleOnAxis() > 1.01) {
      _transform.value = Matrix4.identity();
      return;
    }
    final p = _doubleTapAt;
    const s = _doubleTapScale;
    _transform.value =
        Matrix4.translationValues(-p.dx * (s - 1), -p.dy * (s - 1), 0) *
            Matrix4.diagonal3Values(s, s, 1);
  }

  Widget _image() {
    final url = widget.url;
    const broken = Icon(Icons.broken_image_outlined, color: Colors.white54, size: 40);
    // 매장 사진 중에는 data:image/ base64 로 저장된 것도 있다.
    if (url.startsWith('data:image/')) {
      try {
        final bytes = base64Decode(url.substring(url.indexOf(',') + 1));
        return Image.memory(bytes, fit: BoxFit.contain);
      } catch (_) {
        return broken;
      }
    }
    return CachedNetworkImage(
      imageUrl: url,
      fit: BoxFit.contain,
      placeholder: (_, __) =>
          const Center(child: CircularProgressIndicator(color: Colors.white54)),
      errorWidget: (_, __, ___) => broken,
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onDoubleTapDown: (d) => _doubleTapAt = d.localPosition,
      onDoubleTap: _toggleZoom,
      child: InteractiveViewer(
        transformationController: _transform,
        minScale: 1,
        maxScale: 5,
        child: Center(child: _image()),
      ),
    );
  }
}
