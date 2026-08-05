import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../models/restaurant.dart';
import '../providers/app_provider.dart';
import '../utils/business_hours.dart';
import '../widgets/keyboard_safe.dart';
import '../widgets/load_error_view.dart';
import '../widgets/owner_restaurant_dropdown.dart';
import 'detail_screen.dart';

/// 사장님 매장 관리 탭: 대표사진/메뉴사진/대표메뉴/영업시간/매장공지 편집.
class OwnerRestaurantManageScreen extends StatefulWidget {
  const OwnerRestaurantManageScreen({super.key});

  @override
  State<OwnerRestaurantManageScreen> createState() =>
      _OwnerRestaurantManageScreenState();
}

class _PickedImage {
  final Uint8List bytes;
  final String ext;
  const _PickedImage({required this.bytes, required this.ext});
}

class _OwnerRestaurantManageScreenState
    extends State<OwnerRestaurantManageScreen> {
  String? _toast;

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
      return const Scaffold(
        backgroundColor: Colors.white,
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

    final selectedId = provider.selectedOwnerRestaurantId ?? ownerIds.first;
    final restaurant = ownedList.firstWhere(
      (r) => r.id.toString() == selectedId,
      orElse: () => ownedList.first,
    );

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        bottom: false,
        child: Stack(
          children: [
            KeyboardDismissScroll(
              padding: const EdgeInsets.only(bottom: 40),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  OwnerHeaderSection(
                    ownedList: ownedList,
                    selected: restaurant,
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            const Expanded(
                              child: Text(
                                '매장 관리',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w900,
                                  color: Color(0xFF000000),
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
                        const SizedBox(height: 4),
                        const Text(
                          '사진·메뉴·영업시간·공지를 직접 관리할 수 있어요.',
                          style: TextStyle(
                            fontSize: 13,
                            color: Color(0xFF9CA3AF),
                          ),
                        ),
                      ],
                    ),
                  ),
                  _MainPhotoSection(
                    key: ValueKey('photo_${restaurant.id}'),
                    restaurant: restaurant,
                    onSaved: _showToast,
                  ),
                  _MenuPhotoSection(
                    key: ValueKey('menuphoto_${restaurant.id}'),
                    restaurant: restaurant,
                    onSaved: _showToast,
                  ),
                  _MenuSection(
                    key: ValueKey('menu_${restaurant.id}'),
                    restaurant: restaurant,
                    onSaved: _showToast,
                  ),
                  _HoursSection(
                    key: ValueKey('hours_${restaurant.id}'),
                    restaurant: restaurant,
                    onSaved: _showToast,
                  ),
                  _NoticeSection(
                    key: ValueKey('notice_${restaurant.id}'),
                    restaurant: restaurant,
                    onSaved: _showToast,
                  ),
                ],
              ),
            ),
            if (_toast != null)
              Positioned(
                left: 20,
                right: 20,
                bottom: 24,
                child: _Toast(message: _toast!),
              ),
          ],
        ),
      ),
    );
  }
}

