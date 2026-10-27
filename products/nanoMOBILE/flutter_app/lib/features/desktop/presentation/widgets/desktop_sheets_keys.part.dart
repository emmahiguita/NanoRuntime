part of 'desktop_sheets.dart';

class _PCKeysSheetContent extends StatelessWidget {
  final NanoColors colors;
  final ValueChanged<int> onQuickKey;
  final ValueChanged<List<int>> onCombo;
  final bool ctrlSticky;
  final bool altSticky;
  final bool shiftSticky;
  final bool superSticky;
  final VoidCallback onToggleCtrl;
  final VoidCallback onToggleAlt;
  final VoidCallback onToggleShift;
  final VoidCallback onToggleSuper;

  const _PCKeysSheetContent({
    required this.colors,
    required this.onQuickKey,
    required this.onCombo,
    required this.ctrlSticky,
    required this.altSticky,
    required this.shiftSticky,
    required this.superSticky,
    required this.onToggleCtrl,
    required this.onToggleAlt,
    required this.onToggleShift,
    required this.onToggleSuper,
  });

  @override
  Widget build(BuildContext context) {
    return _SheetContainer(
      colors: colors,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SheetHeader(
            title: 'Teclas PC & Atajos',
            icon: Icons.keyboard_rounded,
            colors: colors,
          ),
          const SizedBox(height: 14),
          const Text(
            'Modificadores (Sticky)',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _modBtn('Ctrl', ctrlSticky, onToggleCtrl, colors),
              _modBtn('Alt', altSticky, onToggleAlt, colors),
              _modBtn('Shift', shiftSticky, onToggleShift, colors),
              _modBtn('Super / Win', superSticky, onToggleSuper, colors),
            ],
          ),
          const SizedBox(height: 16),
          const Text(
            'Navegación & Edición',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _keyBtn('Esc', () => onQuickKey(0xFF1B)),
              _keyBtn('Tab', () => onQuickKey(0xFF09)),
              _keyBtn('Return', () => onQuickKey(0xFF0D)),
              _keyBtn('Space', () => onQuickKey(0x20)),
              _keyBtn('Delete', () => onQuickKey(0xFFFF)),
              _keyBtn('Home', () => onQuickKey(0xFF50)),
              _keyBtn('End', () => onQuickKey(0xFF57)),
              _keyBtn('PgUp', () => onQuickKey(0xFF55)),
              _keyBtn('PgDn', () => onQuickKey(0xFF56)),
            ],
          ),
          const SizedBox(height: 16),
          const Text(
            'Atajos Frecuentes',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _comboBtn('Ctrl+C', () => onCombo([0xFFE3, 0x63])),
              _comboBtn('Ctrl+V', () => onCombo([0xFFE3, 0x76])),
              _comboBtn('Ctrl+X', () => onCombo([0xFFE3, 0x78])),
              _comboBtn('Ctrl+Z', () => onCombo([0xFFE3, 0x7A])),
              _comboBtn('Alt+Tab', () => onCombo([0xFFE9, 0xFF09])),
              _comboBtn(
                'Ctrl+Alt+T (Terminal)',
                () => onCombo([0xFFE3, 0xFFE9, 0x74]),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _modBtn(
    String label,
    bool active,
    VoidCallback onTap,
    NanoColors colors,
  ) {
    final accent = colors.chromeActive;
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 3),
        child: GestureDetector(
          onTap: () {
            HapticFeedback.selectionClick();
            onTap();
          },
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 10),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: active
                  ? accent.withValues(alpha: 0.25)
                  : Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: active ? accent : Colors.white.withValues(alpha: 0.14),
                width: active ? 1.4 : 0.8,
              ),
            ),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                label,
                maxLines: 1,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: active ? accent : Colors.white,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _keyBtn(String label, VoidCallback onTap) {
    return ElevatedButton(
      onPressed: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.white.withValues(alpha: 0.08),
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      child: Text(
        label,
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
      ),
    );
  }

  Widget _comboBtn(String label, VoidCallback onTap) {
    return FilledButton.tonal(
      onPressed: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      style: FilledButton.styleFrom(
        backgroundColor: Colors.white.withValues(alpha: 0.14),
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      child: Text(
        label,
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
      ),
    );
  }
}
