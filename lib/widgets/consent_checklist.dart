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
    this.subtitle,
    this.viewable = true,
  });

  final String id;
  final String label;
  final bool required;
  final String? subtitle;
  final bool viewable;
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _ConsentRow(
          label: widget.agreeAllLabel,
          checked: _allChecked,
          emphasized: true,
          onChanged: _setAll,
        ),
        const SizedBox(height: 12),
        const Divider(height: 1, color: Color(0xFFE5E7EB)),
        const SizedBox(height: 4),
        ...widget.items.map((item) {
          final summary = widget.expandedSummaries?[item.id];
          final expanded = _expanded.contains(item.id);
          final canView = widget.onViewDocument != null && item.viewable;
          return Column(
            children: [
              _ConsentRow(
                label: item.label,
                subtitle: item.subtitle,
                checked: widget.agreed[item.id] ?? false,
                required: item.required,
                onChanged: (v) => _setOne(item.id, v),
                trailing: canView
                    ? IconButton(
                        onPressed: () => widget.onViewDocument!(item.id),
                        icon: const Icon(
                          Icons.chevron_right,
                          size: 20,
                          color: Color(0xFF9CA3AF),
                        ),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
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
                  padding: const EdgeInsets.fromLTRB(32, 0, 16, 12),
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
    this.subtitle,
  });

  final String label;
  final String? subtitle;
  final bool checked;
  final bool? required;
  final bool emphasized;
  final ValueChanged<bool> onChanged;
  final Widget? trailing;

  String get _labelWithRequired {
    if (required == null) return label;
    return '$label (${required! ? '필수' : '선택'})';
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => onChanged(!checked),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: 0,
            vertical: emphasized ? 12 : 10,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _CheckBox(checked: checked, emphasized: emphasized),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _labelWithRequired,
                      style: TextStyle(
                        fontSize: emphasized ? 15 : 14,
                        fontWeight:
                            emphasized ? FontWeight.w800 : FontWeight.w500,
                        color: const Color(0xFF111827),
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle!,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w400,
                          color: Color(0xFF9CA3AF),
                        ),
                      ),
                    ],
                  ],
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

class _CheckBox extends StatelessWidget {
  const _CheckBox({required this.checked, this.emphasized = false});

  final bool checked;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      width: emphasized ? 24 : 22,
      height: emphasized ? 24 : 22,
      decoration: BoxDecoration(
        color: checked ? const Color(0xFF111827) : Colors.white,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: checked ? const Color(0xFF111827) : const Color(0xFFD1D5DB),
          width: 1.5,
        ),
      ),
      child: checked
          ? Icon(
              Icons.check,
              size: emphasized ? 16 : 14,
              color: Colors.white,
            )
          : null,
    );
  }
}
