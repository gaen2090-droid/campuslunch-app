import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/restaurant.dart';
import '../providers/app_provider.dart';
import '../utils/crowd_status_label.dart';
import '../widgets/load_error_view.dart';
import '../widgets/owner_restaurant_dropdown.dart';
import '../widgets/owner_verify_sheet.dart';
import '../widgets/report_sheet.dart';
import 'detail_screen.dart';

/// 사장님 제보 탭: 소유 매장 선택 + 혼잡도 제보 + 입장 가능 인원 반영.
/// 헤더는 사장님 마이페이지(owner_my_screen.dart)와 동일한 드롭다운 톤을 사용.
class OwnerScreen extends StatefulWidget {
  const OwnerScreen({super.key});

  @override
  State<OwnerScreen> createState() => _OwnerScreenState();
}

class _OwnerScreenState extends State<OwnerScreen> {
  String? _toast;
  final _seatCtrl = TextEditingController();
  bool _seatSubmitting = false;
  bool _statusSubmitting = false;
  String? _seatSuccessMessage;
  Timer? _refreshTicker;

  @override
  void initState() {
    super.initState();
    // "n분 전" 표시 갱신 + 최신 혼잡도 상태 동기화 (유저 홈 화면과 동일한 1분 주기)
    _refreshTicker = Timer.periodic(const Duration(minutes: 1), (_) {
      if (!mounted) return;
      context.read<AppProvider>().refreshRestaurants();
    });
  }

  @override
  void dispose() {
    _seatCtrl.dispose();
    _refreshTicker?.cancel();
    super.dispose();
  }

  // 유저 제보 시트(report_sheet.dart)의 reportOptions를 그대로 사용 — 두 화면이 항상 동일하게 유지됨.
  static const _opts = reportOptions;

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
        .whereType<Restaurant>()
        .toList();

