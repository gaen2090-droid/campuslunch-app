import 'package:flutter/material.dart';
import '../models/restaurant.dart';

class StatusBadge extends StatelessWidget {
  final String status;
  final bool large;
  const StatusBadge({super.key, required this.status, this.large = false});

  @override
  Widget build(BuildContext context) {
    final meta = crowdStatusMeta(status);
    return Container(
      padding: EdgeInsets.symmetric(
          horizontal: large ? 12 : 8, vertical: large ? 6 : 4),
      decoration: BoxDecoration(
        color: Color(meta.bgColor),
        borderRadius: BorderRadius.circular(large ? 12 : 8),
      ),
      child: Text(
        meta.label,
        style: TextStyle(
          fontSize: large ? 14 : 12,
          fontWeight: FontWeight.w800,
          color: Color(meta.color),
        ),
      ),
    );
  }
}
