import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';

import '../config/campus.dart';
import '../providers/app_provider.dart';
import '../services/places_service.dart';
import '../widgets/restaurant_google_map.dart';

/// 어드민: Google 지도에서 장소 선택 → DB 등록 + 사장님 인증번호 발급
class AdminMapRegisterTab extends StatefulWidget {
  const AdminMapRegisterTab({super.key});

  @override
  State<AdminMapRegisterTab> createState() => _AdminMapRegisterTabState();
}

class _AdminMapRegisterTabState extends State<AdminMapRegisterTab> {
  final _searchCtrl = TextEditingController();
  final _places = PlacesService();
  Timer? _debounce;
  List<PlaceSearchResult> _results = [];
  PlaceDetails? _selected;
  String _category = '한식';
  String _area = '정문';
  bool _loading = false;
  bool _registering = false;
  String? _error;

  static const _categories = [
    '학식', '한식', '중식', '일식', '양식', '아시아', '분식', '카페',
  ];
  static const _areas = ['학식', '정문', '중문', '후문'];

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onSearchChanged(String v) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () async {
      if (!mounted) return;
      setState(() => _loading = true);
      final list = await _places.search(v);
      if (!mounted) return;
      setState(() {
        _results = list;
        _loading = false;
      });
    });
  }

  Future<void> _pickPlace(PlaceSearchResult item) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final details = await _places.getDetails(item.placeId);
    if (!mounted) return;
    setState(() {
      _selected = details;
      _results = [];
      _searchCtrl.text = details?.name ?? item.name;
      _loading = false;
    });
  }

  Future<void> _register() async {
    final place = _selected;
    if (place == null) {
      setState(() => _error = '지도에서 가게를 먼저 선택해주세요.');
      return;
    }

    setState(() {
      _registering = true;
      _error = null;
    });

    final ownerCode = await context.read<AppProvider>().addRestaurantFromGooglePlace(
          placeId: place.placeId,
          name: place.name,
          address: place.address,
          latitude: place.latitude,
          longitude: place.longitude,
          category: _category,
          area: _area,
          imageUrl: place.photoUrl ?? '',
          hours: place.hours,
          hoursDisplay: place.hoursDisplay,
          hoursPeriods: place.hoursPeriods,
        );

    if (!mounted) return;
    setState(() => _registering = false);

    if (ownerCode == null) {
      setState(() => _error = '등록에 실패했어요. 이미 등록된 가게이거나 권한 문제일 수 있어요.');
      return;
    }

    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('가게 등록 완료',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${place.name}',
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
            const SizedBox(height: 16),
            const Text('사장님 인증번호 (6자리)',
                style: TextStyle(fontSize: 13, color: Color(0xFF6B7280))),
            const SizedBox(height: 8),
            SelectableText(
              ownerCode,
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w900,
                letterSpacing: 6,
                color: Color(0xFF16A34A),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              '사장님 앱 → 인증 화면에서 위 번호를 입력하면 혼잡도를 관리할 수 있어요.',
              style: TextStyle(fontSize: 12, color: Color(0xFF9CA3AF), height: 1.4),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('확인',
                style: TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF16A34A))),
          ),
        ],
      ),
    );

    setState(() {
      _selected = null;
      _searchCtrl.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final pickLatLng = _selected != null
        ? LatLng(_selected!.latitude, _selected!.longitude)
        : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          '지도에서 가게 등록',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Color(0xFF111827)),
        ),
        const SizedBox(height: 6),
        const Text(
          '중앙대 주변 장소를 검색한 뒤 «가게 신규 등록»을 누르면 6자리 인증번호가 발급됩니다.',
          style: TextStyle(fontSize: 13, color: Color(0xFF6B7280), height: 1.4),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _searchCtrl,
          onChanged: _onSearchChanged,
          decoration: InputDecoration(
            hintText: '가게명 검색 (예: 양셰프)',
            filled: true,
            fillColor: Colors.white,
            prefixIcon: const Icon(Icons.search, size: 20),
            suffixIcon: _loading
                ? const Padding(
                    padding: EdgeInsets.all(12),
                    child: SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : null,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
            ),
          ),
        ),
        if (_results.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(top: 4),
            constraints: const BoxConstraints(maxHeight: 160),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: const [
                BoxShadow(color: Color(0x15000000), blurRadius: 12),
              ],
            ),
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: _results.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (_, i) {
                final item = _results[i];
                return ListTile(
                  dense: true,
                  title: Text(item.name,
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                  subtitle: Text(item.address,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 11)),
                  onTap: () => _pickPlace(item),
                );
              },
            ),
          ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _DropdownField(
                label: '구역',
                value: _area,
                items: _areas,
                onChanged: (v) => setState(() => _area = v),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _DropdownField(
                label: '카테고리',
                value: _category,
                items: _categories,
                onChanged: (v) => setState(() => _category = v),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 220,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: RestaurantGoogleMap(
              restaurants: const [],
              selected: null,
              onSelect: (_) {},
              showMyLocation: false,
              pickMarker: pickLatLng,
            ),
          ),
        ),
        if (_selected != null) ...[
          const SizedBox(height: 10),
          Text(
            _selected!.address,
            style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
          ),
        ],
        if (_error != null) ...[
          const SizedBox(height: 8),
          Text(_error!, style: const TextStyle(fontSize: 13, color: Color(0xFFEF4444))),
        ],
        const SizedBox(height: 16),
        GestureDetector(
          onTap: _registering || _selected == null ? null : _register,
          child: Container(
            height: 52,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: const Color(0xFF16A34A),
              borderRadius: BorderRadius.circular(14),
            ),
            child: _registering
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                  )
                : const Text(
                    '가게 신규 등록',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                    ),
                  ),
          ),
        ),
      ],
    );
  }
}

class _DropdownField extends StatelessWidget {
  final String label;
  final String value;
  final List<String> items;
  final ValueChanged<String> onChanged;

  const _DropdownField({
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF9CA3AF))),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE5E7EB)),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: value,
              isExpanded: true,
              items: items
                  .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                  .toList(),
              onChanged: (v) {
                if (v != null) onChanged(v);
              },
            ),
          ),
        ),
      ],
    );
  }
}
