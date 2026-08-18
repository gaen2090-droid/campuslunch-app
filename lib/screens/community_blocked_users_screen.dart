import 'package:flutter/material.dart';

import '../data/community_repository.dart';
import '../models/blocked_user.dart';

/// 차단 관리 — 커뮤니티 더보기(≡) → 차단 관리
class CommunityBlockedUsersScreen extends StatefulWidget {
  const CommunityBlockedUsersScreen({super.key});

  @override
  State<CommunityBlockedUsersScreen> createState() =>
      _CommunityBlockedUsersScreenState();
}

class _CommunityBlockedUsersScreenState
    extends State<CommunityBlockedUsersScreen> {
  final _repo = CommunityRepository();
  List<BlockedUser> _blocked = [];
  bool _loading = true;
  bool _changed = false;
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
      final blocked = await _repo.fetchBlockedUsers();
      if (!mounted) return;
      setState(() {
        _blocked = blocked;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = '차단 목록을 불러오지 못했어요.';
        _loading = false;
      });
    }
  }

  Future<void> _unblock(BlockedUser user) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('차단 해제', style: TextStyle(fontWeight: FontWeight.w900)),
        content: Text(
          '${user.nickname}님의 차단을 해제할까요?\n해제하면 이 사용자의 글과 댓글이 다시 보여요.',
          style: const TextStyle(fontSize: 14, height: 1.5, color: Color(0xFF374151)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('취소', style: TextStyle(color: Color(0xFF9CA3AF))),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              '해제',
              style: TextStyle(color: Color(0xFF000000), fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await _repo.unblockUser(user.userId);
      _changed = true;
      if (!mounted) return;
      setState(() => _blocked.removeWhere((b) => b.userId == user.userId));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${user.nickname}님의 차단을 해제했어요.')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('차단 해제에 실패했어요.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        Navigator.pop(context, _changed);
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, size: 18, color: Color(0xFF000000)),
            onPressed: () => Navigator.pop(context, _changed),
          ),
          titleSpacing: 0,
          title: const Text(
            '차단 관리',
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
    if (_blocked.isEmpty) {
      return ListView(
        children: const [
          SizedBox(height: 120),
          Center(
            child: Text(
              '차단한 사용자가 없어요.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFF9CA3AF), height: 1.5),
            ),
          ),
        ],
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      itemCount: _blocked.length + 1,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, i) {
        if (i == 0) {
          return const Padding(
            padding: EdgeInsets.only(bottom: 8),
            child: Text(
              '차단한 사용자의 게시글과 댓글은 보이지 않아요.',
              style: TextStyle(fontSize: 13, color: Color(0xFF6B7280), height: 1.4),
            ),
          );
        }
        final user = _blocked[i - 1];
        return Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE5E7EB)),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  user.nickname,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF000000),
                  ),
                ),
              ),
              TextButton(
                onPressed: () => _unblock(user),
                child: const Text(
                  '차단 해제',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF000000),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
