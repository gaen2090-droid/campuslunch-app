import 'package:flutter/material.dart';

import '../data/community_repository.dart';
import '../models/community_comment.dart';
import '../utils/profanity_filter.dart';
import '../utils/time_ago.dart';

class CollectionCommentsSheet extends StatefulWidget {
  final String collectionId;
  final String collectionTitle;

  const CollectionCommentsSheet({
    super.key,
    required this.collectionId,
    required this.collectionTitle,
  });

  static Future<void> show(BuildContext context, {
    required String collectionId,
    required String collectionTitle,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => CollectionCommentsSheet(
        collectionId: collectionId,
        collectionTitle: collectionTitle,
      ),
    );
  }

  @override
  State<CollectionCommentsSheet> createState() => _CollectionCommentsSheetState();
}

class _CollectionCommentsSheetState extends State<CollectionCommentsSheet> {
  final _repo = CommunityRepository();
  final _commentCtrl = TextEditingController();
  List<CommunityComment> _comments = [];
  bool _loading = true;
  bool _submitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _commentCtrl.dispose();
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
      await _repo.addCollectionComment(widget.collectionId, content);
      _commentCtrl.clear();
      await _load();
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
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = '댓글 삭제에 실패했어요.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
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
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Color(0xFF111827)),
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
                  ? const Center(child: CircularProgressIndicator(color: Color(0xFF5E8C4A)))
                  : _comments.isEmpty
                      ? const Center(
                          child: Text('첫 댓글을 남겨보세요.', style: TextStyle(color: Color(0xFF9CA3AF))),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                          itemCount: _comments.length,
                          itemBuilder: (context, i) {
                            final c = _comments[i];
                            return _CollectionCommentTile(
                              comment: c,
                              onDelete: c.isOwner ? () => _delete(c) : null,
                            );
                          },
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
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _commentCtrl,
                        onChanged: (_) {
                          if (_error != null) setState(() => _error = null);
                        },
                        decoration: InputDecoration(
                          hintText: '댓글을 입력해주세요',
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
                              child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF5E8C4A)),
                            )
                          : const Icon(Icons.send, color: Color(0xFF5E8C4A)),
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

class _CollectionCommentTile extends StatelessWidget {
  final CommunityComment comment;
  final VoidCallback? onDelete;

  const _CollectionCommentTile({required this.comment, this.onDelete});

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
              ],
            ),
          ),
          if (onDelete != null)
            GestureDetector(
              onTap: onDelete,
              child: const Padding(
                padding: EdgeInsets.only(left: 8),
                child: Icon(Icons.close, size: 16, color: Color(0xFF9CA3AF)),
              ),
            ),
        ],
      ),
    );
  }
}
