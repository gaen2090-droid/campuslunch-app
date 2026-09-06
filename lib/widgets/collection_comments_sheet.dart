import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../constants/app_colors.dart';
import '../data/community_repository.dart';
import '../providers/app_provider.dart';
import '../models/community_comment.dart';
import '../utils/profanity_filter.dart';
import '../utils/time_ago.dart';
import '../widgets/block_user_dialog.dart';
import '../widgets/admin_badge.dart';
import '../widgets/owner_badge.dart';

class CollectionCommentsSheet extends StatefulWidget {
  final String collectionId;
  final String collectionTitle;
  final ValueChanged<int>? onCountChanged;

  const CollectionCommentsSheet({
    super.key,
    required this.collectionId,
    required this.collectionTitle,
    this.onCountChanged,
  });

  static Future<void> show(BuildContext context, {
    required String collectionId,
    required String collectionTitle,
    ValueChanged<int>? onCountChanged,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => CollectionCommentsSheet(
        collectionId: collectionId,
        collectionTitle: collectionTitle,
        onCountChanged: onCountChanged,
      ),
    );
  }

  @override
  State<CollectionCommentsSheet> createState() => _CollectionCommentsSheetState();
}

class _CollectionCommentsSheetState extends State<CollectionCommentsSheet> {
  CommunityRepository get _repo => context.read<AppProvider>().community;
  final _commentCtrl = TextEditingController();
  final _commentFocusNode = FocusNode();
  List<CommunityComment> _comments = [];
  bool _loading = true;
  bool _submitting = false;
  String? _error;
  CommunityComment? _replyTarget;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _commentCtrl.dispose();
    _commentFocusNode.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final comments = await _repo.fetchCollectionComments(widget.collectionId);
      if (!mounted) return;
      setState(() {
        _comments = comments;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _submit() async {
    final content = _commentCtrl.text.trim();
    if (content.isEmpty || _submitting) return;
    if (containsProfanity(content)) {
      setState(() => _error = '커뮤니티 이용 정책에 위배되는 표현이 포함되어 있어요.');
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await _repo.addCollectionComment(
        widget.collectionId,
        content,
        parentCommentId: _replyTarget?.id,
      );
      _commentCtrl.clear();
      setState(() => _replyTarget = null);
      await _load();
      widget.onCountChanged?.call(_comments.length);
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = '댓글 등록에 실패했어요.');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _delete(CommunityComment comment) async {
    try {
      await _repo.deleteCollectionComment(comment.id);
      await _load();
      widget.onCountChanged?.call(_comments.length);
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = '댓글 삭제에 실패했어요.');
    }
  }

  Future<void> _report(CommunityComment comment) async {
    try {
      await _repo.reportCollectionComment(comment.id, reason: '사용자 신고');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('신고가 접수되었어요.')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('신고 접수에 실패했어요.')),
      );
    }
  }

  Future<void> _block(CommunityComment comment) async {
    final authorId = comment.authorId;
    if (authorId == null) return;
    if (!await confirmBlockUser(context, comment.nickname)) return;
    try {
      // 컬렉션 댓글은 community_reports가 아닌 collection_comment_reports에
      // 기록되므로, 운영자 통지를 위해 신고를 따로 남긴다.
      await _repo.reportCollectionComment(comment.id, reason: '사용자 차단');
      await _repo.blockUser(authorId, reason: '컬렉션 댓글 작성자 차단');
      await _load();
      if (!mounted) return;
      widget.onCountChanged?.call(_comments.length);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${comment.nickname}님을 차단했어요.')),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = '차단에 실패했어요.');
    }
  }

