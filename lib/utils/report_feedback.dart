import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/app_provider.dart';

Future<void> submitCrowdReportFeedback(
  BuildContext context,
  String restaurantId,
  String status,
) async {
  final err =
      await context.read<AppProvider>().reportStatus(restaurantId, status);
  if (!context.mounted) return;

  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(
        err ?? '소중한 제보 감사드려요!',
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
      ),
      backgroundColor:
          err != null ? const Color(0xFFEF4444) : const Color(0xFF111827),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 80),
      duration: const Duration(milliseconds: 2200),
      elevation: 0,
    ),
  );
}
