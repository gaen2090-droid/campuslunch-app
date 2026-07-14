import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../data/community_repository.dart';
import '../models/community_post.dart';
import '../utils/profanity_filter.dart';
import 'community_rules_summary.dart';
import 'restaurant_picker_sheet.dart';

typedef _SelectedRestaurant = ({String id, String name});

/// 게시글 작성/수정 바텀시트
class CommunityPostEditorSheet extends StatefulWidget {
  final CommunityPost? editing;

  const CommunityPostEditorSheet({super.key, this.editing});

  static Future<bool?> show(BuildContext context, {CommunityPost? editing}) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => CommunityPostEditorSheet(editing: editing),
    );
  }

  @override
  State<CommunityPostEditorSheet> createState() => _CommunityPostEditorSheetState();
}

class _CommunityPostEditorSheetState extends State<CommunityPostEditorSheet> {
  final _contentCtrl = TextEditingController();
  final List<_PickedImage> _newImages = [];
  List<String> _existingImageUrls = [];
  _SelectedRestaurant? _selectedRestaurant;
  bool _submitting = false;
  String? _validationError;

  static const _maxImages = 4;

  @override
  void initState() {
    super.initState();
    final editing = widget.editing;
    if (editing != null) {
      _contentCtrl.text = editing.content;
      _existingImageUrls = List.from(editing.imageUrls);
      if (editing.restaurantId != null && editing.restaurantName != null) {
        _selectedRestaurant = (
          id: editing.restaurantId!,
          name: editing.restaurantName!,
        );
      }
    }
  }

  @override
  void dispose() {
    _contentCtrl.dispose();
    super.dispose();
  }

  int get _totalImageCount => _existingImageUrls.length + _newImages.length;

  Future<void> _pickImages() async {
    if (_totalImageCount >= _maxImages) return;
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: true,
      withData: true,
    );
    if (result == null) return;
    final remaining = _maxImages - _totalImageCount;
    setState(() {
      for (final f in result.files.take(remaining)) {
        final bytes = f.bytes;
        if (bytes == null) continue;
        _newImages.add(_PickedImage(bytes: bytes, ext: (f.extension ?? 'jpg')));
      }
    });
  }

  Future<void> _pickRestaurant() async {
    final picked = await RestaurantPickerSheet.show(context);
    if (picked == null) return;
    setState(() => _selectedRestaurant = (id: picked.id, name: picked.name));
  }

  Future<void> _submit() async {
    final content = _contentCtrl.text.trim();
    if (content.isEmpty || _submitting) return;
    if (containsProfanity(content)) {
      setState(() => _validationError = '커뮤니티 이용 정책에 위배되는 표현이 포함되어 있어요.');
      return;
    }
    setState(() {
      _submitting = true;
      _validationError = null;
    });

    final repo = CommunityRepository();
    try {
      final uploaded = <String>[];
      for (final img in _newImages) {
        final url = await repo.uploadImage(img.bytes, img.ext);
        uploaded.add(url);
      }
      final allImages = [..._existingImageUrls, ...uploaded];

      if (widget.editing != null) {
        await repo.updatePost(
          postId: widget.editing!.id,
          content: content,
          imageUrls: allImages,
          restaurantId: _selectedRestaurant?.id,
        );
      } else {
        await repo.createPost(
          content: content,
          imageUrls: allImages,
          restaurantId: _selectedRestaurant?.id,
        );
      }
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _validationError = '게시에 실패했어요. 다시 시도해주세요.';
      });
    }
  }

  void _removeExistingImage(int index) {
    setState(() => _existingImageUrls.removeAt(index));
  }

  void _removeNewImage(int index) {
    setState(() => _newImages.removeAt(index));
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.editing != null;
    final screenH = MediaQuery.of(context).size.height;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final bottomSafe = MediaQuery.of(context).padding.bottom;
    final sheetH = screenH * 0.92;
    const headerH = 72.0;
    const footerH = 132.0;
    final bodyH = sheetH - headerH - footerH - bottomSafe;
    final writingH = bodyH * 0.75;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        height: sheetH,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 5,
              decoration: BoxDecoration(
                color: const Color(0xFFE5E7EB),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  isEditing ? '글 수정하기' : '글쓰기',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF111827),
                  ),
                ),
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      height: writingH,
                      child: TextField(
                        controller: _contentCtrl,
                        expands: true,
                        maxLines: null,
                        maxLength: 1000,
                        textAlignVertical: TextAlignVertical.top,
                        onChanged: (_) {
                          if (_validationError != null) {
                            setState(() => _validationError = null);
                          }
                        },
                        decoration: const InputDecoration(
                          hintText: '커뮤니티 이용 정책을 지켜 자유롭게 이야기해주세요.',
                          counterText: '',
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                    ),
                    if (_validationError != null) ...[
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          _validationError!,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFFEF4444),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                    if (_totalImageCount > 0) ...[
                      const SizedBox(height: 8),
                      SizedBox(
                        height: 72,
                        child: ListView(
                          scrollDirection: Axis.horizontal,
                          children: [
                            for (var i = 0; i < _existingImageUrls.length; i++)
                              _ImageThumb(
                                imageProvider: NetworkImage(_existingImageUrls[i]),
                                onRemove: () => _removeExistingImage(i),
                              ),
                            for (var i = 0; i < _newImages.length; i++)
                              _ImageThumb(
                                imageProvider: MemoryImage(_newImages[i].bytes),
                                onRemove: () => _removeNewImage(i),
                              ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),
                    const CommunityRulesSummary(),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(20, 8, 20, bottomSafe + 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      OutlinedButton.icon(
                        onPressed: _totalImageCount >= _maxImages ? null : _pickImages,
                        icon: const Icon(Icons.image_outlined, size: 18),
                        label: Text('사진 ($_totalImageCount/$_maxImages)'),
                      ),
                      const SizedBox(width: 8),
                      if (_selectedRestaurant != null)
                        Expanded(
                          child: Chip(
                            label: Text(
                              _selectedRestaurant!.name,
                              overflow: TextOverflow.ellipsis,
                            ),
                            onDeleted: () => setState(() => _selectedRestaurant = null),
                          ),
                        )
                      else
                        OutlinedButton.icon(
                          onPressed: _pickRestaurant,
                          icon: const Icon(Icons.storefront_outlined, size: 18),
                          label: const Text('관련 매장'),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  GestureDetector(
                    onTap: _submit,
                    child: Container(
                      height: 52,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: const Color(0xFF9ECA8B),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Center(
                        child: _submitting
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : Text(
                                isEditing ? '수정 완료' : '게시하기',
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w900,
                                  color: Color(0xFF111827),
                                ),
                              ),
                      ),
                    ),
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

class _PickedImage {
  final Uint8List bytes;
  final String ext;
  const _PickedImage({required this.bytes, required this.ext});
}

class _ImageThumb extends StatelessWidget {
  final ImageProvider imageProvider;
  final VoidCallback onRemove;

  const _ImageThumb({required this.imageProvider, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image(
              image: imageProvider,
              width: 64,
              height: 64,
              fit: BoxFit.cover,
            ),
          ),
          Positioned(
            top: -6,
            right: -6,
            child: GestureDetector(
              onTap: onRemove,
              child: Container(
                width: 20,
                height: 20,
                decoration: const BoxDecoration(
                  color: Colors.black54,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.close, size: 14, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
