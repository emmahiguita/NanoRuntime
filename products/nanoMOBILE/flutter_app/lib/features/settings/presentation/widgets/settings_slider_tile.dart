import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:nanoai/core/theme/design_tokens.dart';
import 'package:nanoai/core/theme/nano_type.dart';

/// Previsualiza cada movimiento localmente y persiste solo al terminar el gesto.
/// Evita escrituras de preferencias y reconstrucciones pesadas por frame.
class SettingsSliderTile extends StatefulWidget {
  final String label;
  final double value, min, max;
  final String? unit;
  final int? divisions;
  final int fractionDigits;
  final ValueChanged<double> onChanged;
  final NanoColors colors;

  const SettingsSliderTile({
    super.key,
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    this.unit,
    this.divisions,
    this.fractionDigits = 1,
    required this.onChanged,
    required this.colors,
  });

  @override
  State<SettingsSliderTile> createState() => _SettingsSliderTileState();
}

class _SettingsSliderTileState extends State<SettingsSliderTile> {
  double? _draft;

  @override
  Widget build(BuildContext context) {
    final value = (_draft ?? widget.value)
        .clamp(widget.min, widget.max)
        .toDouble();
    final display =
        '${value.toStringAsFixed(widget.fractionDigits)}'
        '${widget.unit == null ? '' : ' ${widget.unit}'}';
    final colors = widget.colors;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                widget.label,
                style: NanoType.body(colors.onSurface).copyWith(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: colors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  display,
                  style: NanoType.caption(colors.primary).copyWith(
                    fontWeight: FontWeight.w700,
                    fontSize: 11,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
            ],
          ),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              showValueIndicator: ShowValueIndicator.never,
              trackHeight: 3.5,
              activeTrackColor: colors.primary,
              inactiveTrackColor: colors.outlineVariant.withValues(alpha: 0.35),
              thumbColor: colors.primary,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
            ),
            child: Slider(
              value: value,
              min: widget.min,
              max: widget.max,
              divisions: widget.divisions,
              semanticFormatterCallback: (_) => display,
              onChanged: (next) => setState(() => _draft = next),
              onChangeEnd: (next) {
                setState(() => _draft = null);
                if (next != widget.value) {
                  widget.onChanged(next);
                  HapticFeedback.selectionClick();
                }
              },
            ),
          ),
        ],
      ),
    );
  }
}
