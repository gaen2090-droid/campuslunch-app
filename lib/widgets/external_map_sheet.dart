import 'package:flutter/material.dart';

import '../models/map_lat_lng.dart';
import '../utils/external_map_launcher.dart';

/// 외부 지도 앱(카카오맵/네이버 지도) 도보 길찾기 바로가기 바텀시트.
Future<void> showExternalMapSheet(
  BuildContext context, {
  required MapLatLng origin,
  required MapLatLng destination,
  required String destinationName,
}) {
  return showModalBottomSheet(
    context: context,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (sheetContext) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: const Color(0xFFE5E7EB),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            _ExternalMapTile(
              app: ExternalMapApp.kakaoMap,
              badgeColor: const Color(0xFFFEE500),
              iconColor: const Color(0xFF3C1E1E),
              logoAsset: 'assets/icon/maps/kakaomap_logo.png',
              logoFillsBadge: true,
              onTap: () async {
                Navigator.pop(sheetContext);
                await ExternalMapLauncher.openWalkingRoute(
                  app: ExternalMapApp.kakaoMap,
                  origin: origin,
                  destination: destination,
                  destinationName: destinationName,
                );
              },
            ),
            const SizedBox(height: 10),
            _ExternalMapTile(
              app: ExternalMapApp.naverMap,
              badgeColor: const Color(0xFFF3F4F6),
              iconColor: const Color(0xFF03C75A),
              logoAsset: 'assets/icon/maps/navermap_logo.png',
              logoFillsBadge: false,
              onTap: () async {
                Navigator.pop(sheetContext);
                await ExternalMapLauncher.openWalkingRoute(
                  app: ExternalMapApp.naverMap,
                  origin: origin,
                  destination: destination,
                  destinationName: destinationName,
                );
              },
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () => Navigator.pop(sheetContext),
                style: TextButton.styleFrom(
                  backgroundColor: const Color(0xFFF3F4F6),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  '닫기',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF374151),
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

class _ExternalMapTile extends StatelessWidget {
  final ExternalMapApp app;
  final Color badgeColor;
  final Color iconColor;
  final String logoAsset;
  final bool logoFillsBadge;
  final VoidCallback onTap;

  const _ExternalMapTile({
    required this.app,
    required this.badgeColor,
    required this.iconColor,
    required this.logoAsset,
    required this.logoFillsBadge,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final fallback = Icon(Icons.map_rounded, size: 20, color: iconColor);
    final logo = logoFillsBadge
        ? ClipRRect(
            borderRadius: BorderRadius.circular(9),
            child: Image.asset(
              logoAsset,
              width: 36,
              height: 36,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => fallback,
            ),
          )
        : Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: badgeColor,
              borderRadius: BorderRadius.circular(9),
            ),
            child: Image.asset(
              logoAsset,
              width: 22,
              height: 22,
              errorBuilder: (context, error, stackTrace) => fallback,
            ),
          );

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            logo,
            const SizedBox(width: 14),
            Text(
              app.label,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Color(0xFF000000),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
