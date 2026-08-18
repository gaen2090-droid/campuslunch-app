import 'package:flutter/material.dart';

import '../data/community_repository.dart';
import '../models/community_inbox_notification.dart';
import '../utils/time_ago.dart';

/// 이용 제한 내역 — 커뮤니티 메뉴 → 차단 관리 밑.
/// 알림창의 정지/해제 안내와 같은 형식(헤드라인+사유)으로 보여주되,
/// 여기서는 배경색 강조(빨간색) 없이 표시한다.
class CommunitySuspensionHistoryScreen extends StatefulWidget {
  const CommunitySuspensionHistoryScreen({super.key});

  @override
  State<CommunitySuspensionHistoryScreen> createState() =>
      _CommunitySuspensionHistoryScreenState();
}

class _CommunitySuspensionHistoryScreenState
    extends State<CommunitySuspensionHistoryScreen> {
  final _repo = CommunityRepository();
  List<CommunityInboxNotification> _items = [];
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
      final list = await _repo.fetchSuspensionHistory();
      if (!mounted) return;
      setState(() {
        _items = list;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = '이용 제한 내역을 불러오지 못했어요.';
        _loading = false;
      });
    }
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
          '이용 제한 내역',
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
    if (_items.isEmpty) {
      return ListView(
        children: const [
          SizedBox(height: 160),
          Center(
            child: Text('이용 제한 내역이 없어요.', style: TextStyle(color: Color(0xFF9CA3AF))),
          ),
        ],
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      itemCount: _items.length,
      separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFFE5E7EB)),
      itemBuilder: (context, i) {
        final n = _items[i];
        final reasonText = n.adminReasonText;
        return Container(
          color: Colors.white,
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
            subtitle: reasonText == null
                ? null
                : Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      reasonText,
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