void _showFullImage(BuildContext context, {String? url, Uint8List? bytes}) {
  showDialog(
    context: context,
    barrierColor: Colors.black87,
    builder: (context) => GestureDetector(
      onTap: () => Navigator.pop(context),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Stack(
          children: [
            Center(
              child: InteractiveViewer(
                child: url != null
                    ? Image.network(url, fit: BoxFit.contain)
                    : Image.memory(bytes!, fit: BoxFit.contain),
              ),
            ),
            Positioned(
              top: 40,
              right: 16,
              child: GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: const BoxDecoration(
                    color: Colors.black54,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.close, color: Colors.white),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _Toast extends StatelessWidget {
  final String message;
  const _Toast({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFF000000),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget child;
  const _SectionCard({required this.title, this.subtitle, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w900,
              color: Color(0xFF000000),
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(
              subtitle!,
              style: const TextStyle(fontSize: 12, color: Color(0xFF9CA3AF)),
            ),
          ],
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _SaveButton extends StatelessWidget {
  final bool loading;
  final VoidCallback? onTap;
  const _SaveButton({required this.loading, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null && !loading;
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        width: double.infinity,
        height: 44,
        decoration: BoxDecoration(
          color: enabled ? const Color(0xFF000000) : const Color(0xFFE5E7EB),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(
          child: loading
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : Text(
                  '저장',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    color: enabled ? Colors.white : const Color(0xFF9CA3AF),
                  ),
                ),
        ),
      ),
    );
  }
}

// ── 1. 대표사진 ──

class _MainPhotoSection extends StatefulWidget {
  final Restaurant restaurant;
  final ValueChanged<String> onSaved;
  const _MainPhotoSection({super.key, required this.restaurant, required this.onSaved});

  @override
  State<_MainPhotoSection> createState() => _MainPhotoSectionState();
}

class _MainPhotoSectionState extends State<_MainPhotoSection> {
  _PickedImage? _picked;
  bool _saving = false;
  bool _reverting = false;

  Future<void> _pick() async {
    final file = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (file == null) return;
    final bytes = await file.readAsBytes();
    final ext = file.name.contains('.') ? file.name.split('.').last : 'jpg';
    if (!mounted) return;
    setState(() => _picked = _PickedImage(bytes: bytes, ext: ext));
  }

  Future<void> _save() async {
    final picked = _picked;
    if (picked == null) return;
    setState(() => _saving = true);
    final err = await context.read<AppProvider>().ownerUpdateRestaurantPhoto(
          widget.restaurant.id,
          bytes: picked.bytes,
          ext: picked.ext,
        );
    if (!mounted) return;
    setState(() {
      _saving = false;
      if (err == null) _picked = null;
    });
    widget.onSaved(err ?? '대표사진이 변경되었어요.');
  }

  Future<void> _revertToGoogle() async {
    setState(() => _reverting = true);
    final err = await context
        .read<AppProvider>()
        .ownerRevertRestaurantPhotoToGoogle(widget.restaurant.id);
    if (!mounted) return;
    setState(() {
      _reverting = false;
      if (err == null) _picked = null;
    });
    widget.onSaved(err ?? '구글맵 사진으로 되돌렸어요.');
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.restaurant;
    return _SectionCard(
      title: '대표사진',
      subtitle: '기본값은 구글맵 사진이에요. 직접 등록하면 "출처: 사장님"으로 표시돼요.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: () {
              if (_picked != null) {
                _showFullImage(context, bytes: _picked!.bytes);
              } else if (r.imageUrl.isNotEmpty) {
                _showFullImage(context, url: r.imageUrl);
              }
            },
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                width: double.infinity,
                height: 160,
                child: _picked != null
                    ? Image.memory(_picked!.bytes, fit: BoxFit.cover)
                    : (r.imageUrl.isNotEmpty
                        ? Image.network(
                            r.imageUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                              color: const Color(0xFFF3F4F6),
                              child: const Icon(Icons.image_not_supported_outlined,
                                  color: Color(0xFF9CA3AF)),
                            ),
                          )
                        : Container(color: const Color(0xFFF3F4F6))),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            r.imageSource == 'owner' ? '현재 출처: 사장님' : '현재 출처: Google Maps',
            style: const TextStyle(fontSize: 11, color: Color(0xFF9CA3AF)),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: _pick,
                  child: Container(
                    height: 40,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF9FAFB),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFE5E7EB)),
                    ),
                    child: const Center(
                      child: Text(
                        '변경',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF000000),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              if (r.imageSource == 'owner' && r.googleImageUrl.isNotEmpty) ...[
                const SizedBox(width: 8),
                Expanded(
                  child: GestureDetector(
                    onTap: _reverting ? null : _revertToGoogle,
                    child: Container(
                      height: 40,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF9FAFB),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFE5E7EB)),
                      ),
                      child: Center(
                        child: _reverting
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Text(
                                '구글맵 사진으로 되돌리기',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF6B7280),
                                ),
                              ),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
          if (_picked != null) ...[
            const SizedBox(height: 10),
            _SaveButton(loading: _saving, onTap: _save),
          ],
        ],
      ),
    );
  }
}

// ── 2. 메뉴 사진 (최대 3장) ──

class _MenuPhotoSection extends StatefulWidget {
  final Restaurant restaurant;
  final ValueChanged<String> onSaved;
  const _MenuPhotoSection({super.key, required this.restaurant, required this.onSaved});

  @override
  State<_MenuPhotoSection> createState() => _MenuPhotoSectionState();
}

class _MenuPhotoSectionState extends State<_MenuPhotoSection> {
  static const _maxImages = 3;
  late List<String> _existingUrls;
  final List<_PickedImage> _newImages = [];
  bool _saving = false;
  bool _dirty = false;

  @override
  void initState() {
    super.initState();
    _existingUrls = List.from(widget.restaurant.menuPhotoUrls);
  }

  int get _totalCount => _existingUrls.length + _newImages.length;

  Future<void> _pick() async {
    if (_totalCount >= _maxImages) return;
    final remaining = _maxImages - _totalCount;
    final picker = ImagePicker();
    final picked = remaining == 1
        ? await picker.pickImage(source: ImageSource.gallery).then(
            (f) => f == null ? const <XFile>[] : [f])
        : await picker.pickMultiImage(limit: remaining);
    if (picked.isEmpty) return;
    final loaded = <_PickedImage>[];
    for (final file in picked.take(remaining)) {
      final bytes = await file.readAsBytes();
      final ext = file.name.contains('.') ? file.name.split('.').last : 'jpg';
      loaded.add(_PickedImage(bytes: bytes, ext: ext));
    }
    if (!mounted) return;
    setState(() {
      _newImages.addAll(loaded);
      _dirty = true;
    });
  }

  void _removeExisting(int index) {
    setState(() {
      _existingUrls.removeAt(index);
      _dirty = true;
    });
  }

  void _removeNew(int index) {
    setState(() {
      _newImages.removeAt(index);
      _dirty = true;
    });
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final err = await context.read<AppProvider>().ownerUpdateMenuPhotos(
          widget.restaurant.id,
          existingUrls: _existingUrls,
          newImages: _newImages
              .map((e) => (bytes: e.bytes, ext: e.ext))
              .toList(),
        );
    if (!mounted) return;
    if (err == null) {
      // refreshRestaurants()가 이미 완료된 뒤라 provider가 최신 URL(스토리지 업로드
      // 결과로 치환된 값)을 들고 있음 — 로컬 복사본(_existingUrls)을 그걸로 다시 맞춘다.
      // 안 그러면 저장은 성공했는데 화면엔 계속 예전 상태(또는 로컬 미리보기)만 보인다.
      final fresh = context.read<AppProvider>().restaurants.firstWhere(
            (x) => x.id == widget.restaurant.id,
            orElse: () => widget.restaurant,
          );
      setState(() {
        _existingUrls = List.from(fresh.menuPhotoUrls);
        _newImages.clear();
        _dirty = false;
        _saving = false;
      });
    } else {
      setState(() => _saving = false);
    }
    widget.onSaved(err ?? '메뉴 사진이 저장되었어요.');
  }

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: '메뉴 사진',
      subtitle: '최대 3장까지 등록할 수 있어요. (선택)',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (var i = 0; i < _existingUrls.length; i++)
                Stack(
                  children: [
                    GestureDetector(
                      onTap: () => _showFullImage(context, url: _existingUrls[i]),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.network(
                          _existingUrls[i],
                          width: 84,
                          height: 84,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            width: 84,
                            height: 84,
                            color: const Color(0xFFF3F4F6),
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      top: 4,
                      right: 4,
                      child: GestureDetector(
                        onTap: () => _removeExisting(i),
                        child: Container(
                          padding: const EdgeInsets.all(2),
                          decoration: const BoxDecoration(
                              color: Colors.black54, shape: BoxShape.circle),
                          child: const Icon(Icons.close, size: 14, color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                ),
              for (var i = 0; i < _newImages.length; i++)
                Stack(
                  children: [
                    GestureDetector(
                      onTap: () => _showFullImage(context, bytes: _newImages[i].bytes),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.memory(_newImages[i].bytes,
                            width: 84, height: 84, fit: BoxFit.cover),
                      ),
                    ),
                    Positioned(
                      top: 4,
                      right: 4,
                      child: GestureDetector(
                        onTap: () => _removeNew(i),
                        child: Container(
                          padding: const EdgeInsets.all(2),
                          decoration: const BoxDecoration(
                              color: Colors.black54, shape: BoxShape.circle),
                          child: const Icon(Icons.close, size: 14, color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                ),
              if (_totalCount < _maxImages)
                GestureDetector(
                  onTap: _pick,
                  child: Container(
                    width: 84,
                    height: 84,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF9FAFB),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE5E7EB)),
                    ),
                    child: const Icon(Icons.add_a_photo_outlined, color: Color(0xFF9CA3AF)),
                  ),
                ),
            ],
          ),
          if (_dirty) ...[
            const SizedBox(height: 12),
            _SaveButton(loading: _saving, onTap: _save),
          ],
        ],
      ),
    );
  }
}

// ── 3. 대표 메뉴 (이름 + 가격) ──

class _MenuSection extends StatefulWidget {
  final Restaurant restaurant;
  final ValueChanged<String> onSaved;
  const _MenuSection({super.key, required this.restaurant, required this.onSaved});

  @override
  State<_MenuSection> createState() => _MenuSectionState();
}

class _MenuRow {
  final TextEditingController nameCtrl;
  final TextEditingController priceCtrl;
  _MenuRow({String name = '', String price = ''})
      : nameCtrl = TextEditingController(text: name),
        priceCtrl = TextEditingController(text: price);

  void dispose() {
    nameCtrl.dispose();
    priceCtrl.dispose();
  }
}

class _MenuSectionState extends State<_MenuSection> {
  late List<_MenuRow> _rows;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _rows = widget.restaurant.menu.isEmpty
        ? [_MenuRow()]
        : widget.restaurant.menu
            .map((m) => _MenuRow(name: m.name, price: m.price.toString()))
            .toList();
  }

  @override
  void dispose() {
    for (final r in _rows) {
      r.dispose();
    }
    super.dispose();
  }

  void _addRow() => setState(() => _rows.add(_MenuRow()));

  void _removeRow(int index) {
    setState(() {
      _rows[index].dispose();
      _rows.removeAt(index);
    });
  }

  Future<void> _save() async {
    final items = <MenuItem>[];
    for (final row in _rows) {
      final name = row.nameCtrl.text.trim();
      if (name.isEmpty) continue;
      final price = int.tryParse(row.priceCtrl.text.trim()) ?? 0;
      items.add(MenuItem(name: name, price: price));
    }
    setState(() => _saving = true);
    final err = await context
        .read<AppProvider>()
        .ownerUpdateRestaurantMenu(widget.restaurant.id, items);
    if (!mounted) return;
    setState(() => _saving = false);
    widget.onSaved(err ?? '대표 메뉴가 저장되었어요.');
  }

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: '대표 메뉴',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < _rows.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: TextField(
                      controller: _rows[i].nameCtrl,
                      textInputAction: TextInputAction.next,
                      onEditingComplete: () =>
                          FocusScope.of(context).nextFocus(),
                      decoration: InputDecoration(
                        hintText: '메뉴명',
                        isDense: true,
                        contentPadding:
                            const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                        border: const OutlineInputBorder(),
                        suffixIcon: keyboardHideButton(),
                        suffixIconConstraints: const BoxConstraints(
                          minWidth: 36,
                          minHeight: 36,
                        ),
                      ),
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 2,
                    child: TextField(
                      controller: _rows[i].priceCtrl,
                      keyboardType: TextInputType.number,
                      textInputAction: TextInputAction.done,
                      onEditingComplete: () =>
                          FocusManager.instance.primaryFocus?.unfocus(),
                      decoration: InputDecoration(
                        hintText: '가격',
                        isDense: true,
                        contentPadding:
                            const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                        border: const OutlineInputBorder(),
                        suffixIcon: keyboardHideButton(),
                        suffixIconConstraints: const BoxConstraints(
                          minWidth: 36,
                          minHeight: 36,
                        ),
                      ),
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
                  IconButton(
                    onPressed: _rows.length > 1 ? () => _removeRow(i) : null,
                    icon: const Icon(Icons.remove_circle_outline, size: 20),
                    color: const Color(0xFF9CA3AF),
                  ),
                ],
              ),
            ),
          GestureDetector(
            onTap: _addRow,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFE5E7EB)),
              ),
              child: const Center(
                child: Text(
                  '+ 메뉴 추가',
                  style: TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          _SaveButton(loading: _saving, onTap: _save),
        ],
      ),
    );
  }
}

