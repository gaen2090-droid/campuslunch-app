import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/community_repository.dart';
import '../models/collection.dart';
import '../models/community_notice.dart';
import '../models/community_post.dart';
import '../models/restaurant.dart';
import '../providers/app_provider.dart';
import '../services/supabase_service.dart';
import '../widgets/collection_comments_sheet.dart';
import '../widgets/collection_section.dart';
import '../widgets/community_guideline_sheet.dart';
import '../widgets/community_post_card.dart';
import '../widgets/community_post_editor_sheet.dart';
import '../widgets/community_rules_summary.dart';
import 'collection_detail_screen.dart';
import 'community_my_activity_screen.dart';
import 'community_notifications_screen.dart';
import 'community_post_detail_screen.dart';
import 'community_search_screen.dart';
import 'detail_screen.dart';
import 'home_screen.dart' show HomeFilterChip, SimpleFilterSheet;

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

  int _segment = 0; // 0: 자유게시판, 1: 맛집 컬렉션
  List<RestaurantCollection> _collections = [];
  final Map<String, List<CollectionItem>> _collectionItems = {};
  bool _collectionsLoading = true;
  String? _collectionsError;
  bool _savedCollectionsOnly = false;
  String _collectionSortBy = '인기순';
  static const _collectionSortOpts = ['인기순', '최신순'];

  CommunityNotice? _notice;
  List<CommunityPost> _pinnedPosts = [];
  bool _hasUnreadNotification = false;
  bool _openingPendingPush = false;

  @override
  void initState() {
    super.initState();
    _loadNotice();
    _loadPinned();
    _loadFeed();
    _loadCollections();
    _maybeShowGuideline();
    _checkUnreadNotifications();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _openPendingPushPost();
    });
  }

  @override
  void dispose() {
    _pinnedPageController.dispose();
    super.dispose();
  }

  Future<void> _loadPinned() async {
    try {
      final pinned = await _repo.fetchPinnedPosts();
      if (!mounted) return;
      setState(() {
        _pinnedPosts = pinned;
        // 1개뿐이면 스와이프가 무의미하므로 폭 전체(1.0)를 채운다.
        _pinnedPageController.dispose();
        _pinnedPageController = PageController(
          viewportFraction: pinned.length <= 1 ? 1.0 : 0.7,
          initialPage: 0,
        );
      });
    } catch (_) {
      // 핀 게시글 로드 실패는 무시 (핵심 기능 아님)
    }
  }

  Future<void> _openPendingPushPost() async {
    if (_openingPendingPush) return;
    final provider = context.read<AppProvider>();
    final postId = provider.consumePendingCommunityPostId();
    if (postId == null || postId.isEmpty) return;
    _openingPendingPush = true;
    try {
      final post = await _repo.fetchPostById(postId);
      if (!mounted || post == null) return;
      await _openDetail(post);
    } catch (e) {
      debugPrint('[Community] open pending push post failed: $e');
    } finally {
      _openingPendingPush = false;
    }
  }

  Future<void> _loadNotice() async {
    try {
      final notice = await _repo.fetchActiveNotice();
      if (!mounted) return;
      setState(() => _notice = notice);
    } catch (_) {
      // 공지 로드 실패는 무시 (핵심 기능 아님)
    }
  }

  Future<void> _checkUnreadNotifications() async {
    try {
      final hasUnread = await _repo.hasUnreadInboxNotifications();
      if (!mounted) return;
      setState(() => _hasUnreadNotification = hasUnread);
    } catch (_) {
      // 알림 확인 실패는 무시 (핵심 기능 아님)
    }
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

  Future<void> _loadCollections() async {
    setState(() {
      _collectionsLoading = true;
      _collectionsError = null;
    });
    try {
      final collections = await _repo.fetchCollections();
      final itemsByCollection = <String, List<CollectionItem>>{};
      for (final c in collections) {
        itemsByCollection[c.id] = await _repo.fetchCollectionItems(c.id);
      }
      if (!mounted) return;
      setState(() {
        _collections = collections;
        _collectionItems
          ..clear()
          ..addAll(itemsByCollection);
        _collectionsLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _collectionsError = '컬렉션을 불러오지 못했어요.';
        _collectionsLoading = false;
      });
    }
  }

  Future<void> _toggleCollectionLike(RestaurantCollection collection) async {
    final index = _collections.indexWhere((c) => c.id == collection.id);
    if (index == -1) return;
    final wasLiked = collection.likedByMe;
    setState(() {
      _collections[index] = collection.copyWith(
        likedByMe: !wasLiked,
        likeCount: collection.likeCount + (wasLiked ? -1 : 1),
      );
    });
    try {
      await _repo.toggleCollectionLike(collection.id, wasLiked);
    } catch (_) {
      if (!mounted) return;
      setState(() => _collections[index] = collection);
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
    if (changed == true) {
      _loadFeed();
      _loadPinned();
    }
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
    _pushDetail(match);
  }

  void _pushDetail(Restaurant restaurant) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => DetailScreen(restaurant: restaurant)),
    );
  }

  Future<void> _openNotifications() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const CommunityNotificationsScreen()),
    );
    if (!mounted) return;
    await _checkUnreadNotifications();
  }

  @override
  Widget build(BuildContext context) {
    final pendingId =
        context.select<AppProvider, String?>((p) => p.pendingCommunityPostId);
    if (pendingId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _openPendingPushPost();
      });
    }
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      // 맛집 컬렉션은 관리자 웹에서만 등록.
      floatingActionButton: _segment == 0
          ? FloatingActionButton(
              onPressed: () => _openEditor(),
              backgroundColor: const Color(0xFF5E8C4A),
              child: const Icon(Icons.edit_outlined, color: Colors.white),
            )
          : null,
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: _segment == 0 ? _loadFeed : _loadCollections,
          child: _segment == 0 ? _buildBody() : _buildCollectionsBody(),
        ),
      ),
    );
  }

  Widget _header() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 16, 0, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            // 아이콘 버튼들의 접근성 최소 탭 영역(48x48)은 그대로 두고, 그
            // 내장 여백만큼 우측 마진을 줄여 시각적으로 화면 끝에 더 가깝게
            // 붙인다(좌측은 기존 20 유지, 마이페이지 톱니바퀴와 동일 값).
            padding: const EdgeInsets.fromLTRB(20, 0, 14, 0),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    '커뮤니티',
                    style: TextStyle(
                      fontFamily: 'Pretendard',
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF5E8C4A),
                      letterSpacing: -0.8,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const CommunitySearchScreen()),
                  ),
                  icon: const Icon(Icons.search, color: Color(0xFF5E8C4A), size: 24),
                ),
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    IconButton(
                      onPressed: _openNotifications,
                      icon: const Icon(Icons.notifications_outlined, color: Color(0xFF5E8C4A), size: 24),
                    ),
                    if (_hasUnreadNotification)
                      Positioned(
                        right: 8,
                        top: 8,
                        child: Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: Color(0xFFEF4444),
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                  ],
                ),
                PopupMenuButton<MyActivityMode>(
                  icon: const Icon(Icons.menu, color: Color(0xFF5E8C4A), size: 24),
                  offset: const Offset(0, 44),
                  onSelected: (mode) => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => CommunityMyActivityScreen(mode: mode),
                    ),
                  ),
                  itemBuilder: (ctx) => [
                    const PopupMenuItem(value: MyActivityMode.myPosts, child: Text('내가 쓴 글')),
                    const PopupMenuItem(value: MyActivityMode.commentedPosts, child: Text('댓글 단 글')),
                    PopupMenuItem(
                      onTap: () {
                        Future.microtask(
                          () => CommunityRulesSummary.openFullPolicy(context),
                        );
                      },
                      child: const Text('커뮤니티 이용규칙'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: _segmentControl(),
          ),
          if (_segment == 1) ...[
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: _collectionFilterBar(),
            ),
          ],
          if (_segment == 0 && _notice != null) ...[
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: _noticeBox(_notice!),
            ),
          ],
          if (_segment == 0 && _pinnedPosts.isNotEmpty) ...[
            const SizedBox(height: 12),
            _pinnedPostsRow(),
          ],
        ],
      ),
    );
  }

  PageController _pinnedPageController =
      PageController(viewportFraction: 0.7, initialPage: 0);

  Widget _pinnedPostsRow() {
    // 홈 필터칩 행과 동일하게 — 좌측 여백만 안쪽 padding으로 주고, 스와이프
    // 시 배너가 우측 여백과 무관하게 화면 끝까지 침범하도록 아이콘+PageView
    // 전체를 화면 폭 그대로 두고 좌측에만 패딩을 준다.
    return SizedBox(
      height: 36,
      child: Row(
        children: [
          const SizedBox(width: 20),
          const Icon(Icons.campaign_rounded, size: 20, color: Color(0xFF4C9C2A)),
          const SizedBox(width: 10),
          Expanded(
            child: ClipRect(
              child: PageView.builder(
                controller: _pinnedPageController,
                padEnds: false,
                itemCount: _pinnedPosts.length,
                itemBuilder: (_, i) => Padding(
                  padding: EdgeInsets.only(
                    right: i == _pinnedPosts.length - 1 ? 20 : 8,
                  ),
                  child: _pinnedPostBanner(_pinnedPosts[i]),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _pinnedPostBanner(CommunityPost post) {
    return GestureDetector(
      onTap: () => _openDetail(post),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFF3F8F0),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFBFE0B0)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                post.content,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF111827),
                ),
              ),
            ),
            const SizedBox(width: 6),
            const Icon(Icons.chevron_right, size: 16, color: Color(0xFF9CA3AF)),
          ],
        ),
      ),
    );
  }

  Widget _collectionFilterBar() {
    return Row(
      children: [
        GestureDetector(
          onTap: () => setState(() => _savedCollectionsOnly = !_savedCollectionsOnly),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
            decoration: BoxDecoration(
              color: _savedCollectionsOnly ? const Color(0xFF9ECA8B) : Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                  color: _savedCollectionsOnly ? const Color(0xFF9ECA8B) : const Color(0xFFE5E7EB)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '저장한 컬렉션',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      color: _savedCollectionsOnly ? const Color(0xFF111827) : const Color(0xFF374151)),
                ),
                const SizedBox(width: 3),
                Icon(
                  _savedCollectionsOnly ? Icons.favorite : Icons.favorite_border,
                  size: 14,
                  color: const Color(0xFF111827),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 8),
        HomeFilterChip(
          label: _collectionSortBy,
          active: _collectionSortBy != '인기순',
          open: false,
          onTap: () => showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
            builder: (_) => SimpleFilterSheet(
              title: '정렬',
              items: _collectionSortOpts,
              selected: {_collectionSortBy},
              multiSelect: false,
              isActive: _collectionSortBy != '인기순',
              locationMode: true,
              onApply: (v) => setState(() => _collectionSortBy = v.first),
              onReset: () => setState(() => _collectionSortBy = '인기순'),
              onRequestLocation: () {},
            ),
          ),
        ),
      ],
    );
  }

  Widget _noticeBox(CommunityNotice notice) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '안내',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Color(0xFFEF4444),
              height: 1.3,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              notice.content,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: Color(0xFF374151),
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _segmentControl() {
    return Row(
      children: [
        _segmentTab('자유게시판', 0),
        _segmentTab('맛집 컬렉션', 1),
      ],
    );
  }

  Widget _segmentTab(String label, int index) {
    final active = _segment == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _segment = index),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: active ? const Color(0xFF5E8C4A) : const Color(0xFFE5E7EB),
                width: active ? 2 : 1,
              ),
            ),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: active ? const Color(0xFF5E8C4A) : const Color(0xFF9CA3AF),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCollectionsBody() {
    if (_collectionsLoading) {
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
    if (_collectionsError != null) {
      return ListView(
        children: [
          _header(),
          const SizedBox(height: 80),
          Center(
            child: Text(_collectionsError!, style: const TextStyle(color: Color(0xFF9CA3AF))),
          ),
        ],
      );
    }
    if (_collections.isEmpty) {
      return ListView(
        children: [
          _header(),
          const SizedBox(height: 120),
          const Center(
            child: Text(
              '아직 등록된 컬렉션이 없어요.',
              style: TextStyle(color: Color(0xFF9CA3AF)),
            ),
          ),
        ],
      );
    }
    final restaurants = context.watch<AppProvider>().restaurants;

    var visibleCollections = _savedCollectionsOnly
        ? _collections.where((c) => c.likedByMe).toList()
        : List<RestaurantCollection>.from(_collections);
    visibleCollections.sort((a, b) {
      if (_collectionSortBy == '최신순') return b.createdAt.compareTo(a.createdAt);
      final likeDiff = b.likeCount.compareTo(a.likeCount);
      if (likeDiff != 0) return likeDiff;
      return b.createdAt.compareTo(a.createdAt);
    });

    if (visibleCollections.isEmpty) {
      return ListView(
        children: [
          _header(),
          const SizedBox(height: 120),
          const Center(
            child: Text(
              '저장한 컬렉션이 없어요.',
              style: TextStyle(color: Color(0xFF9CA3AF)),
            ),
          ),
        ],
      );
    }

    return ListView(
      padding: const EdgeInsets.only(bottom: 96),
      children: [
        _header(),
        for (final collection in visibleCollections)
          CollectionSection(
            collection: collection,
            items: _collectionItems[collection.id] ?? const [],
            restaurants: restaurants,
            onTapRestaurant: _pushDetail,
            onSeeAll: (c, items) => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => CollectionDetailScreen(
                  collection: c,
                  items: items,
                  restaurants: restaurants,
                ),
              ),
            ),
            onTapComments: (c) async {
              await CollectionCommentsSheet.show(
                context,
                collectionId: c.id,
                collectionTitle: c.title,
              );
              if (mounted) _loadCollections();
            },
            onTapLike: () => _toggleCollectionLike(collection),
            onReport: () => _reportCollection(collection),
          ),
      ],
    );
  }

  Future<void> _reportCollection(RestaurantCollection collection) async {
    try {
      await _repo.reportCollection(collection.id, reason: '사용자 신고');
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
        padding: const EdgeInsets.only(bottom: 96),
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
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: CommunityPostCard(
              post: post,
              onTap: () => _openDetail(post),
              onLike: () => _toggleLike(post),
              onRestaurantTap: post.restaurantId != null
                  ? () => _openRestaurant(post.restaurantId!)
                  : null,
            ),
          );
        },
      ),
    );
  }
}