    if (ownedList.isEmpty) {
      if (ownerIds.isNotEmpty && allRestaurants.isEmpty) {
        if (provider.restaurantsLoading) {
          return const Scaffold(
            backgroundColor: Colors.white,
            body: Center(child: CircularProgressIndicator()),
          );
        }
        return Scaffold(
          backgroundColor: Colors.white,
          body: LoadErrorView(
            message: provider.restaurantsLoadFailed
                ? '네트워크 연결을 확인해주세요.'
                : '매장 정보를 불러올 수 없어요.',
            onRetry: () async {
              await provider.refreshRestaurants();
              await provider.refreshOwnerState();
            },
          ),
        );
      }
      return Scaffold(
        backgroundColor: Colors.white,
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
                    await provider.refreshOwnerState();
                    if (!mounted) return;
                    setState(() {});
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF111827),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Text(
                      '다시 불러오기',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                GestureDetector(
                  onTap: () => OwnerVerifyScreen.show(context),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFE5E7EB)),
                    ),
                    child: const Text(
                      '사장님 인증하기',
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

    final selectedId = provider.selectedOwnerRestaurantId ?? ownerIds.first;
    final restaurant = ownedList.firstWhere(
      (r) => r.id.toString() == selectedId,
      orElse: () => ownedList.first,
    );
    // 아직 혼잡도 제보/업데이트가 없는 매장은 어떤 옵션도 선택되지 않은 상태로 보여준다.
    final current = restaurant.hasCrowdUpdate ? restaurant.status : null;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        bottom: false,
        child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: () => FocusScope.of(context).unfocus(),
        child: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.only(bottom: 100),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── 매장 선택 헤더 (마이페이지와 완전히 동일한 공용 위젯) ──
                OwnerHeaderSection(
                  ownedList: ownedList,
                  selected: restaurant,
                ),

                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const Expanded(
                        child: Text(
                          '지금 매장 상태를 선택해주세요',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF6B7280),
                          ),
                        ),
                      ),
                      GestureDetector(
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => DetailScreen(restaurant: restaurant),
                          ),
                        ),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF3F4F6),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: const Color(0xFFE5E7EB)),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.visibility_outlined,
                                  size: 13, color: Color(0xFF374151)),
                              SizedBox(width: 4),
                              Text(
                                '소비자 화면 보기',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w900,
                                  color: Color(0xFF374151),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    children: [
                      ..._opts.map((opt) {
                        final selected = current == opt.status;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: GestureDetector(
                            onTap: () async {
                              if (_statusSubmitting) return;
                              setState(() => _statusSubmitting = true);
                              final err = await provider.reportStatus(
                                restaurant.id,
                                opt.status,
                              );
                              if (!context.mounted) return;
                              setState(() => _statusSubmitting = false);
                              if (err != null) {
                                _showToast(err);
                                return;
                              }
                              _showToast(
                                  '\'${restaurant.name}\' 혼잡도를 \'${opt.status}\'으로 업데이트했어요');
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 20, vertical: 18),
                              decoration: BoxDecoration(
                                color: selected ? opt.bgColor : Colors.white,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: selected
                                      ? opt.borderColor
                                      : const Color(0xFFE5E7EB),
                                  width: selected ? 2 : 1,
                                ),
                                boxShadow: selected
                                    ? null
                                    : [
                                        BoxShadow(
                                          color: Colors.black.withAlpha(8),
                                          blurRadius: 8,
                                          offset: const Offset(0, 1),
                                        ),
                                      ],
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Row(
                                    children: [
                                      Container(
                                        width: 16,
                                        height: 16,
                                        decoration: BoxDecoration(
                                          color: opt.textColor,
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                      const SizedBox(width: 14),
                                      Flexible(
                                        child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Text(
                                            opt.label,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              fontSize: 18,
                                              fontWeight: FontWeight.w900,
                                              letterSpacing: -0.5,
                                              color: selected
                                                  ? opt.textColor
                                                  : const Color(0xFF374151),
                                            ),
                                          ),
                                          Text(
                                            opt.subtitle,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w500,
                                              color: selected
                                                  ? opt.textColor.withAlpha(180)
                                                  : const Color(0xFF9CA3AF),
                                            ),
                                          ),
                                        ],
                                        ),
                                      ),
                                    ],
                                    ),
                                  ),
                                  if (selected) ...[
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: opt.textColor,
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: Text(
                                        '${restaurant.crowdBaseSource == 'owner' ? '사장님' : '소비자'} · '
                                        '${formatUpdateAgeFromDateTime(restaurant.updatedAt)}',
                                        style: const TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w900,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        );
                      }),
                      const SizedBox(height: 4),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: const Color(0xFFE5E7EB)),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withAlpha(8),
                              blurRadius: 8,
                              offset: const Offset(0, 1),
                            ),
                          ],
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
                            const SizedBox(height: 14),
                            TextField(
                              controller: _seatCtrl,
                              keyboardType: TextInputType.number,
                              textAlign: TextAlign.center,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                              ],
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w900,
                                color: Color(0xFF111827),
                              ),
                              onChanged: (_) => setState(() {
                                _seatSuccessMessage = null;
                              }),
                              decoration: InputDecoration(
                                hintText: '0',
                                hintStyle: const TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w900,
                                  color: Color(0xFFD1D5DB),
                                ),
                                suffixText: '명',
                                suffixStyle: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.grey.shade700,
                                ),
                                filled: true,
                                fillColor: const Color(0xFFF9FAFB),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 14,
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: const BorderSide(
                                    color: Color(0xFFE5E7EB),
                                  ),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: const BorderSide(
                                    color: Color(0xFFE5E7EB),
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: const BorderSide(
                                    color: Color(0xFF111827),
                                    width: 1.5,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 10),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 10),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF3F4F6),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                _seatPreviewText(),
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF374151),
                                ),
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
                                      ? const Color(0xFF9CA3AF)
                                      : const Color(0xFF111827),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: Center(
                                  child: _seatSubmitting
                                      ? const SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.white,
                                          ),
                                        )
                                      : const Text(
                                          '반영하기',
                                          style: TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w900,
                                            color: Colors.white,
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
                                  color: Color(0xFF374151),
                                  height: 1.4,
                                ),
                              ),
                            ],
                          ],
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
              bottom: 40,
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
        ],
      ),
      ),
      ),
    );
  }
}
