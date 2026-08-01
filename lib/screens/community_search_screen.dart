import 'dart:async';

import 'package:flutter/material.dart';

import '../data/community_repository.dart';
import '../models/community_post.dart';
import '../services/supabase_service.dart';
import '../utils/recent_search_store.dart';
import '../widgets/community_post_card.dart';
import 'community_post_detail_screen.dart';

/// 커뮤니티 검색 — 별도 페이지 + 최근 검색어.
class CommunitySearchScreen extends StatefulWidget {
  const CommunitySearchScreen({super.key});

  @override
  State<CommunitySearchScreen> createState() => _CommunitySearchScreenState();
}

class _CommunitySearchScreenState extends State<CommunitySearchScreen> {
  static const _recentSearchStore = RecentSearchStore('community');

  final _repo = CommunityRepository();
  final _searchCtrl = TextEditingController();
  final _focusNode = FocusNode();

  bool _searching = false;
  bool _hasSearched = false;
  List<CommunityPost> _results = [];
  List<String> _recentSearches = [];

  @override
  void initState() {
    super.initState();
    _loadRecentSearches();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _loadRecentSearches() async {
    final searches = await _recentSearchStore.load();
    if (!mounted) return;
    setState(() => _recentSearches = searches);
  }

  Future<void> _saveRecentSearch(String query) async {
    final updated = await _recentSearchStore.save(query, _recentSearches);
    if (!mounted) return;
    setState(() => _recentSearches = updated);
  }

  Future<void> _removeRecentSearch(String query) async {
    final updated = await _recentSearchStore.remove(query, _recentSearches);
    if (!mounted) return;
    setState(() => _recentSearches = updated);
  }

  Future<void> _clearRecentSearches() async {
    await _recentSearchStore.clear();
    if (!mounted) return;
    setState(() => _recentSearches = []);
  }

  void _onChanged(String value) {
    if (value.trim().isEmpty) {
      setState(() {
        _hasSearched = false;
        _results = [];
      });
    }
  }

  Future<void> _runSearch(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return;
    setState(() {
      _searching = true;
      _hasSearched = true;
    });
    try {
      final results = await _repo.fetchFeed(query: trimmed);
      if (!mounted) return;
      setState(() {
        _results = results;
        _searching = false;
      });
      unawaited(_saveRecentSearch(trimmed));
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _results = [];
        _searching = false;
      });
    }
  }

  void _submitFromChip(String query) {
    _searchCtrl.value = TextEditingValue(
      text: query,
      selection: TextSelection.collapsed(offset: query.length),
    );
    _runSearch(query);
  }

  Future<void> _toggleLike(CommunityPost post) async {
    final uid = SupabaseService.client.auth.currentUser?.id;
    if (uid == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('로그인 후 이용할 수 있어요.')),
      );
      return;
    }
    final index = _results.indexWhere((p) => p.id == post.id);
    if (index == -1) return;
    final wasLiked = post.likedByMe;
    setState(() {
      _results[index] = post.copyWith(
        likedByMe: !wasLiked,
        likeCount: post.likeCount + (wasLiked ? -1 : 1),
      );
    });
    try {
      await _repo.toggleLike(post.id, wasLiked);
    } catch (_) {
      if (!mounted) return;
      setState(() => _results[index] = post);
    }
  }

  Future<void> _openDetail(CommunityPost post) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => CommunityPostDetailScreen(post: post)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            _searchBar(),
            Expanded(child: _body()),
          ],
        ),
      ),
    );
  }

  Widget _searchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 40,
              decoration: BoxDecoration(
                color: const Color(0xFFF3F4F6),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                children: [
                  const SizedBox(width: 12),
                  GestureDetector(
                    onTap: () => _runSearch(_searchCtrl.text),
                    child: const Icon(Icons.search, size: 16, color: Color(0xFF9CA3AF)),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _searchCtrl,
                      focusNode: _focusNode,
                      onChanged: _onChanged,
                      onSubmitted: _runSearch,
                      textInputAction: TextInputAction.search,
                      style: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w500, color: Color(0xFF1F2937)),
                      decoration: const InputDecoration(
                        hintText: '게시글 내용, 댓글, 매장명 검색',
                        hintStyle: TextStyle(fontSize: 14, color: Color(0xFF9CA3AF)),
                        border: InputBorder.none,
                        isDense: true,
                      ),
                    ),
                  ),
                  if (_searchCtrl.text.isNotEmpty)
                    GestureDetector(
                      onTap: () {
                        _searchCtrl.clear();
                        _onChanged('');
                      },
                      child: const Padding(
                        padding: EdgeInsets.only(right: 10),
                        child: Icon(Icons.close, size: 16, color: Color(0xFF9CA3AF)),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: const Text('취소',
                style: TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w900, color: Color(0xFF6B7280))),
          ),
        ],
      ),
    );
  }

  Widget _body() {
    if (!_hasSearched) return _recentSearchesView();

    if (_searching) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF111827)),
      );
    }

    if (_results.isEmpty) {
      return const Center(
        child: Text(
          '검색 결과가 없어요.',
          style: TextStyle(fontSize: 14, color: Color(0xFF9CA3AF)),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      itemCount: _results.length,
      itemBuilder: (context, i) {
        final post = _results[i];
        return CommunityPostCard(
          post: post,
          onTap: () => _openDetail(post),
          onLike: () => _toggleLike(post),
        );
      },
    );
  }

  Widget _recentSearchesView() {
    if (_recentSearches.isEmpty) {
      return const Center(
        child: Text(
          '최근 검색어가 없어요.',
          style: TextStyle(fontSize: 14, color: Color(0xFF9CA3AF)),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                '최근 검색어',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: Color(0xFF111827)),
              ),
              GestureDetector(
                onTap: _clearRecentSearches,
                child: const Text(
                  '전체삭제',
                  style: TextStyle(fontSize: 13, color: Color(0xFF9CA3AF)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _recentSearches.map((q) {
              return GestureDetector(
                onTap: () => _submitFromChip(q),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFFE5E7EB)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        q,
                        style: const TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF374151)),
                      ),
                      const SizedBox(width: 6),
                      GestureDetector(
                        onTap: () => _removeRecentSearch(q),
                        child: const Icon(Icons.close, size: 14, color: Color(0xFF9CA3AF)),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}
