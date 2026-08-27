import 'package:flutter/material.dart';

import '../constants/app_colors.dart';
import '../models/community_poll_option.dart';

/// 게시글 상세의 투표 카드. 아직 투표하지 않았으면 옵션 선택 버튼 + "투표하기",
/// 이미 투표했으면 옵션별 득표율 결과 뷰로 표시한다(§0 — 결과는 투표 즉시 공개,
/// 1인 1회로 재투표는 불가능).
class CommunityPollCard extends StatefulWidget {
  final List<CommunityPollOption> options;
  final Future<void> Function(List<String> optionIds) onVote;

  const CommunityPollCard({
    super.key,
    required this.options,
    required this.onVote,
  });

  @override
  State<CommunityPollCard> createState() => _CommunityPollCardState();
}

class _CommunityPollCardState extends State<CommunityPollCard> {
  final Set<String> _selected = {};
  bool _submitting = false;

  bool get _voted => widget.options.any((o) => o.votedByMe);

  bool get _allowMultiple =>
      widget.options.isNotEmpty && widget.options.first.allowMultiple;

  int get _totalVoters {
    // 참여자 수(중복선택 고려 distinct)는 상위(게시글) 레벨 poll_voter_count가
    // 정확하지만, 이 카드는 옵션 리스트만 받으므로 옵션별 vote_count 합으로
    // 근사 표시하지 않고 득표율 계산에만 vote_count를 사용한다.
    return widget.options.fold(0, (sum, o) => sum + o.voteCount);
  }

  void _toggle(String optionId) {
    if (_voted || _submitting) return;
    setState(() {
      if (_selected.contains(optionId)) {
        _selected.remove(optionId);
      } else if (_allowMultiple) {
        _selected.add(optionId);
      } else {
        // 단일선택 투표는 새 선택이 이전 선택을 대체한다(라디오 버튼처럼).
        _selected
          ..clear()
          ..add(optionId);
      }
    });
  }

  Future<void> _submit() async {
    if (_selected.isEmpty || _submitting) return;
    setState(() => _submitting = true);
    try {
      await widget.onVote(_selected.toList());
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final voted = _voted;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFD1D5DB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.poll_outlined, size: 16, color: Color(0xFF26BC7D)),
              SizedBox(width: 6),
              Text(
                '투표',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: Color(0xFF000000)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          for (final option in widget.options)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: voted
                  ? _ResultBar(
                      option: option,
                      totalVotes: _totalVoters,
                    )
                  : _OptionButton(
                      label: option.label,
                      selected: _selected.contains(option.id),
                      onTap: () => _toggle(option.id),
                    ),
            ),
          if (!voted) ...[
            const SizedBox(height: 4),
            GestureDetector(
              onTap: _selected.isEmpty ? null : _submit,
              child: Container(
                height: 44,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: _selected.isEmpty
                      ? const Color(0xFFE5E7EB)
                      : AppColors.primaryCta,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: _submitting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : Text(
                          '투표하기',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: _selected.isEmpty ? const Color(0xFF9CA3AF) : Colors.white,
                          ),
                        ),
                ),
              ),
            ),
          ],
          const SizedBox(height: 8),
          Text(
            _allowMultiple
                ? '$_totalVoters명 참여 · 최대 ${widget.options.length}개 선택 가능'
                : '$_totalVoters명 참여 · 1개 선택 가능',
            style: const TextStyle(fontSize: 11, color: Color(0xFF9CA3AF)),
          ),
        ],
      ),
    );
  }
}

class _OptionButton extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _OptionButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFE6F3EC) : const Color(0xFFF9FAFB),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? AppColors.primaryCta : const Color(0xFFE5E7EB),
          ),
        ),
        child: Row(
          children: [
            Icon(
              selected ? Icons.check_circle : Icons.circle_outlined,
              size: 18,
              color: selected ? AppColors.primaryCta : const Color(0xFF9CA3AF),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: selected ? const Color(0xFF26BC7D) : const Color(0xFF374151),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ResultBar extends StatelessWidget {
  final CommunityPollOption option;
  final int totalVotes;

  const _ResultBar({required this.option, required this.totalVotes});

  @override
  Widget build(BuildContext context) {
    final ratio = totalVotes == 0 ? 0.0 : option.voteCount / totalVotes;
    final percent = (ratio * 100).toStringAsFixed(1);
    final mine = option.votedByMe;
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Stack(
        children: [
          Container(
            width: double.infinity,
            height: 44,
            color: const Color(0xFFF3F4F6),
          ),
          FractionallySizedBox(
            widthFactor: ratio.clamp(0.0, 1.0),
            child: Container(
              height: 44,
              color: mine ? const Color(0xFFE6F3EC) : const Color(0xFFE5E7EB),
            ),
          ),
          Positioned.fill(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Row(
                children: [
                  if (mine) ...[
                    const Icon(Icons.check_circle, size: 16, color: Color(0xFF26BC7D)),
                    const SizedBox(width: 6),
                  ],
                  Expanded(
                    child: Text(
                      option.label,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: mine ? const Color(0xFF26BC7D) : const Color(0xFF374151),
                      ),
                    ),
                  ),
                  Text(
                    '$percent% (${option.voteCount}명)',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: mine ? const Color(0xFF26BC7D) : const Color(0xFF6B7280),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
