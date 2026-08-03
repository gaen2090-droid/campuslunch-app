import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/restaurant.dart';
import '../providers/app_provider.dart';

/// 게시글 작성 시 관련 매장 1개를 선택하는 검색 바텀시트
class RestaurantPickerSheet extends StatefulWidget {
  const RestaurantPickerSheet({super.key});

  static Future<Restaurant?> show(BuildContext context) {
    return showModalBottomSheet<Restaurant>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const RestaurantPickerSheet(),
    );
  }

  @override
  State<RestaurantPickerSheet> createState() => _RestaurantPickerSheetState();
}

class _RestaurantPickerSheetState extends State<RestaurantPickerSheet> {
  final _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final all = context.watch<AppProvider>().restaurants;
    final query = _searchCtrl.text.trim().toLowerCase();
    final results = query.isEmpty
        ? all
        : all.where((r) => r.name.toLowerCase().contains(query)).toList();

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).padding.bottom),
      child: Column(
        children: [
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 5,
            decoration: BoxDecoration(
              color: const Color(0xFFE5E7EB),
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
            child: Row(
              children: [
                const Text(
                  '관련 매장 선택',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF000000),
                  ),
                ),
                const Spacer(),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('닫기', style: TextStyle(color: Color(0xFF9CA3AF))),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Container(
              height: 44,
              decoration: BoxDecoration(
                color: const Color(0xFFF3F4F6),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const SizedBox(width: 12),
                  const Icon(Icons.search, size: 18, color: Color(0xFF9CA3AF)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _searchCtrl,
                      onChanged: (_) => setState(() {}),
                      decoration: const InputDecoration(
                        hintText: '매장명 검색',
                        border: InputBorder.none,
                        isDense: true,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: results.isEmpty
                ? const Center(
                    child: Text('검색 결과가 없어요.', style: TextStyle(color: Color(0xFF9CA3AF))),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    itemCount: results.length,
                    itemBuilder: (context, i) {
                      final r = results[i];
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(r.name,
                            style: const TextStyle(fontWeight: FontWeight.w700)),
                        subtitle: Text(
                          r.area == r.category ? r.area : '${r.area} · ${r.category}',
                          style: const TextStyle(fontSize: 12, color: Color(0xFF9CA3AF)),
                        ),
                        onTap: () => Navigator.pop(context, r),
                      );
                    },
                  ),
          ),
        ],
      ),
    ),
    );
  }
}
