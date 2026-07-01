import 'package:flutter/material.dart';

/// 전체 동의 + 항목별 동의 체크리스트 (범용)
class ConsentChecklist extends StatefulWidget {
  const ConsentChecklist({
    super.key,
    required this.agreeAllLabel,
    required this.items,
    required this.agreed,
    required this.onChanged,
    this.expandedSummaries,
    this.onViewDocument,
  });

  final String agreeAllLabel;
  final List<ConsentCheckItem> items;
  final Map<String, bool> agreed;
  final ValueChanged<Map<String, bool>> onChanged;
  final Map<String, String>? expandedSummaries;
  final void Function(String id)? onViewDocument;

  @override
  State<ConsentChecklist> createState() => _ConsentChecklistState();
}

class ConsentCheckItem {
  const ConsentCheckItem({
    required this.id,
    required this.label,
    required this.required,
  });

  final String id;
  final String label;
  final bool required;
}

class _ConsentChecklistState extends State<ConsentChecklist> {
  final Set<String> _expanded = {};

  bool get _allChecked =>
      widget.items.every((item) => widget.agreed[item.id] == true);

  void _setAll(bool value) {
    widget.onChanged({for (final item in widget.items) item.id: value});
  }

  void _setOne(String id, bool value) {
    final next = Map<String, bool>.from(widget.agreed)..[id] = value;
    widget.onChanged(next);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(8),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _ConsentRow(
            label: widget.agreeAllLabel,
            checked: _allChecked,
            emphasized: true,
            onChanged: _setAll,
          ),
          const Divider(height: 1, color: Color(0xFFE5E7EB)),
          ...widget.items.map((item) {
            final summary = widget.expandedSummaries?[item.id];
            final expanded = _expanded.contains(item.id);
            final canView = widget.onViewDocument != null;
            return Column(
              children: [
                _ConsentRow(
                  label: item.label,
                  checked: widget.agreed[item.id] ?? false,
                  required: item.required,
                  onChanged: (v) => _setOne(item.id, v),
                  trailing: canView
                      ? TextButton(
                          onPressed: () => widget.onViewDocument!(item.id),
                          style: TextButton.styleFrom(
                            minimumSize: Size.zero,
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: const Text(
                            '전문 보기',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF5E8C4A),
                            ),
                          ),
                        )
                      : summary != null
                          ? IconButton(
                              icon: Icon(
                                expanded
                                    ? Icons.expand_less
                                    : Icons.expand_more,
                                size: 20,
                                color: const Color(0xFF9CA3AF),
                              ),
                              onPressed: () => setState(() {
                                if (expanded) {
                                  _expanded.remove(item.id);
                                } else {
                                  _expanded.add(item.id);
                                }
                              }),
                            )
                          : null,
                ),
                if (summary != null && expanded && !canView)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(48, 0, 16, 12),
                    child: Text(
                      summary,
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF6B7280),
                        height: 1.55,
                      ),
                    ),
                  ),
              ],
            );
          }),
        ],
      ),
    );
  }
}

class _ConsentRow extends StatelessWidget {
  const _ConsentRow({
    required this.label,
    required this.checked,
    required this.onChanged,
    this.required,
    this.emphasized = false,
    this.trailing,
  });

  final String label;
  final bool checked;
  final bool? required;
  final bool emphasized;
  final ValueChanged<bool> onChanged;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: emphasized ? const Color(0xFFF3F8F0) : Colors.transparent,
      child: InkWell(
        onTap: () => onChanged(!checked),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: 16,
            vertical: emphasized ? 14 : 12,
          ),
          child: Row(
            children: [
              _CheckBox(checked: checked, emphasized: emphasized),
              const SizedBox(width: 10),
              if (required != null) ...[
                _RequiredBadge(required: required!),
                const SizedBox(width: 6),
              ],
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: emphasized ? 14 : 13,
                    fontWeight: emphasized ? FontWeight.w900 : FontWeight.w700,
                    color: const Color(0xFF111827),
                  ),
                ),
              ),
              if (trailing != null) trailing!,
            ],
          ),
        ),
      ),
    );
  }
}

class _RequiredBadge extends StatelessWidget {
  const _RequiredBadge({required this.required});

  final bool required;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: required ? const Color(0xFFDAFFCA) : const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        required ? '필수' : '선택',
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          color: required ? const Color(0xFF4C9C2A) : const Color(0xFF9CA3AF),
        ),
      ),
    );
  }
}

class _CheckBox extends StatelessWidget {
  const _CheckBox({required this.checked, this.emphasized = false});

  final bool checked;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      width: emphasized ? 22 : 20,
      height: emphasized ? 22 : 20,
      decoration: BoxDecoration(
        color: checked ? const Color(0xFF9ECA8B) : Colors.white,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: checked ? const Color(0xFF9ECA8B) : const Color(0xFFD1D5DB),
          width: emphasized ? 1.5 : 1,
        ),
      ),
      child: checked
          ? Icon(
              Icons.check,
              size: emphasized ? 16 : 14,
              color: const Color(0xFF111827),
            )
          : null,
    );
  }
}
