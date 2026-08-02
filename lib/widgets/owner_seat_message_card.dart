import 'package:flutter/material.dart';

import '../models/owner_seat_update.dart';
import '../utils/owner_seat_label.dart';

class OwnerSeatMessageCard extends StatelessWidget {
  final OwnerSeatUpdate update;

  const OwnerSeatMessageCard({super.key, required this.update});

  @override
  Widget build(BuildContext context) {
    if (!update.isVisibleAt(DateTime.now())) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFFF3F4F6),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            const Icon(Icons.event_seat_outlined, size: 15, color: Color(0xFF6B7280)),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                ownerSeatCardLine(update),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF374151),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
