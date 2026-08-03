import 'package:flutter/material.dart';

import '../utils/business_hours.dart';

/// 영업시간: 접으면 1줄, 펼치면 요일마다 1줄
class BusinessHoursSection extends StatefulWidget {
  final String hours;

  const BusinessHoursSection({super.key, required this.hours});

  @override
  State<BusinessHoursSection> createState() => _BusinessHoursSectionState();
}

class _BusinessHoursSectionState extends State<BusinessHoursSection> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    if (widget.hours.trim().isEmpty) return const SizedBox.shrink();

    final lines = BusinessHoursData.displayLines(widget.hours);
    final canExpand = lines.length > 1;
    final collapsed =
        BusinessHoursData.collapsedDisplayLine(widget.hours, DateTime.now());

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: canExpand ? () => setState(() => _expanded = !_expanded) : null,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.only(top: 2),
              child: Icon(Icons.access_time,
                  size: 16, color: Color(0xFF9CA3AF)),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (!_expanded || !canExpand)
                    Text(
                      collapsed,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF6B7280),
                        height: 1.4,
                      ),
                    )
                  else
                    ...lines.map(
                      (line) => Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text(
                          line,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF6B7280),
                            height: 1.4,
                          ),
                        ),
                      ),
                    ),
                  if (canExpand) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text(
                          _expanded ? '접기' : '요일별 보기',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF000000),
                          ),
                        ),
                        Icon(
                          _expanded
                              ? Icons.keyboard_arrow_up
                              : Icons.keyboard_arrow_down,
                          size: 18,
                          color: const Color(0xFF000000),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
