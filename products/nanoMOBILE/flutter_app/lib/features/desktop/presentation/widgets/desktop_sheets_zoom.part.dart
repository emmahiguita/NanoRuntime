part of 'desktop_sheets.dart';

class _ZoomSheetContent extends StatefulWidget {
  final NanoColors colors;
  final double currentZoom;
  final ValueChanged<double> onZoomChanged;
  final VoidCallback onResetZoom;

  const _ZoomSheetContent({
    required this.colors,
    required this.currentZoom,
    required this.onZoomChanged,
    required this.onResetZoom,
  });

  @override
  State<_ZoomSheetContent> createState() => _ZoomSheetContentState();
}

class _ZoomSheetContentState extends State<_ZoomSheetContent> {
  late double _zoom;

  @override
  void initState() {
    super.initState();
    _zoom = widget.currentZoom;
  }

  @override
  Widget build(BuildContext context) {
    return _SheetContainer(
      colors: widget.colors,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _SheetHeader(
            title: 'Zoom del Escritorio',
            icon: Icons.zoom_in_map_rounded,
            colors: widget.colors,
            trailing: Text(
              '${(_zoom * 100).round()}%',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: widget.colors.chromeActive,
              ),
            ),
          ),
          const SizedBox(height: 16),
          SliderTheme(
            data: SliderThemeData(
              activeTrackColor: widget.colors.chromeActive,
              inactiveTrackColor: Colors.white.withValues(alpha: 0.12),
              thumbColor: widget.colors.chromeActive,
              overlayColor: widget.colors.chromeActive.withValues(alpha: 0.20),
            ),
            child: Slider(
              value: _zoom.clamp(0.10, 5.00),
              min: 0.10,
              max: 5.00,
              divisions: 49,
              onChanged: (val) {
                setState(() => _zoom = val);
                widget.onZoomChanged(val);
              },
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _presetChip('10% Mín', 0.10),
              _presetChip('50%', 0.50),
              _presetChip('100%', 1.0),
              _presetChip('200%', 2.0),
              _presetChip('500%', 5.0),
            ],
          ),
        ],
      ),
    );
  }

  Widget _presetChip(String label, double targetZoom) {
    final isSelected = (_zoom - targetZoom).abs() < 0.05;
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 3),
        child: OutlinedButton(
          onPressed: () {
            HapticFeedback.selectionClick();
            setState(() => _zoom = targetZoom);
            widget.onZoomChanged(targetZoom);
          },
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 10),
            side: BorderSide(
              color: isSelected
                  ? widget.colors.chromeActive
                  : Colors.white.withValues(alpha: 0.15),
              width: isSelected ? 1.4 : 0.8,
            ),
            backgroundColor: isSelected
                ? widget.colors.chromeActive.withValues(alpha: 0.18)
                : Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              label,
              maxLines: 1,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? widget.colors.chromeActive : Colors.white70,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
