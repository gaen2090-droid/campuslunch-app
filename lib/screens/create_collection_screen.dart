import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../constants/app_colors.dart';
import '../data/community_repository.dart';
import '../models/collection.dart';
import '../models/restaurant.dart';
import '../providers/app_provider.dart';

const int kCollectionMaxRestaurants = 20;
const int kCollectionMinRestaurants = 5;

/// 커뮤니티 > 맛집 컬렉션 > 직접 만들기 / 수정하기
class CreateCollectionScreen extends StatefulWidget {
  final RestaurantCollection? editing;
  final List<Restaurant> initialSelected;

  const CreateCollectionScreen({
    super.key,
    this.editing,
    this.initialSelected = const [],
  });

  @override
  State<CreateCollectionScreen> createState() => _CreateCollectionScreenState();
}

class _CreateCollectionScreenState extends State<CreateCollectionScreen> {
  final _repo = CommunityRepository();
  late final _titleCtrl = TextEditingController(text: widget.editing?.title ?? '');
  late final _subtitleCtrl = TextEditingController(text: widget.editing?.subtitle ?? '');
  final _searchCtrl = TextEditingController();

  late final List<Restaurant> _selected = List.from(widget.initialSelected);
  bool _submitting = false;
  String? _error;

  bool get _isEditing => widget.editing != null;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _subtitleCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _toggle(Restaurant r) {
    setState(() {
      final idx = _selected.indexWhere((e) => e.id == r.id);
      if (idx >= 0) {
        _selected.removeAt(idx);
      } else {
        if (_selected.length >= kCollectionMaxRestaurants) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('매장은 최대 $kCollectionMaxRestaurants개까지 선택할 수 있어요.')),
          );
          return;
        }
        _selected.add(r);
      }
    });
  }

  Future<void> _submit() async {
    final title = _titleCtrl.text.trim();
    if (title.isEmpty) {
      setState(() => _error = '제목을 입력해주세요.');
      return;
    }
    if (_selected.length < kCollectionMinRestaurants) {
      setState(() => _error = '매장을 최소 $kCollectionMinRestaurants개 이상 선택해주세요.');
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final subtitle = _subtitleCtrl.text.trim().isEmpty ? null : _subtitleCtrl.text.trim();
      final restaurantIds = _selected.map((r) => r.id).toList();
      if (_isEditing) {
        await _repo.updateUserCollection(
          collectionId: widget.editing!.id,
          title: title,
          subtitle: subtitle,
          restaurantIds: restaurantIds,
        );
      } else {
        await _repo.createUserCollection(
          title: title,
          subtitle: subtitle,
          restaurantIds: restaurantIds,
        );
      }
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _error = _isEditing
            ? '컬렉션을 수정하지 못했어요. 잠시 후 다시 시도해주세요.'
            : '컬렉션을 만들지 못했어요. 잠시 후 다시 시도해주세요.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final all = context.watch<AppProvider>().restaurants;
    final q = _searchCtrl.text.trim().toLowerCase();
    final results = q.isEmpty
        ? const <Restaurant>[]
        : all
            .where((r) => '${r.name} ${r.area} ${r.category}'.toLowerCase().contains(q))
            .toList();

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
        title: Text(
          _isEditing ? '컬렉션 수정' : '컬렉션 만들기',
          style: const TextStyle(
            fontFamily: 'Pretendard',
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: Color(0xFF000000),
            letterSpacing: -0.5,
          ),
        ),
        centerTitle: false,
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '제목',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFF374151)),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _titleCtrl,
                    maxLength: 30,
                    decoration: InputDecoration(
                      hintText: '예: 비 오는 날 가기 좋은 곳',
                      filled: true,
                      fillColor: const Color(0xFFF3F4F6),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      counterText: '',
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    '부제목 (선택)',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFF374151)),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _subtitleCtrl,
                    maxLength: 50,
                    decoration: InputDecoration(
                      hintText: '예: 창밖 보면서 파전에 막걸리 어때요',
                      filled: true,
                      fillColor: const Color(0xFFF3F4F6),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      counterText: '',
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '매장 선택 (최소 $kCollectionMinRestaurants개)',
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFF374151)),
                      ),
                      Text(
                        '${_selected.length}/$kCollectionMaxRestaurants',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF9CA3AF)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _searchCtrl,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      hintText: '매장명, 위치, 음식종류 검색',
                      prefixIcon: const Icon(Icons.search, size: 18, color: Color(0xFF9CA3AF)),
                      filled: true,
                      fillColor: const Color(0xFFF3F4F6),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                  ),
                  if (_selected.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _selected
                          .map((r) => Chip(
                                label: Text(r.name, style: const TextStyle(fontSize: 12)),
                                onDeleted: () => _toggle(r),
                                backgroundColor: const Color(0xFFF3F4F6),
                                deleteIconColor: const Color(0xFF374151),
                                side: const BorderSide(color: Color(0xFFE5E7EB)),
                              ))
                          .toList(),
                    ),
                  ],
                  if (q.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    if (results.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 24),
                        child: Center(
                          child: Text('검색 결과가 없어요.', style: TextStyle(color: Color(0xFF9CA3AF))),
                        ),
                      )
                    else
                      ...results.map((r) {
                        final isSelected = _selected.any((e) => e.id == r.id);
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(r.name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                          subtitle: Text('${r.area} · ${r.category}', style: const TextStyle(fontSize: 12, color: Color(0xFF9CA3AF))),
                          trailing: Icon(
                            isSelected ? Icons.check_circle : Icons.add_circle_outline,
                            color: isSelected ? AppColors.primaryCta : const Color(0xFFD1D5DB),
                          ),
                          onTap: () => _toggle(r),
                        );
                      }),
                  ],
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 12)),
                  ],
                ],
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(20, 12, 20, MediaQuery.of(context).padding.bottom + 12),
            child: GestureDetector(
              onTap: _submitting ? null : _submit,
              child: Container(
                height: 52,
                decoration: BoxDecoration(
                  color: _submitting ? const Color(0xFFE5E7EB) : AppColors.primaryCta,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Center(
                  child: _submitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : Text(
                          _isEditing ? '수정 완료' : '컬렉션 올리기',
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: Colors.white),
                        ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
