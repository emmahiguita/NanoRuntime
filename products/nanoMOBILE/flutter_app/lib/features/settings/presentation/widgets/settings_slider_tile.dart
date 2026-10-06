import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:nanoai/core/theme/design_tokens.dart';
import 'package:nanoai/core/theme/nano_type.dart';

/// Previsualiza cada movimiento localmente y persiste solo al terminar el gesto.
/// Evita escrituras de preferencias y reconstrucciones de toda la pantalla por frame.
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

  /// Durante el arrastre el borrador es local; fuera de él manda el proveedor.
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
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 12,
            runSpacing: 4,
            children: [
              Text(widget.label, style: NanoType.body(colors.onSurface)),
              Text(
                display,
                style: NanoType.subtitle(
                  colors.primary,
                ).copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
              ),
            ],
          ),
          SliderTheme(
            data: SliderTheme.of(
              context,
            ).copyWith(showValueIndicator: ShowValueIndicator.never),
            child: Slider(
              value: value,
              min: widget.min,
              max: widget.max,
              divisions: widget.divisions,
              semanticFormatterCallback: (_) => display,
              onChanged: (next) => setState(() => _draft = next),
              // Una sola notificación y vibración por gesto, sin temporizadores.
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
