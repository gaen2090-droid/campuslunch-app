import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';

import '../constants/app_colors.dart';
import '../providers/app_provider.dart';
import '../models/community_poll_option.dart';
import '../models/community_post.dart';
import '../screens/community_poll_editor_screen.dart';
import '../utils/profanity_filter.dart';
import 'community_poll_card.dart';
import 'community_rules_summary.dart';
import 'restaurant_picker_sheet.dart';

typedef _SelectedRestaurant = ({String id, String name});

/// 게시글 작성/수정 페이지
class CommunityPostEditorSheet extends StatefulWidget {
  final CommunityPost? editing;

  const CommunityPostEditorSheet({super.key, this.editing});

  static Future<bool?> show(BuildContext context, {CommunityPost? editing}) {
    return Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => CommunityPostEditorSheet(editing: editing),
      ),
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
  CommunityPollDraft? _pollDraft;
  List<CommunityPollOption> _existingPollOptions = [];
  bool _loadingExistingPoll = false;

  static const _maxImages = 4;

  /// 게시된 글의 투표는 전혀 수정할 수 없으므로(§0), 이미 투표가 달린 글을
  /// 수정할 때는 새 투표를 추가하는 UI 진입점을 노출하지 않는다. 대신 기존
  /// 투표를 읽기 전용(사실은 상세 화면과 동일하게 투표도 가능)으로 보여준다.
  bool get _pollLockedByExistingPoll =>
      widget.editing != null && widget.editing!.hasPoll;

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
      if (editing.hasPoll) _loadExistingPollOptions(editing.id);
    }
  }

  Future<void> _loadExistingPollOptions(String postId) async {
    setState(() => _loadingExistingPoll = true);
    try {
      final options = await context.read<AppProvider>().community.fetchPollOptions(postId);
      if (!mounted) return;
      setState(() {
        _existingPollOptions = options;
        _loadingExistingPoll = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingExistingPoll = false);
    }
  }

  Future<void> _voteOnExistingPoll(List<String> optionIds) async {
    await context.read<AppProvider>().community.submitPollVote(optionIds);
    if (!mounted) return;
    await _loadExistingPollOptions(widget.editing!.id);
  }

  @override
  void dispose() {
    _contentCtrl.dispose();
    super.dispose();
  }

  int get _totalImageCount => _existingImageUrls.length + _newImages.length;

  Future<void> _pickImages() async {
    if (_totalImageCount >= _maxImages) return;
    final remaining = _maxImages - _totalImageCount;
    final picker = ImagePicker();
    final List<XFile> picked;
    if (remaining == 1) {
      final single = await picker.pickImage(source: ImageSource.gallery);
      picked = single == null ? const [] : [single];
    } else {
      picked = await picker.pickMultiImage(limit: remaining);
    }
    if (picked.isEmpty) return;
    final loaded = <_PickedImage>[];
    for (final file in picked.take(remaining)) {
      final bytes = await file.readAsBytes();
      final ext = file.name.contains('.') ? file.name.split('.').last : 'jpg';
      loaded.add(_PickedImage(bytes: bytes, ext: ext));
    }
    if (!mounted) return;
    setState(() => _newImages.addAll(loaded));
  }

  Future<void> _pickRestaurant() async {
    final picked = await RestaurantPickerSheet.show(context);
    if (picked == null) return;
    setState(() => _selectedRestaurant = (id: picked.id, name: picked.name));
  }

  Future<void> _openPollEditor() async {
    final result = await CommunityPollEditorScreen.show(
      context,
      initialDraft: _pollDraft,
    );
    if (result == null) return;
    if (!mounted) return;
    setState(() => _pollDraft = result);
  }

  void _deletePollDraft() {
    setState(() => _pollDraft = null);
  }

  void _showPollMenu(TapDownDetails details) async {
    final selected = await showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
        details.globalPosition.dx,
        details.globalPosition.dy,
        details.globalPosition.dx,
        details.globalPosition.dy,
      ),
      items: const [
        PopupMenuItem(value: 'edit', child: Text('수정')),
        PopupMenuItem(
          value: 'delete',
          child: Text('삭제', style: TextStyle(color: Color(0xFFEF4444))),
        ),
      ],
    );
    if (!mounted) return;
    if (selected == 'edit') _openPollEditor();
    if (selected == 'delete') _deletePollDraft();
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

    final repo = context.read<AppProvider>().community;
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
          pollOptions: _pollLockedByExistingPoll ? null : _pollDraft?.options,
          pollAllowMultiple: _pollDraft?.allowMultiple ?? false,
        );
      } else {
        await repo.createPost(
          content: content,
          imageUrls: allImages,
          restaurantId: _selectedRestaurant?.id,
          pollOptions: _pollDraft?.options,
          pollAllowMultiple: _pollDraft?.allowMultiple ?? false,
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
    final bottomSafe = MediaQuery.of(context).padding.bottom;

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
        title: Text(
          isEditing ? '글 수정하기' : '글쓰기',
          style: const TextStyle(
            fontFamily: 'Pretendard',
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: Color(0xFF000000),
            letterSpacing: -0.5,
          ),
        ),
        centerTitle: false,
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: _contentCtrl,
                    minLines: 8,
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
                      height: 78,
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
                  if (_pollDraft != null) ...[
                    const SizedBox(height: 12),
                    _PollSummaryCard(
                      draft: _pollDraft!,
                      onMenuTap: _showPollMenu,
                    ),
                    const SizedBox(height: 8),
                    const _PollLockNotice(),
                  ],
                  if (_pollLockedByExistingPoll) ...[
                    const SizedBox(height: 12),
                    if (_loadingExistingPoll && _existingPollOptions.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        child: Center(child: CircularProgressIndicator(color: Color(0xFF000000))),
                      )
                    else if (_existingPollOptions.isNotEmpty)
                      CommunityPollCard(
                        options: _existingPollOptions,
                        onVote: _voteOnExistingPoll,
                      ),
                    const SizedBox(height: 8),
                    const _PollLockNotice(),
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
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                    OutlinedButton.icon(
                      onPressed: _totalImageCount >= _maxImages ? null : _pickImages,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF000000),
                      ),
                      icon: const Icon(Icons.image_outlined, size: 18),
                      label: Text('사진 ($_totalImageCount/$_maxImages)'),
                    ),
                    const SizedBox(width: 8),
                    if (!_pollLockedByExistingPoll)
                      OutlinedButton.icon(
                        onPressed: _pollDraft != null ? null : _openPollEditor,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: _pollDraft != null
                              ? const Color(0xFFD1D5DB)
                              : const Color(0xFF000000),
                        ),
                        icon: const Icon(Icons.poll_outlined, size: 18),
                        label: const Text('투표'),
                      ),
                    const SizedBox(width: 8),
                    if (_selectedRestaurant != null)
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 160),
                        child: OutlinedButton.icon(
                          onPressed: _pickRestaurant,
                          style: OutlinedButton.styleFrom(
                            backgroundColor: const Color(0xFFE6F3EC),
                            foregroundColor: const Color(0xFF26BC7D),
                            side: const BorderSide(color: Color(0xFFE6F3EC)),
                          ),
                          icon: const Icon(Icons.storefront_outlined, size: 18),
                          label: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Flexible(
                                child: Text(
                                  _selectedRestaurant!.name,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 4),
                              GestureDetector(
                                onTap: () => setState(() => _selectedRestaurant = null),
                                child: const Icon(Icons.close, size: 16),
                              ),
                            ],
                          ),
                        ),
                      )
                    else
                      OutlinedButton.icon(
                        onPressed: _pickRestaurant,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF000000),
                        ),
                        icon: const Icon(Icons.storefront_outlined, size: 18),
                        label: const Text('관련 매장'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                GestureDetector(
                  onTap: _submit,
                  child: Container(
                    height: 52,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: AppColors.primaryCta,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Center(
                      child: _submitting
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : Text(
                              isEditing ? '수정 완료' : '게시하기',
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
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
      padding: const EdgeInsets.only(top: 6, right: 14),
      child: Stack(
        clipBehavior: Clip.none,
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

/// 아직 게시 전(로컬 상태)인 투표를 요약해서 보여주는 카드. 우측 ⋮ 메뉴로
/// 수정(편집 화면 재진입)/삭제를 선택한다. 게시된 이후에는 이 카드가 아니라
/// 상세 화면의 읽기 전용 투표 카드(community_poll_card.dart)가 대신 쓰인다.
class _PollSummaryCard extends StatelessWidget {
  final CommunityPollDraft draft;
  final void Function(TapDownDetails) onMenuTap;

  const _PollSummaryCard({
    required this.draft,
    required this.onMenuTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.poll_outlined, size: 18, color: Color(0xFF6B7280)),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '투표',
                  style: TextStyle(
                    fontFamily: 'Pretendard',
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF000000),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${draft.allowMultiple ? '복수 선택 가능' : '1개만 선택 가능'}, ${draft.options.length}개 항목',
                  style: const TextStyle(
                    fontFamily: 'Pretendard',
                    fontSize: 12,
                    color: Color(0xFF9CA3AF),
                  ),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTapDown: onMenuTap,
            child: const Icon(Icons.more_vert, size: 18, color: Color(0xFF9CA3AF)),
          ),
        ],
      ),
    );
  }
}

/// 캡처 참고: 투표가 붙은 게시글 초안 아래 "글 게시 후 투표는 수정/삭제할 수
/// 없어요" 안내.
class _PollLockNotice extends StatelessWidget {
  const _PollLockNotice();

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: const [
        Icon(Icons.info_outline, size: 14, color: Color(0xFF9CA3AF)),
        SizedBox(width: 4),
        Expanded(
          child: Text(
            '글 게시 후 투표는 수정하거나 삭제할 수 없어요.',
            style: TextStyle(
              fontFamily: 'Pretendard',
              fontSize: 12,
              color: Color(0xFF9CA3AF),
            ),
          ),
        ),
      ],
    );
  }
}