// ── 4. 영업시간 ──

class _HoursSection extends StatefulWidget {
  final Restaurant restaurant;
  final ValueChanged<String> onSaved;
  const _HoursSection({super.key, required this.restaurant, required this.onSaved});

  @override
  State<_HoursSection> createState() => _HoursSectionState();
}

class _TimeRangeRow {
  String from;
  String to;
  _TimeRangeRow({required this.from, required this.to});
}

class _HoursSectionState extends State<_HoursSection> {
  late bool _alwaysOpen;
  late List<_TimeRangeRow> _ranges;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _alwaysOpen = BusinessHoursData.isAlwaysOpenHours(widget.restaurant.hours);
    _ranges = _alwaysOpen
        ? [_TimeRangeRow(from: '00:00', to: '24:00')]
        : BusinessHoursData.rangesForEdit(widget.restaurant.hours)
            .map((r) => _TimeRangeRow(from: r.from, to: r.to))
            .toList();
  }

  Future<void> _pickTime(_TimeRangeRow row, bool isFrom) async {
    final current = isFrom ? row.from : row.to;
    final parts = current.split(':');
    final initial = TimeOfDay(
      hour: int.tryParse(parts[0]) ?? 11,
      minute: int.tryParse(parts.length > 1 ? parts[1] : '0') ?? 0,
    );
    final picked = await showTimePicker(context: context, initialTime: initial);
    if (picked == null) return;
    final text =
        '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
    setState(() {
      if (isFrom) {
        row.from = text;
      } else {
        row.to = text;
      }
    });
  }

  Future<void> _save() async {
    final hours = _alwaysOpen
        ? '00:00 - 24:00'
        : _ranges.map((r) => '${r.from} - ${r.to}').join(', ');
    setState(() => _saving = true);
    final err = await context
        .read<AppProvider>()
        .ownerUpdateRestaurantHours(widget.restaurant.id, hours);
    if (!mounted) return;
    setState(() => _saving = false);
    widget.onSaved(err ?? '영업시간이 저장되었어요.');
  }

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: '영업 시간',
      subtitle: '휴무 등 변경 사항을 바로 반영할 수 있어요.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Checkbox(
                value: _alwaysOpen,
                onChanged: (v) => setState(() => _alwaysOpen = v ?? false),
                activeColor: const Color(0xFF000000),
              ),
              const Text('24시간 영업', style: TextStyle(fontSize: 13)),
            ],
          ),
          if (!_alwaysOpen) ...[
            for (var i = 0; i < _ranges.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => _pickTime(_ranges[i], true),
                        child: _TimeBox(label: _ranges[i].from),
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 8),
                      child: Text('~'),
                    ),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => _pickTime(_ranges[i], false),
                        child: _TimeBox(label: _ranges[i].to),
                      ),
                    ),
                    IconButton(
                      onPressed: _ranges.length > 1
                          ? () => setState(() => _ranges.removeAt(i))
                          : null,
                      icon: const Icon(Icons.remove_circle_outline, size: 20),
                      color: const Color(0xFF9CA3AF),
                    ),
                  ],
                ),
              ),
            GestureDetector(
              onTap: () => setState(
                  () => _ranges.add(_TimeRangeRow(from: '11:00', to: '21:00'))),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFE5E7EB)),
                ),
                child: const Center(
                  child: Text(
                    '+ 시간대 추가',
                    style: TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
                  ),
                ),
              ),
            ),
          ],
          const SizedBox(height: 12),
          _SaveButton(loading: _saving, onTap: _save),
        ],
      ),
    );
  }
}

