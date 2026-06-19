import 'package:flutter/material.dart';

import '../models/restaurant.dart';
import '../screens/directions_screen.dart';

void openInAppDirections(BuildContext context, Restaurant restaurant) {
  if (!restaurant.hasMapLocation) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text(
          '매장 위치 정보가 없어 길찾기를 할 수 없어요.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
        backgroundColor: const Color(0xFF111827),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 80),
      ),
    );
    return;
  }

  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => DirectionsScreen(restaurant: restaurant),
    ),
  );
}
