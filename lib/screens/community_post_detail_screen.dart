import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/community_repository.dart';
import '../models/community_comment.dart';
import '../models/community_post.dart';
import '../models/restaurant.dart';
import '../providers/app_provider.dart';
import '../services/supabase_service.dart';
import '../utils/profanity_filter.dart';
import '../utils/time_ago.dart';
import '../widgets/community_post_editor_sheet.dart';
import '../widgets/owner_badge.dart';
import 'detail_screen.dart';

class CommunityPostDetailScreen extends StatefulWidget {
  final CommunityPost post;

  const CommunityPostDetailScreen({super.key, required this.post});

  @override
  State<CommunityPostDetailScreen> createState() => _CommunityPostDetailScreenState();
}

class _CommunityPostDetailScreenState extends State<CommunityPostDetailScreen> {
  final _repo = CommunityRepository();
  final _commentCtrl = TextEditingController();
  final _commentFocusNode = FocusNode();
  late CommunityPost _post;
  List<CommunityComment> _comments = [];
  bool _loadingComments = true;
  bool _submittingComment = false;
  bool _changed = false;
  bool _deleted = false;
  bool _subscribed = false;
  bool _subscribedLoaded = false;
  CommunityComment? _replyTarget;

  @override
  void initState() {
    super.initState();
    _post = widget.post;
    _loadComments();
    _loadSubscription();
  }

