import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/community_repository.dart';
import '../providers/app_provider.dart';
import '../models/community_inbox_notification.dart';
import '../utils/time_ago.dart';
import '../widgets/collection_comments_sheet.dart';
import 'community_post_detail_screen.dart';

class CommunityNotificationsScreen extends StatefulWidget {
  const CommunityNotificationsScreen({super.key});

  @override
  State<CommunityNotificationsScreen> createState() =>
      _CommunityNotificationsScreenState();
}

class _CommunityNotificationsScreenState
    extends State<CommunityNotificationsScreen> {
  CommunityRepository get _repo => context.read<AppProvider>().community;
  List<CommunityInboxNotification> _notifications = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
    unawaited(_repo.markInboxSeen());
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await _repo.fetchInboxNotifications();
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

  Future<void> _openPost(CommunityInboxNotification n) async {
    if (!n.isRead) {
      final index = _notifications.indexWhere((e) => e.eventId == n.eventId);
      if (index != -1) {
        setState(() {
          _notifications[index] = _notifications[index].copyWith(isRead: true);
        });
      }
      unawaited(_repo.markInboxNotificationRead(n.eventId));
    }
    if (n.isAdminNotice || n.postId == null) return;

    if (n.isCollection) {
      await CollectionCommentsSheet.show(
        context,
        collectionId: n.postId!,
        collectionTitle: '컬렉션',
      );
      return;
    }

    final post = await _repo.fetchPostById(n.postId!);
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
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 18, color: Color(0xFF000000)),
          onPressed: () => Navigator.pop(context),
        ),
        titleSpacing: 0,
        title: const Text(
          '알림',
          style: TextStyle(
            fontFamily: 'Pretendard',
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: Color(0xFF000000),
            letterSpacing: -0.5,
          ),
        ),
        centerTitle: false,
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        color: const Color(0xFF000000),
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFF000000)));
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
        if (n.isAdminNotice) {
          final contentText = n.adminContentText;
          final reasonText = n.adminReasonText;
          final subtitleLines = <String>[
            if (contentText != null) contentText,
            if (reasonText != null) reasonText,
          ];
          return Container(
            color: n.isActiveSuspensionNotice
                ? const Color(0xFFFDF0F3)
                : n.isSuspensionNotice
                    ? const Color(0xFFE6F3EC)
                    : const Color(0xFFFDF0F3),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              title: Text(
                n.adminHeadline,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF000000),
                ),
              ),
              subtitle: subtitleLines.isEmpty
                  ? null
                  : Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        subtitleLines.join('\n'),
                        style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
                      ),
                    ),
              trailing: Text(
                timeAgo(n.createdAt),
                style: const TextStyle(fontSize: 11, color: Color(0xFF9CA3AF)),
              ),
            ),
          );
        }
        return Container(
          color: n.isRead ? Colors.white : const Color(0xFFE6F3EC),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            onTap: () => _openPost(n),
            title: Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: n.actorNickname,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF000000),
                    ),
                  ),
                  TextSpan(
                    text: n.headlineSuffix,
                    style: const TextStyle(color: Color(0xFF000000)),
                  ),
                ],
              ),
              style: const TextStyle(fontSize: 14),
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                n.bodyText,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
              ),
            ),
            trailing: Text(
              timeAgo(n.createdAt),
              style: const TextStyle(fontSize: 11, color: Color(0xFF9CA3AF)),
            ),
          ),
        );
      },
    );
  }
}
