import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/community_repository.dart';
import '../models/community_post.dart';
import '../models/restaurant.dart';
import '../providers/app_provider.dart';
import '../services/supabase_service.dart';
import '../utils/time_ago.dart';
import '../widgets/community_guideline_sheet.dart';
import '../widgets/community_post_editor_sheet.dart';
import 'community_post_detail_screen.dart';
import 'detail_screen.dart';

class CommunityScreen extends StatefulWidget {
  const CommunityScreen({super.key});

  @override
  State<CommunityScreen> createState() => _CommunityScreenState();
}

class _CommunityScreenState extends State<CommunityScreen> {
  final _repo = CommunityRepository();
  final List<CommunityPost> _posts = [];
  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadFeed();
    _maybeShowGuideline();
  }

  Future<void> _maybeShowGuideline() async {
    final provider = context.read<AppProvider>();
    final shouldShow = await provider.shouldShowCommunityGuideline();
    if (!shouldShow || !mounted) return;
    await showCommunityGuidelineSheet(context);
    provider.completeCommunityGuideline();
  }

  Future<void> _loadFeed() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final posts = await _repo.fetchFeed();
      if (!mounted) return;
      setState(() {
        _posts
          ..clear()
          ..addAll(posts);
        _hasMore = posts.length >= 20;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '게시글을 불러오지 못했어요.';
        _loading = false;
      });
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore || !_hasMore || _posts.isEmpty) return;
    setState(() => _loadingMore = true);
    try {
      final more = await _repo.fetchFeed(before: _posts.last.createdAt);
      if (!mounted) return;
      setState(() {
        _posts.addAll(more);
        _hasMore = more.length >= 20;
        _loadingMore = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingMore = false);
    }
  }

  Future<void> _toggleLike(CommunityPost post) async {
    final uid = SupabaseService.client.auth.currentUser?.id;
    if (uid == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('로그인 후 이용할 수 있어요.')),
      );
      return;
    }
    final index = _posts.indexWhere((p) => p.id == post.id);
    if (index == -1) return;
    final wasLiked = post.likedByMe;
    setState(() {
      _posts[index] = post.copyWith(
        likedByMe: !wasLiked,
        likeCount: post.likeCount + (wasLiked ? -1 : 1),
      );
    });
    try {
      await _repo.toggleLike(post.id, wasLiked);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _posts[index] = post;
      });
    }
  }

  Future<void> _openEditor({CommunityPost? editing}) async {
    final changed = await CommunityPostEditorSheet.show(context, editing: editing);
    if (changed == true) _loadFeed();
  }

  Future<void> _openDetail(CommunityPost post) async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => CommunityPostDetailScreen(post: post)),
    );
    if (changed == true) _loadFeed();
  }

  void _openRestaurant(String restaurantId) {
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
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openEditor(),
        backgroundColor: const Color(0xFF5E8C4A),
        child: const Icon(Icons.edit_outlined, color: Colors.white),
      ),
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: _loadFeed,
          child: _buildBody(),
        ),
      ),
    );
  }

  Widget _header() {
    return const Padding(
      padding: EdgeInsets.fromLTRB(8, 16, 8, 20),
      child: Row(
        children: [
          Expanded(
            child: Text(
              '커뮤니티',
              style: TextStyle(
                fontFamily: 'OkDanDan',
                fontSize: 31,
                fontWeight: FontWeight.w900,
                color: Color(0xFF5E8C4A),
                letterSpacing: -0.8,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return ListView(
        children: [
          _header(),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 80),
            child: Center(child: CircularProgressIndicator(color: Color(0xFF5E8C4A))),
          ),
        ],
      );
    }
    if (_error != null) {
      return ListView(
        children: [
          _header(),
          const SizedBox(height: 80),
          Center(
            child: Text(_error!, style: const TextStyle(color: Color(0xFF9CA3AF))),
          ),
        ],
      );
    }
    if (_posts.isEmpty) {
      return ListView(
        children: [
          _header(),
          const SizedBox(height: 120),
          const Center(
            child: Text(
              '아직 게시글이 없어요.\n첫 글을 남겨보세요!',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFF9CA3AF), height: 1.5),
            ),
          ),
        ],
      );
    }
    return NotificationListener<ScrollNotification>(
      onNotification: (n) {
        if (n.metrics.pixels >= n.metrics.maxScrollExtent - 200) {
          _loadMore();
        }
        return false;
      },
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
        itemCount: _posts.length + (_hasMore ? 1 : 0) + 1,
        itemBuilder: (context, i) {
          if (i == 0) {
            return _header();
          }
          final postIndex = i - 1;
          if (postIndex >= _posts.length) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF5E8C4A)),
                ),
              ),
            );
          }
          final post = _posts[postIndex];
          return _PostCard(
            post: post,
            onTap: () => _openDetail(post),
            onLike: () => _toggleLike(post),
            onRestaurantTap: post.restaurantId != null
                ? () => _openRestaurant(post.restaurantId!)
                : null,
          );
        },
      ),
    );
  }
}

class _PostCard extends StatelessWidget {
  final CommunityPost post;
  final VoidCallback onTap;
  final VoidCallback onLike;
  final VoidCallback? onRestaurantTap;

  const _PostCard({
    required this.post,
    required this.onTap,
    required this.onLike,
    this.onRestaurantTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  post.nickname,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFF111827)),
                ),
                const SizedBox(width: 6),
                Text(
                  timeAgo(post.createdAt),
                  style: const TextStyle(fontSize: 12, color: Color(0xFF9CA3AF)),
                ),
                if (post.updatedAt != null) ...[
                  const SizedBox(width: 4),
                  const Text('· 수정됨', style: TextStyle(fontSize: 12, color: Color(0xFF9CA3AF))),
                ],
              ],
            ),
            const SizedBox(height: 8),
            Text(
              post.content,
              maxLines: 5,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 14, color: Color(0xFF374151), height: 1.4),
            ),
            if (post.imageUrls.isNotEmpty) ...[
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(
                  post.imageUrls.first,
                  height: 160,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    height: 160,
                    color: const Color(0xFFF3F4F6),
                  ),
                ),
              ),
            ],
            if (post.restaurantId != null && post.restaurantName != null) ...[
              const SizedBox(height: 10),
              GestureDetector(
                onTap: onRestaurantTap,
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
                        post.restaurantName!,
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF5E8C4A)),
                      ),
                    ],
                  ),
                ),
              ),
            ],
            const SizedBox(height: 10),
            Row(
              children: [
                GestureDetector(
                  onTap: onLike,
                  child: Row(
                    children: [
                      Icon(
                        post.likedByMe ? Icons.favorite : Icons.favorite_border,
                        size: 18,
                        color: post.likedByMe ? const Color(0xFFEF4444) : const Color(0xFF9CA3AF),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${post.likeCount}',
                        style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280), fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                const Icon(Icons.chat_bubble_outline, size: 16, color: Color(0xFF9CA3AF)),
                const SizedBox(width: 4),
                Text(
                  '${post.commentCount}',
                  style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280), fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
