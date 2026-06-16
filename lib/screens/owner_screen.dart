import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  final _seatCtrl = TextEditingController();
  bool _seatSubmitting = false;
  bool _statusSubmitting = false;
  String? _seatSuccessMessage;

  @override
  void dispose() {
    _seatCtrl.dispose();
    super.dispose();
  }

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

  int? _parseSeatInput() {
    final text = _seatCtrl.text.trim();
    if (text.isEmpty) return null;
    final value = int.tryParse(text);
    if (value == null || value < 0) return null;
    return value;
  }

  Future<void> _submitSeatUpdate(
    AppProvider provider,
    String restaurantId,
  ) async {
    final seats = _parseSeatInput();
    if (seats == null) {
      _showToast('0 이상의 숫자를 입력해주세요');
      return;
    }
    setState(() {
      _seatSubmitting = true;
      _seatSuccessMessage = null;
    });
    final err = await provider.submitOwnerSeatUpdate(restaurantId, seats);
    if (!mounted) return;
    setState(() => _seatSubmitting = false);
    if (err != null) {
      _showToast(err);
      return;
    }
    setState(() {
      _seatSuccessMessage = '입장 가능 인원이 반영되었어요.\n1시간 동안 유저 화면에 표시됩니다.';
    });
  }

  String _seatPreviewText() {
    final seats = _parseSeatInput();
    if (seats == null) return '지금 [   ]명 입장 가능해요';
    if (seats == 0) return '지금은 바로 입장이 어려워요.';
    return '지금 $seats명 입장 가능해요';
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
      return Scaffold(
        backgroundColor: const Color(0xFFFAFAF8),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  '매장 정보를 불러올 수 없어요.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF9CA3AF),
                  ),
                ),
                const SizedBox(height: 16),
                GestureDetector(
                  onTap: () async {
                    await provider.refreshRestaurants();
                    if (!mounted) return;
                    setState(() {});
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF9ECA8B),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Text(
                      '다시 불러오기',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF111827),
                      ),
                    ),
                  ),
                ),
              ],
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
                            onTap: () => setState(() {
                              _selectedId = r.id.toString();
                              _seatCtrl.clear();
                              _seatSuccessMessage = null;
                            }),
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

                // Status + 입장 가능 인원
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 0),
                    child: Column(
                      children: [
                        ..._opts.map((opt) {
                          final selected = current == opt.key;
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: GestureDetector(
                              onTap: () async {
                                if (selected || _statusSubmitting) return;
                                setState(() => _statusSubmitting = true);
                                final err = await provider.reportStatus(
                                  restaurant.id,
                                  opt.key,
                                );
                                if (!context.mounted) return;
                                setState(() => _statusSubmitting = false);
                                if (err != null) {
                                  _showToast(err);
                                  return;
                                }
                                _showToast(
                                    '\'${restaurant.name}\' 혼잡도를 \'${opt.key}\'으로 업데이트했어요');
                              },
                              child: AnimatedContainer(
                                height: 72,
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
                                  padding:
                                      const EdgeInsets.symmetric(horizontal: 28),
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
                                              fontSize: 22,
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
                                            borderRadius:
                                                BorderRadius.circular(20),
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
                          );
                        }),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: const Color(0xFFE5E7EB)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                '지금 몇 명까지 입장 가능한가요?',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF111827),
                                ),
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Expanded(
                                    child: TextField(
                                      controller: _seatCtrl,
                                      keyboardType: TextInputType.number,
                                      inputFormatters: [
                                        FilteringTextInputFormatter.digitsOnly,
                                      ],
                                      onChanged: (_) => setState(() {
                                        _seatSuccessMessage = null;
                                      }),
                                      decoration: InputDecoration(
                                        hintText: '0',
                                        filled: true,
                                        fillColor: const Color(0xFFF9FAFB),
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                          horizontal: 16,
                                          vertical: 14,
                                        ),
                                        border: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(14),
                                          borderSide: const BorderSide(
                                            color: Color(0xFFE5E7EB),
                                          ),
                                        ),
                                        enabledBorder: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(14),
                                          borderSide: const BorderSide(
                                            color: Color(0xFFE5E7EB),
                                          ),
                                        ),
                                        focusedBorder: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(14),
                                          borderSide: const BorderSide(
                                            color: Color(0xFF5E8C4A),
                                            width: 1.5,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Text(
                                    '명',
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.grey.shade700,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Text(
                                _seatPreviewText(),
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF6B7280),
                                ),
                              ),
                              const SizedBox(height: 14),
                              GestureDetector(
                                onTap: _seatSubmitting
                                    ? null
                                    : () => _submitSeatUpdate(
                                          provider,
                                          restaurant.id.toString(),
                                        ),
                                child: Container(
                                  width: double.infinity,
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 14),
                                  decoration: BoxDecoration(
                                    color: _seatSubmitting
                                        ? const Color(0xFFBFE0B0)
                                        : const Color(0xFF9ECA8B),
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: Center(
                                    child: _seatSubmitting
                                        ? const SizedBox(
                                            width: 20,
                                            height: 20,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: Color(0xFF111827),
                                            ),
                                          )
                                        : const Text(
                                            '반영하기',
                                            style: TextStyle(
                                              fontSize: 15,
                                              fontWeight: FontWeight.w900,
                                              color: Color(0xFF111827),
                                            ),
                                          ),
                                  ),
                                ),
                              ),
                              if (_seatSuccessMessage != null) ...[
                                const SizedBox(height: 12),
                                Text(
                                  _seatSuccessMessage!,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF5E8C4A),
                                    height: 1.4,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
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
