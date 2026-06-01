import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../widgets/owner_verify_sheet.dart';

class OwnerScreen extends StatefulWidget {
  const OwnerScreen({super.key});

  @override
  State<OwnerScreen> createState() => _OwnerScreenState();
}

class _OwnerScreenState extends State<OwnerScreen> {
  String? _selectedId;
  String? _toast;
  bool _showAddSheet = false;

  static const _opts = [
    _StatusOpt(
      key: '여유로움',
      dotColor: Color(0xFF22C55E),
      activeBg: Color(0xFFF0FDF4),
      activeRing: Color(0xFF86EFAC),
      activeText: Color(0xFF16A34A),
      activeLabelBg: Color(0xFF22C55E),
    ),
    _StatusOpt(
      key: '약간혼잡',
      dotColor: Color(0xFFF59E0B),
      activeBg: Color(0xFFFFFBEB),
      activeRing: Color(0xFFFCD34D),
      activeText: Color(0xFFD97706),
      activeLabelBg: Color(0xFFF59E0B),
    ),
    _StatusOpt(
      key: '자리없음',
      dotColor: Color(0xFFEF4444),
      activeBg: Color(0xFFFFF5F5),
      activeRing: Color(0xFFFCA5A5),
      activeText: Color(0xFFEF4444),
      activeLabelBg: Color(0xFFEF4444),
    ),
  ];

  void _showToast(String msg) {
    setState(() => _toast = msg);
    Future.delayed(const Duration(milliseconds: 1800), () {
      if (mounted) setState(() => _toast = null);
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final ownerIds = provider.ownerRestaurantIds;
    final allRestaurants = provider.restaurants;

    final ownedList = ownerIds
        .map((rid) {
          try {
            return allRestaurants.firstWhere((r) => r.id.toString() == rid);
          } catch (_) {
            return null;
          }
        })
        .whereType<dynamic>()
        .where((r) => r != null)
        .toList();

    if (ownedList.isEmpty) {
      return const Scaffold(
        backgroundColor: Color(0xFFFAFAF8),
        body: Center(
          child: Text(
            '매장 정보를 불러올 수 없어요.',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: Color(0xFF9CA3AF),
            ),
          ),
        ),
      );
    }

    final selectedId = _selectedId ?? ownerIds.first;
    final restaurant = ownedList.firstWhere(
      (r) => r.id.toString() == selectedId,
      orElse: () => ownedList.first,
    );
    final current = restaurant.status;

    return Scaffold(
      backgroundColor: const Color(0xFFFAFAF8),
      body: Stack(
        children: [
          SafeArea(
            bottom: false,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Restaurant tab pills
                if (ownedList.length > 1) ...[
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.fromLTRB(24, 32, 24, 0),
                    child: Row(
                      children: ownedList.map((r) {
                        final isSelected = r.id.toString() == selectedId;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: GestureDetector(
                            onTap: () => setState(() => _selectedId = r.id.toString()),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 150),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 8),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? const Color(0xFF111827)
                                    : Colors.white,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: isSelected
                                      ? const Color(0xFF111827)
                                      : const Color(0xFFE5E7EB),
                                ),
                              ),
                              child: Text(
                                r.name,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w900,
                                  color: isSelected
                                      ? Colors.white
                                      : const Color(0xFF6B7280),
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 6),
                ] else
                  const SizedBox(height: 32),

                // Header
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '내 매장',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5,
                          color: Color(0xFF9CA3AF),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        restaurant.name,
                        style: const TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -1.28,
                          height: 1.18,
                          color: Color(0xFF111827),
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        '지금 매장 상태를 선택해주세요',
                        style: TextStyle(fontSize: 14, color: Color(0xFF6B7280)),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 40),

                // Status buttons
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      children: _opts.map((opt) {
                        final selected = current == opt.key;
                        return Expanded(
                          child: Padding(
                            padding: const EdgeInsets.only(bottom: 16),
                            child: GestureDetector(
                              onTap: () {
                                if (selected) return;
                                provider.reportStatus(restaurant.id, opt.key);
                                _showToast(
                                    '\'${restaurant.name}\' 혼잡도를 \'${opt.key}\'으로 업데이트했어요');
                              },
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                decoration: BoxDecoration(
                                  color: selected ? opt.activeBg : Colors.white,
                                  borderRadius: BorderRadius.circular(28),
                                  border: Border.all(
                                    color: selected
                                        ? opt.activeRing
                                        : const Color(0xFFE5E7EB),
                                    width: selected ? 2 : 1,
                                  ),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 28),
                                  child: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Row(
                                        children: [
                                          Container(
                                            width: 20,
                                            height: 20,
                                            decoration: BoxDecoration(
                                              color: opt.dotColor,
                                              shape: BoxShape.circle,
                                            ),
                                          ),
                                          const SizedBox(width: 16),
                                          Text(
                                            opt.key,
                                            style: TextStyle(
                                              fontSize: 26,
                                              fontWeight: FontWeight.w900,
                                              letterSpacing: -0.78,
                                              color: selected
                                                  ? opt.activeText
                                                  : const Color(0xFF374151),
                                            ),
                                          ),
                                        ],
                                      ),
                                      if (selected)
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 12, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: opt.activeLabelBg,
                                            borderRadius: BorderRadius.circular(20),
                                          ),
                                          child: const Text(
                                            '현재',
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w900,
                                              color: Colors.white,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),

                // Bottom buttons
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    24,
                    0,
                    24,
                    MediaQuery.of(context).padding.bottom + 40,
                  ),
                  child: Column(
                    children: [
                      GestureDetector(
                        onTap: () => setState(() => _showAddSheet = true),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 10),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: const Color(0xFFE5E7EB)),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.add,
                                  size: 16, color: Color(0xFF374151)),
                              SizedBox(width: 6),
                              Text(
                                '매장 추가',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w900,
                                  color: Color(0xFF374151),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      GestureDetector(
                        onTap: () => provider.logout(),
                        child: const Text(
                          '로그아웃',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFFC1BDB7),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Toast
          if (_toast != null)
            Positioned(
              bottom: MediaQuery.of(context).padding.bottom + 40,
              left: 20,
              right: 20,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF111827),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    _toast!,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ),

          // Verify sheet overlay
          if (_showAddSheet)
            Positioned.fill(
              child: OwnerVerifySheet(
                onClose: () => setState(() => _showAddSheet = false),
                onSuccess: (restaurantId) {
                  setState(() => _showAddSheet = false);
                  _showToast('매장이 추가됐어요');
                },
              ),
            ),
        ],
      ),
    );
  }
}

class _StatusOpt {
  final String key;
  final Color dotColor;
  final Color activeBg;
  final Color activeRing;
  final Color activeText;
  final Color activeLabelBg;

  const _StatusOpt({
    required this.key,
    required this.dotColor,
    required this.activeBg,
    required this.activeRing,
    required this.activeText,
    required this.activeLabelBg,
  });
}
