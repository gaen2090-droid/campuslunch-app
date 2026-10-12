import 'package:flutter/material.dart';

import '../utils/business_hours.dart';

/// 영업시간: 접으면 1줄, 펼치면 요일마다 1줄
class BusinessHoursSection extends StatefulWidget {
  final String hours;

  /// 휴무 안내 문구(예: "휴무: 일요일, 공휴일"). 비어 있으면 표시하지 않는다.
  final String closedNote;

  const BusinessHoursSection({
    super.key,
    required this.hours,
    this.closedNote = '',
  });

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
                    // 영업시간 옆에 같은 줄로: 11:00 - 21:00 (휴무: 토, 일)
                    // Row + 세로 가운데 정렬 — 휴무 문구는 시간보다 작고 가볍게.
                    // (WidgetSpan은 시스템 글자 크기 설정에서 크기가 두 번 곱해져 쓰지 않는다.)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Flexible(
                          child: Text(
                            collapsed,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF6B7280),
                              height: 1.4,
                            ),
                          ),
                        ),
                        if (widget.closedNote.isNotEmpty) ...[
                          const SizedBox(width: 6),
                          // 시각적으로 시간 글자 가운데에 맞도록 1px 위로
                          Transform.translate(
                            offset: const Offset(0, -1),
                            child: Text(
                              '(${widget.closedNote})',
                              maxLines: 1,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: Color(0xFF6B7280),
                                height: 1.4,
                              ),
                            ),
                          ),
                        ],
                      ],
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
                  // 펼친 상태에서는 요일별 줄 아래에 한 줄로 보여준다.
                  if (widget.closedNote.isNotEmpty && _expanded && canExpand)
                    Padding(
                      padding: const EdgeInsets.only(top: 2, bottom: 2),
                      child: Text(
                        '(${widget.closedNote})',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF6B7280),
                          height: 1.4,
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
