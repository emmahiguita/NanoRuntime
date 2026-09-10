import 'package:flutter/material.dart';

import '../automation_visual_theme.dart';

/// A suggestion only selects an existing action or draft; it owns no engine
/// state and cannot bypass the caller's execution/confirmation policy.
class AutomationSuggestion {
  const AutomationSuggestion({
    required this.label,
    required this.onSelected,
    this.leading,
  });

  final String label;
  final VoidCallback? onSelected;
  final Widget? leading;
}

/// One bounded, horizontally scrollable row shared by dashboard and messages.
/// Hiding is explicit and reversible; temporary suppression keeps that choice.
class AutomationSuggestionCarousel extends StatefulWidget {
  const AutomationSuggestionCarousel({
    super.key,
    required this.suggestions,
    this.suppressed = false,
  });

  final List<AutomationSuggestion> suggestions;
  final bool suppressed;

  @override
  State<AutomationSuggestionCarousel> createState() =>
      _AutomationSuggestionCarouselState();
}

class _AutomationSuggestionCarouselState
    extends State<AutomationSuggestionCarousel> {
  bool _expanded = true;

  @override
  Widget build(BuildContext context) {
    if (widget.suppressed || widget.suggestions.isEmpty) {
      return const SizedBox.shrink();
    }
    final visual = AutomationVisual.of(context);
    final textScale = MediaQuery.textScalerOf(context).scale(12) / 12;
    final rowHeight = (52 * textScale).clamp(52.0, 104.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Sugerencias',
                style: TextStyle(
                  color: visual.textMuted,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            TextButton.icon(
              onPressed: () => setState(() => _expanded = !_expanded),
              icon: Icon(
                _expanded
                    ? Icons.expand_less_rounded
                    : Icons.expand_more_rounded,
                size: 18,
              ),
              label: Text(_expanded ? 'Ocultar' : 'Mostrar'),
              style: TextButton.styleFrom(
                foregroundColor: visual.accent,
                minimumSize: const Size(44, 44),
                textStyle: const TextStyle(fontSize: 12),
              ),
            ),
          ],
        ),
        if (_expanded)
          LayoutBuilder(
            builder: (context, constraints) {
              final itemWidth = (constraints.maxWidth * 0.72)
                  .clamp(160.0, 260.0)
                  .clamp(0.0, constraints.maxWidth);
              return SizedBox(
                height: rowHeight,
                child: ListView.separated(
                  key: const ValueKey('automation-suggestion-carousel'),
                  scrollDirection: Axis.horizontal,
                  itemCount: widget.suggestions.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    final suggestion = widget.suggestions[index];
                    return SizedBox(
                      width: itemWidth,
                      child: Tooltip(
                        message: suggestion.label,
                        child: Material(
                          color: visual.accentSoft.withValues(alpha: 0.48),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(
                              color: visual.accent.withValues(alpha: 0.20),
                            ),
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: InkWell(
                            onTap: suggestion.onSelected,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              child: Row(
                                children: [
                                  if (suggestion.leading != null) ...[
                                    suggestion.leading!,
                                    const SizedBox(width: 8),
                                  ],
                                  Expanded(
                                    child: Text(
                                      suggestion.label,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: suggestion.onSelected != null
                                            ? visual.text
                                            : visual.textMuted,
                                        fontSize: 12,
                                        height: 1.2,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              );
            },
          ),
      ],
    );
  }
}
