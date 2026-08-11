import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/restaurant.dart';
import '../providers/app_provider.dart';
import 'owner_verify_sheet.dart';

/// 사장님 제보/마이페이지 화면 상단에 공용으로 쓰는 헤더 (여백 + 드롭다운).
/// 두 화면이 이 위젯을 그대로 호출해야 세로 위치가 실제로 동일해진다 —
/// 각자 SizedBox/Padding 수치를 따로 맞추는 방식은 우연히 값이 같을 뿐
/// 트리 구조가 달라 화면마다 어긋나기 쉽다.
class OwnerHeaderSection extends StatelessWidget {
  final List<Restaurant> ownedList;
  final Restaurant? selected;
  final VoidCallback? onSettingsTap;

  const OwnerHeaderSection({
    super.key,
    required this.ownedList,
    required this.selected,
    this.onSettingsTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
      child: OwnerRestaurantDropdown(
        ownedList: ownedList,
        selected: selected,
        onSettingsTap: onSettingsTap,
      ),
    );
  }
}

/// 사장님 제보/마이페이지 헤더에 공용으로 쓰는 매장 선택. 탭하면 표준 바텀시트로
/// 매장 목록 + 매장 추가 + 매장 삭제가 아래에서 올라온다.
class OwnerRestaurantDropdown extends StatelessWidget {
  final List<Restaurant> ownedList;
  final Restaurant? selected;
  final VoidCallback? onSettingsTap;
  /// 화면별로 톱니바퀴 유무에 따라 화살표 수직 정렬이 달라 보이는 걸 보정하는 값.
  /// 음수면 위로 이동.
  final double arrowOffsetY;

  const OwnerRestaurantDropdown({
    super.key,
    required this.ownedList,
    required this.selected,
    this.onSettingsTap,
    this.arrowOffsetY = 0,
  });

  void _openSheet(BuildContext context) {
    final provider = context.read<AppProvider>();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _RestaurantSheet(
        ownedList: ownedList,
        selected: selected,
        onSelect: (r) => provider.selectOwnerRestaurant(r.id.toString()),
        onAddRestaurant: () => OwnerVerifyScreen.show(context),
        onReleaseRestaurant: (restaurantId) =>
            provider.releaseOwnerRestaurant(restaurantId),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // 커뮤니티 헤더(_header() in community_screen.dart)와 동일하게, 텍스트는
    // 별도 높이 보정 없이 바깥 Row(기본 center 정렬)에 그대로 맡긴다.
    return Row(
      children: [
        Expanded(
          child: InkWell(
            onTap: () => _openSheet(context),
            child: Row(
              children: [
                Flexible(
                  child: Text(
                    selected?.name ?? '사장님',
                    style: const TextStyle(
                      fontFamily: 'Pretendard',
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF000000),
                      letterSpacing: -0.8,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 4),
                Transform.translate(
                  offset: Offset(0, arrowOffsetY),
                  child: const Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFF000000)),
                ),
              ],
            ),
          ),
        ),
        // if/else로 서로 다른 위젯(IconButton vs SizedBox)을 넣으면 실제
        // 레이아웃 박스 크기가 우연히 같을 뿐 트리가 달라 어긋나기 쉽다.
        // 항상 같은 IconButton을 렌더링하고, 톱니바퀴가 없을 때는 아이콘만
        // 투명하게 숨겨 두 화면이 물리적으로 동일한 트리를 갖게 한다.
        IconButton(
          onPressed: onSettingsTap,
          icon: Icon(
            Icons.settings_outlined,
            size: 24,
            color: onSettingsTap == null
                ? Colors.transparent
                : const Color(0xFF000000),
          ),
        ),
      ],
    );
  }
}

class _RestaurantSheet extends StatefulWidget {
  final List<Restaurant> ownedList;
  final Restaurant? selected;
  final void Function(Restaurant) onSelect;
  final VoidCallback onAddRestaurant;
  final Future<String?> Function(String restaurantId) onReleaseRestaurant;

