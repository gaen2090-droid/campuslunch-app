import 'package:flutter/material.dart';

import '../data/community_repository.dart';
import '../models/community_post.dart';
import '../models/restaurant.dart';
import '../providers/app_provider.dart';
import '../widgets/community_post_card.dart';
import 'community_post_detail_screen.dart';
import 'detail_screen.dart';
import 'package:provider/provider.dart';

enum MyActivityMode { myPosts, commentedPosts }

class CommunityMyActivityScreen extends StatefulWidget {
  final MyActivityMode mode;

  const CommunityMyActivityScreen({super.key, required this.mode});

  @override
  State<CommunityMyActivityScreen> createState() => _CommunityMyActivityScreenState();
}

class _CommunityMyActivityScreenState extends State<CommunityMyActivityScreen> {
  final _repo = CommunityRepository();
  List<CommunityPost> _posts = [];
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
      final posts = widget.mode == MyActivityMode.myPosts
          ? await _repo.fetchMyPosts()
          : await _repo.fetchMyCommentedPosts();
      if (!mounted) return;
      setState(() {
        _posts = posts;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '불러오지 못했어요.';
        _loading = false;
      });
    }
  }

  Future<void> _toggleLike(CommunityPost post) async {
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
      setState(() => _posts[index] = post);
    }
  }

  Future<void> _openDetail(CommunityPost post) async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => CommunityPostDetailScreen(post: post)),
    );
    if (changed == true) _load();
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
    final title = widget.mode == MyActivityMode.myPosts ? '내가 쓴 글' : '댓글 단 글';
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
        title: Text(
          title,
          style: const TextStyle(
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
          Center(
            child: Text(_error!, style: const TextStyle(color: Color(0xFF9CA3AF))),
          ),
        ],
      );
    }
    if (_posts.isEmpty) {
      return ListView(
        children: [
          const SizedBox(height: 160),
          Center(
            child: Text(
              widget.mode == MyActivityMode.myPosts
                  ? '아직 쓴 글이 없어요.'
                  : '아직 댓글 단 글이 없어요.',
              style: const TextStyle(color: Color(0xFF9CA3AF)),
            ),
          ),
        ],
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
      itemCount: _posts.length,
      itemBuilder: (context, i) {
        final post = _posts[i];
        return CommunityPostCard(
          post: post,
          onTap: () => _openDetail(post),
          onLike: () => _toggleLike(post),
          onRestaurantTap: post.restaurantId != null
              ? () => _openRestaurant(post.restaurantId!)
              : null,
        );
      },
    );
  }
}