  Future<void> _toggleCommentLike(CommunityComment comment) async {
    if (comment.isOwner) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('내가 쓴 댓글은 공감할 수 없어요.')),
      );
      return;
    }
    final uid = context.read<AppProvider>().currentUserId;
    if (uid == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('로그인 후 이용할 수 있어요.')),
      );
      return;
    }
    final index = _comments.indexWhere((c) => c.id == comment.id);
    if (index == -1) return;
    final wasLiked = comment.likedByMe;
    setState(() {
      _comments[index] = comment.copyWith(
        likedByMe: !wasLiked,
        likeCount: comment.likeCount + (wasLiked ? -1 : 1),
      );
    });
    try {
      await _repo.toggleCollectionCommentLike(comment.id, wasLiked);
    } catch (_) {
      if (!mounted) return;
      setState(() => _comments[index] = comment);
    }
  }

  void _startReply(CommunityComment comment) {
    setState(() => _replyTarget = comment);
    FocusScope.of(context).requestFocus(_commentFocusNode);
  }

  void _cancelReply() {
    setState(() => _replyTarget = null);
  }

  List<Widget> _buildCommentTree() {
    final topLevel = _comments.where((c) => c.parentCommentId == null).toList();
    final repliesByParent = <String, List<CommunityComment>>{};
    for (final c in _comments) {
      final parentId = c.parentCommentId;
      if (parentId != null) {
        repliesByParent.putIfAbsent(parentId, () => []).add(c);
      }
    }

    final widgets = <Widget>[];
    for (final parent in topLevel) {
      widgets.add(_CollectionCommentTile(
        comment: parent,
        onDelete: parent.isOwner ? () => _delete(parent) : null,
        onReport: parent.isOwner ? null : () => _report(parent),
        onBlock: parent.isOwner || parent.authorId == null
            ? null
            : () => _block(parent),
        onLike: () => _toggleCommentLike(parent),
        onReply: () => _startReply(parent),
      ));
      final replies = repliesByParent[parent.id] ?? const [];
      for (final reply in replies) {
        widgets.add(Padding(
          padding: const EdgeInsets.only(left: 32),
          child: _CollectionCommentTile(
            comment: reply,
            onDelete: reply.isOwner ? () => _delete(reply) : null,
            onReport: reply.isOwner ? null : () => _report(reply),
            onBlock: reply.isOwner || reply.authorId == null
                ? null
                : () => _block(reply),
            onLike: () => _toggleCommentLike(reply),
            onReply: () => _startReply(parent),
          ),
        ));
      }
    }
    return widgets;
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        Navigator.of(context).pop(_comments.length);
      },
      child: Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        height: MediaQuery.of(context).size.height * 0.75,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 6,
              decoration: BoxDecoration(
                color: const Color(0xFFE5E7EB),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '${widget.collectionTitle} 댓글',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Color(0xFF000000)),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    '${_comments.length}',
                    style: const TextStyle(fontSize: 13, color: Color(0xFF9CA3AF), fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator(color: Color(0xFF000000)))
                  : _comments.isEmpty
                      ? const Center(
                          child: Text('첫 댓글을 남겨보세요.', style: TextStyle(color: Color(0xFF9CA3AF))),
                        )
                      : ListView(
                          padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                          children: _buildCommentTree(),
                        ),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                child: Text(
                  _error!,
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFFEF4444)),
                ),
              ),
            SafeArea(
              top: false,
              child: Container(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                decoration: const BoxDecoration(
                  border: Border(top: BorderSide(color: Color(0xFFE5E7EB))),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_replyTarget != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                '${_replyTarget!.nickname}님에게 답글 남기는 중',
                                style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            GestureDetector(
                              onTap: _cancelReply,
                              child: const Icon(Icons.close, size: 16, color: Color(0xFF9CA3AF)),
                            ),
                          ],
                        ),
                      ),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _commentCtrl,
                            focusNode: _commentFocusNode,
                            textInputAction: TextInputAction.send,
                            onChanged: (_) {
                              if (_error != null) setState(() => _error = null);
                            },
                            onSubmitted: (_) {
                              if (!_submitting) _submit();
                            },
                            decoration: InputDecoration(
                              hintText: _replyTarget != null ? '답글을 입력해주세요' : '댓글을 입력해주세요',
                              filled: true,
                              fillColor: const Color(0xFFF9FAFB),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(20),
                                borderSide: BorderSide.none,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          onPressed: _submitting ? null : _submit,
                          icon: _submitting
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF000000)),
                                )
                              : const Icon(Icons.send, color: Color(0xFF000000)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      ),
    );
  }
}

class _CollectionCommentTile extends StatelessWidget {
  final CommunityComment comment;
  final VoidCallback? onDelete;
  final VoidCallback? onReport;
  final VoidCallback? onBlock;
  final VoidCallback onLike;
  final VoidCallback onReply;

  const _CollectionCommentTile({
    required this.comment,
    required this.onLike,
    required this.onReply,
    this.onDelete,
    this.onReport,
    this.onBlock,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        comment.nickname,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFF000000)),
                      ),
                    ),
                    if (comment.isAuthorOwner) ...[
                      const SizedBox(width: 4),
                      const OwnerBadge(),
                    ],
                    if (comment.isAuthorAdmin) ...[
                      const SizedBox(width: 4),
                      const AdminBadge(),
                    ],
                    const SizedBox(width: 6),
                    Text(
                      timeAgo(comment.createdAt),
                      style: const TextStyle(fontSize: 11, color: Color(0xFF9CA3AF)),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  comment.content,
                  style: const TextStyle(fontSize: 14, color: Color(0xFF374151), height: 1.4),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    GestureDetector(
                      onTap: onLike,
                      child: Row(
                        children: [
                          Icon(
                            comment.likedByMe ? Icons.thumb_up : Icons.thumb_up_outlined,
                            size: 16,
                            color: comment.likedByMe ? AppColors.primaryCta : const Color(0xFF9CA3AF),
                          ),
                          if (comment.likeCount > 0) ...[
                            const SizedBox(width: 4),
                            Text(
                              '${comment.likeCount}',
                              style: const TextStyle(fontSize: 12, color: Color(0xFF9CA3AF), fontWeight: FontWeight.w600),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 14),
                    GestureDetector(
                      onTap: onReply,
                      child: const Icon(Icons.chat_bubble_outline, size: 16, color: Color(0xFF9CA3AF)),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (onDelete != null || onReport != null || onBlock != null)
            PopupMenuButton<String>(
              padding: EdgeInsets.zero,
              icon: const Icon(Icons.more_vert, size: 16, color: Color(0xFF9CA3AF)),
              onSelected: (v) {
                if (v == 'delete') onDelete?.call();
                if (v == 'report') onReport?.call();
                if (v == 'block') onBlock?.call();
              },
              itemBuilder: (ctx) => onDelete != null
                  ? const [PopupMenuItem(value: 'delete', child: Text('삭제'))]
                  : [
                      if (onReport != null)
                        const PopupMenuItem(value: 'report', child: Text('신고')),
                      if (onBlock != null)
                        const PopupMenuItem(
                          value: 'block',
                          child: Text(
                            '이 사용자 차단',
                            style: TextStyle(color: Color(0xFFEF4444)),
                          ),
                        ),
                    ],
            ),
        ],
      ),
    );
  }
}