  const _RestaurantSheet({
    required this.ownedList,
    required this.selected,
    required this.onSelect,
    required this.onAddRestaurant,
    required this.onReleaseRestaurant,
  });

  @override
  State<_RestaurantSheet> createState() => _RestaurantSheetState();
}

class _RestaurantSheetState extends State<_RestaurantSheet> {
  bool _confirmRelease = false;
  bool _releasing = false;

  Future<void> _releaseRestaurant() async {
    final selected = widget.selected;
    if (selected == null) return;
    setState(() => _releasing = true);
    final err = await widget.onReleaseRestaurant(selected.id.toString());
    if (!mounted) return;
    setState(() {
      _releasing = false;
      _confirmRelease = false;
    });
    Navigator.pop(context);
    if (err != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).padding.bottom + 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 12),
            Center(
              child: Container(
                width: 40,
                height: 5,
                decoration: BoxDecoration(
                  color: const Color(0xFFE5E7EB),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 20, 20, 12),
              child: Text(
                '내 가게',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF000000),
                ),
              ),
            ),
            if (_confirmRelease)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: _ReleaseConfirm(
                  restaurantName: widget.selected?.name ?? '',
                  isLastRestaurant: widget.ownedList.length == 1,
                  releasing: _releasing,
                  onCancel: () => setState(() => _confirmRelease = false),
                  onConfirm: _releaseRestaurant,
                ),
              )
            else ...[
              if (widget.ownedList.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF3F4F6),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Center(
                      child: Text(
                        '변경할 가게가 없습니다',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF9CA3AF),
                        ),
                      ),
                    ),
                  ),
                )
              else
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    itemCount: widget.ownedList.length,
                    itemBuilder: (context, i) {
                      final r = widget.ownedList[i];
                      final isSelected = r.id.toString() == widget.selected?.id.toString();
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(r.name,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: isSelected
                                  ? const Color(0xFF000000)
                                  : const Color(0xFF6B7280),
                            )),
                        trailing: isSelected
                            ? const Icon(Icons.check, color: Color(0xFF000000))
                            : null,
                        onTap: () {
                          widget.onSelect(r);
                          Navigator.pop(context);
                        },
                      );
                    },
                  ),
                ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: GestureDetector(
                  onTap: () {
                    Navigator.pop(context);
                    widget.onAddRestaurant();
                  },
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF3F4F6),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Center(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.add, size: 18, color: Color(0xFF374151)),
                          SizedBox(width: 6),
                          Text(
                            '새 가게 추가',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF374151),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              if (widget.selected != null) ...[
                const SizedBox(height: 12),
                Center(
                  child: GestureDetector(
                    onTap: () => setState(() => _confirmRelease = true),
                    child: const Text(
                      '매장 삭제',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFFEF4444),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

class _ReleaseConfirm extends StatelessWidget {
  final String restaurantName;
  final bool isLastRestaurant;
  final bool releasing;
  final VoidCallback onCancel;
  final VoidCallback? onConfirm;

  const _ReleaseConfirm({
    required this.restaurantName,
    required this.isLastRestaurant,
    required this.releasing,
    required this.onCancel,
    required this.onConfirm,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF5F5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFECACA)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            isLastRestaurant
                ? '매장을 삭제할까요?\n삭제 후에는 일반 소비자 화면으로 돌아가요.'
                : '\'$restaurantName\' 등록을 삭제할까요?\n앱에는 매장이 그대로 남아요.',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: Color(0xFF374151),
              height: 1.45,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: releasing ? null : onCancel,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE5E7EB)),
                    ),
                    child: const Center(
                      child: Text(
                        '취소',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF6B7280),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: GestureDetector(
                  onTap: releasing ? null : onConfirm,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEF4444),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: releasing
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text(
                              '삭제',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                              ),
                            ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
