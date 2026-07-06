import 'package:flutter/material.dart';

import '../data/community_repository.dart';
import '../models/community_comment_notification.dart';
import '../utils/time_ago.dart';
import 'community_post_detail_screen.dart';

class CommunityNotificationsScreen extends StatefulWidget {
  const CommunityNotificationsScreen({super.key});

  @override
  State<CommunityNotificationsScreen> createState() => _CommunityNotificationsScreenState();
}

class _CommunityNotificationsScreenState extends State<CommunityNotificationsScreen> {
  final _repo = CommunityRepository();
  List<CommunityCommentNotification> _notifications = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await _repo.fetchCommentNotifications();
      if (!mounted) return;
      setState(() {
        _notifications = list;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '알림을 불러오지 못했어요.';
        _loading = false;
      });
    }
  }

  Future<void> _openPost(CommunityCommentNotification n) async {
    final post = await _repo.fetchPostById(n.postId);
    if (!mounted) return;
    if (post == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('게시글을 찾을 수 없어요.')),
      );
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => CommunityPostDetailScreen(post: post)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF9FAFB),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 18, color: Color(0xFF111827)),
          onPressed: () => Navigator.pop(context),
        ),
        titleSpacing: 0,
        title: const Text(
          '알림',
          style: TextStyle(
            fontFamily: 'OkDanDan',
            fontSize: 20,
            fontWeight: FontWeight.w900,
            color: Color(0xFF111827),
            letterSpacing: -0.5,
          ),
        ),
        centerTitle: false,
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFF5E8C4A)));
    }
    if (_error != null) {
      return ListView(
        children: [
          const SizedBox(height: 120),
          Center(child: Text(_error!, style: const TextStyle(color: Color(0xFF9CA3AF)))),
        ],
      );
    }
    if (_notifications.isEmpty) {
      return ListView(
        children: const [
          SizedBox(height: 160),
          Center(
            child: Text('아직 알림이 없어요.', style: TextStyle(color: Color(0xFF9CA3AF))),
          ),
        ],
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
      itemCount: _notifications.length,
      separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFFE5E7EB)),
      itemBuilder: (context, i) {
        final n = _notifications[i];
        return ListTile(
          contentPadding: const EdgeInsets.symmetric(vertical: 8),
          onTap: () => _openPost(n),
          title: Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: n.commenterNickname,
                  style: const TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF111827)),
                ),
                const TextSpan(text: '님이 댓글을 남겼어요', style: TextStyle(color: Color(0xFF111827))),
              ],
            ),
            style: const TextStyle(fontSize: 14),
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              n.commentContent,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
            ),
          ),
          trailing: Text(
            timeAgo(n.createdAt),
            style: const TextStyle(fontSize: 11, color: Color(0xFF9CA3AF)),
          ),
        );
      },
    );
  }
}