  Future<void> _loadSubscription() async {
    try {
      final subscribed = await _repo.isSubscribed(_post.id);
      if (!mounted) return;
      setState(() {
        _subscribed = subscribed;
        _subscribedLoaded = true;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _subscribedLoaded = true);
    }
  }

  Future<void> _toggleSubscription() async {
    final next = !_subscribed;
    setState(() => _subscribed = next);
    try {
      await _repo.setSubscribed(_post.id, next);
    } catch (_) {
      if (!mounted) return;
      setState(() => _subscribed = !next);
    }
  }

  @override
  void dispose() {
    _commentCtrl.dispose();
    _commentFocusNode.dispose();
    super.dispose();
  }

  Future<void> _loadComments() async {
    setState(() => _loadingComments = true);
    try {
      final comments = await _repo.fetchComments(_post.id);
      if (!mounted) return;
      setState(() {
        _comments = comments;
        _loadingComments = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingComments = false);
    }
  }

  Future<void> _toggleLike() async {
    final uid = SupabaseService.client.auth.currentUser?.id;
    if (uid == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('로그인 후 이용할 수 있어요.')),
      );
      return;
    }
    final wasLiked = _post.likedByMe;
    setState(() {
      _post = _post.copyWith(
        likedByMe: !wasLiked,
        likeCount: _post.likeCount + (wasLiked ? -1 : 1),
      );
      _changed = true;
    });
    try {
      await _repo.toggleLike(_post.id, wasLiked);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _post = _post.copyWith(likedByMe: wasLiked, likeCount: widget.post.likeCount);
      });
    }
  }

  Future<void> _submitComment() async {
    final content = _commentCtrl.text.trim();
    if (content.isEmpty || _submittingComment) return;
    if (containsProfanity(content)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('커뮤니티 이용 정책에 위배되는 표현이 포함되어 있어요.')),
      );
      return;
    }
    setState(() => _submittingComment = true);
    try {
      await _repo.addComment(
        _post.id,
        content,
        parentCommentId: _replyTarget?.id,
      );
      _commentCtrl.clear();
      _changed = true;
      setState(() => _replyTarget = null);
      await _loadComments();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('댓글 등록에 실패했어요.')),
      );
    } finally {
      if (mounted) setState(() => _submittingComment = false);
    }
  }

  Future<void> _deleteComment(CommunityComment comment) async {
    try {
      await _repo.deleteComment(comment.id);
      _changed = true;
      await _loadComments();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('댓글 삭제에 실패했어요.')),
      );
    }
  }

  Future<void> _reportComment(CommunityComment comment) async {
    try {
      await _repo.report(commentId: comment.id, reason: '사용자 신고');
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

  Future<void> _toggleCommentLike(CommunityComment comment) async {
    if (comment.isOwner) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('내가 쓴 댓글은 공감할 수 없어요.')),
      );
      return;
    }
    final uid = SupabaseService.client.auth.currentUser?.id;
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
      await _repo.toggleCommentLike(comment.id, wasLiked);
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
      widgets.add(_CommentTile(
        comment: parent,
        onDelete: parent.isOwner ? () => _deleteComment(parent) : null,
        onReport: parent.isOwner ? null : () => _reportComment(parent),
        onLike: () => _toggleCommentLike(parent),
        onReply: () => _startReply(parent),
      ));
      final replies = repliesByParent[parent.id] ?? const [];
      for (final reply in replies) {
        widgets.add(Padding(
          padding: const EdgeInsets.only(left: 32),
          child: _CommentTile(
            comment: reply,
            onDelete: reply.isOwner ? () => _deleteComment(reply) : null,
            onReport: reply.isOwner ? null : () => _reportComment(reply),
            onLike: () => _toggleCommentLike(reply),
            onReply: () => _startReply(parent),
          ),
        ));
      }
    }
    return widgets;
  }

  Future<void> _editPost() async {
    final result = await CommunityPostEditorSheet.show(context, editing: _post);
    if (!mounted) return;
    if (result == true) {
      _changed = true;
      Navigator.pop(context, true);
    }
  }

  Future<void> _deletePost() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('게시글 삭제', style: TextStyle(fontWeight: FontWeight.w900)),
        content: const Text('삭제한 게시글은 복구할 수 없어요.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('취소', style: TextStyle(color: Color(0xFF9CA3AF))),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('삭제', style: TextStyle(color: Color(0xFFEF4444), fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await _repo.deletePost(_post.id);
      _deleted = true;
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('삭제에 실패했어요.')),
      );
    }
  }

  Future<void> _reportPost() async {
    try {
      await _repo.report(postId: _post.id, reason: '사용자 신고');
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

  void _openRestaurant() {
    final restaurantId = _post.restaurantId;
    if (restaurantId == null) return;
    final restaurants = context.read<AppProvider>().restaurants;
    Restaurant? match;
    for (final r in restaurants) {
      if (r.id == restaurantId) {
        match = r;
        break;
      }
    }
    if (match == null) return;
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => DetailScreen(restaurant: match!)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) {
        if (didPop) return;
        Navigator.pop(context, _deleted || _changed);
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF9FAFB),
        resizeToAvoidBottomInset: true,
        appBar: AppBar(
          backgroundColor: const Color(0xFFF9FAFB),
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, size: 18, color: Color(0xFF111827)),
            onPressed: () => Navigator.pop(context, _deleted || _changed),
          ),
          titleSpacing: 0,
          title: const Text(
            '게시글',
            style: TextStyle(fontFamily: 'OkDanDan', fontSize: 20, fontWeight: FontWeight.w900, color: Color(0xFF111827), letterSpacing: -0.5),
          ),
          centerTitle: false,
          actions: [
            if (_subscribedLoaded)
              IconButton(
                onPressed: _toggleSubscription,
                icon: Icon(
                  _subscribed ? Icons.notifications_active : Icons.notifications_off_outlined,
                  color: _subscribed ? const Color(0xFF5E8C4A) : const Color(0xFF9CA3AF),
                ),
              ),
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, color: Color(0xFF111827)),
              offset: const Offset(0, 44),
              onSelected: (v) {
                if (v == 'edit') _editPost();
                if (v == 'delete') _deletePost();
                if (v == 'report') _reportPost();
              },
              itemBuilder: (ctx) => _post.isOwner
                  ? const [
                      PopupMenuItem(value: 'edit', child: Text('수정')),
                      PopupMenuItem(value: 'delete', child: Text('삭제')),
                    ]
                  : const [
                      PopupMenuItem(value: 'report', child: Text('신고')),
                    ],
            ),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
          children: [
                  Row(
                    children: [
                      Text(
                        _post.nickname,
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Color(0xFF111827)),
                      ),
                      if (_post.isAuthorOwner) ...[
                        const SizedBox(width: 4),
                        const OwnerBadge(),
                      ],
                      const SizedBox(width: 6),
                      Text(
                        timeAgo(_post.createdAt),
                        style: const TextStyle(fontSize: 12, color: Color(0xFF9CA3AF)),
                      ),
                      if (_post.updatedAt != null) ...[
                        const SizedBox(width: 4),
                        const Text('· 수정됨', style: TextStyle(fontSize: 12, color: Color(0xFF9CA3AF))),
                      ],
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _post.content,
                    style: const TextStyle(fontSize: 15, color: Color(0xFF374151), height: 1.5),
                  ),
                  if (_post.imageUrls.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    ...(_post.imageUrls.map((url) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.network(
                              url,
                              width: double.infinity,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Container(
                                height: 160,
                                color: const Color(0xFFF3F4F6),
                              ),
                            ),
                          ),
                        ))),
                  ],
                  if (_post.restaurantId != null && _post.restaurantName != null) ...[
                    const SizedBox(height: 8),
                    GestureDetector(
                      onTap: _openRestaurant,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF3F8F0),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.storefront_outlined, size: 14, color: Color(0xFF5E8C4A)),
                            const SizedBox(width: 4),
                            Text(
                              _post.restaurantName!,
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF5E8C4A)),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  GestureDetector(
                    onTap: _toggleLike,
                    child: Row(
                      children: [
                        Icon(
                          _post.likedByMe ? Icons.favorite : Icons.favorite_border,
                          size: 20,
                          color: _post.likedByMe ? const Color(0xFFEF4444) : const Color(0xFF9CA3AF),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '좋아요 ${_post.likeCount}',
                          style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280), fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 32, color: Color(0xFFE5E7EB)),
                  Text(
                    '댓글 ${_comments.length}',
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Color(0xFF111827)),
                  ),
                  const SizedBox(height: 12),
                  if (_loadingComments)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: Center(child: CircularProgressIndicator(color: Color(0xFF5E8C4A))),
                    )
                  else if (_comments.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: Center(
                        child: Text('첫 댓글을 남겨보세요.', style: TextStyle(color: Color(0xFF9CA3AF))),
                      ),
                    )
                  else
                    ..._buildCommentTree(),
          ],
        ),
        bottomNavigationBar: Material(
          color: Colors.white,
          child: SafeArea(
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
                          onSubmitted: (_) {
                            if (!_submittingComment) _submitComment();
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
                        onPressed: _submittingComment ? null : _submitComment,
                        icon: _submittingComment
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF5E8C4A)),
                              )
                            : const Icon(Icons.send, color: Color(0xFF5E8C4A)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CommentTile extends StatelessWidget {
  final CommunityComment comment;
  final VoidCallback? onDelete;
  final VoidCallback? onReport;
  final VoidCallback onLike;
  final VoidCallback onReply;

  const _CommentTile({
    required this.comment,
    required this.onLike,
    required this.onReply,
    this.onDelete,
    this.onReport,
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
                    Text(
                      comment.nickname,
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFF111827)),
                    ),
                    if (comment.isAuthorOwner) ...[
                      const SizedBox(width: 4),
                      const OwnerBadge(),
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
                      onTap: onReply,
                      child: const Icon(Icons.chat_bubble_outline, size: 16, color: Color(0xFF9CA3AF)),
                    ),
                    const SizedBox(width: 14),
                    GestureDetector(
                      onTap: onLike,
                      child: Row(
                        children: [
                          Icon(
                            comment.likedByMe ? Icons.thumb_up : Icons.thumb_up_outlined,
                            size: 16,
                            color: comment.likedByMe ? const Color(0xFF5E8C4A) : const Color(0xFF9CA3AF),
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
                  ],
                ),
              ],
            ),
          ),
          if (onDelete != null || onReport != null)
            PopupMenuButton<String>(
              padding: EdgeInsets.zero,
              icon: const Icon(Icons.more_vert, size: 16, color: Color(0xFF9CA3AF)),
              onSelected: (v) {
                if (v == 'delete') onDelete?.call();
                if (v == 'report') onReport?.call();
              },
              itemBuilder: (ctx) => onDelete != null
                  ? const [PopupMenuItem(value: 'delete', child: Text('삭제'))]
                  : const [PopupMenuItem(value: 'report', child: Text('신고'))],
            ),
        ],
      ),
    );
  }
}