class _TimeBox extends StatelessWidget {
  final String label;
  const _TimeBox({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Center(
        child: Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
      ),
    );
  }
}

// ── 5. 매장 공지 ──

class _NoticeSection extends StatefulWidget {
  final Restaurant restaurant;
  final ValueChanged<String> onSaved;
  const _NoticeSection({super.key, required this.restaurant, required this.onSaved});

  @override
  State<_NoticeSection> createState() => _NoticeSectionState();
}

class _NoticeSectionState extends State<_NoticeSection> {
  static const _maxLength = 500;
  late final TextEditingController _ctrl;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.restaurant.ownerNotice);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final err = await context
        .read<AppProvider>()
        .ownerUpdateRestaurantNotice(widget.restaurant.id, _ctrl.text.trim());
    if (!mounted) return;
    setState(() => _saving = false);
    widget.onSaved(err ?? '매장 공지가 저장되었어요.');
  }

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: '매장 공지',
      subtitle: '유저 화면에는 한 줄로 보이고, 탭하면 전체를 볼 수 있어요.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _ctrl,
            maxLength: _maxLength,
            maxLines: 4,
            textInputAction: TextInputAction.done,
            onEditingComplete: () =>
                FocusManager.instance.primaryFocus?.unfocus(),
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: '예) 8월 15일은 광복절로 휴무입니다.',
              border: const OutlineInputBorder(),
              isDense: true,
              suffixIcon: keyboardHideButton(),
            ),
            style: const TextStyle(fontSize: 13),
          ),
          const SizedBox(height: 4),
          _SaveButton(loading: _saving, onTap: _save),
        ],
      ),
    );
  }
}
