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
          color: const Color(0xFFE6F3EC),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFCDE9DC)),
        ),
        child: Row(
          children: [
            const Icon(Icons.event_seat, size: 19, color: Color(0xFF26BC7D)),
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
