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
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFF3F8F0),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFBFE0B0)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.only(top: 2),
              child: Icon(Icons.chat_bubble_outline,
                  size: 18, color: Color(0xFF5E8C4A)),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                ownerSeatCardLine(update),
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF4C9C2A),
                  height: 1.4,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
