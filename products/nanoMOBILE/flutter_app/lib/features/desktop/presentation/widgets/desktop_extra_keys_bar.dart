import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:nanoai/core/theme/design_tokens.dart';
import 'package:nanoai/features/desktop/presentation/widgets/desktop_stream_chrome.dart';

/// Quick PC Extra Keys Bar for Linux Remote Desktop.
/// Features sticky modifier states (Ctrl, Alt, Shift, Super) with glow indicators
/// and quick X11 shortcuts (Esc, Tab, Arrows, Del, F-keys, Ctrl+C, Ctrl+V, Alt+Tab, etc.).
class DesktopExtraKeysBar extends StatelessWidget {
  final NanoColors colors;
  final bool ctrlSticky;
  final bool altSticky;
  final bool shiftSticky;
  final bool superSticky;
  final VoidCallback onToggleCtrl;
  final VoidCallback onToggleAlt;
  final VoidCallback onToggleShift;
  final VoidCallback onToggleSuper;
  final ValueChanged<int> onQuickKey;
  final ValueChanged<List<int>> onCombo;
  final bool compact;

  const DesktopExtraKeysBar({
    super.key,
    required this.colors,
    required this.ctrlSticky,
    required this.altSticky,
    required this.shiftSticky,
    required this.superSticky,
    required this.onToggleCtrl,
    required this.onToggleAlt,
    required this.onToggleShift,
    required this.onToggleSuper,
    required this.onQuickKey,
    required this.onCombo,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final accent = colors.chromeActive;

    return Container(
      height: compact ? 34 : 48,
      padding: EdgeInsets.symmetric(horizontal: compact ? 4 : 8, vertical: compact ? 2 : 4),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.85),
        border: Border(
          top: BorderSide(
            color: accent.withValues(alpha: 0.20),
            width: 0.8,
          ),
        ),
      ),
      child: ListView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        children: [
          // Sticky Modifiers
          _modifierChip('Ctrl', ctrlSticky, onToggleCtrl, accent),
          _modifierChip('Alt', altSticky, onToggleAlt, accent),
          _modifierChip('Shift', shiftSticky, onToggleShift, accent),
          _modifierChip('Super', superSticky, onToggleSuper, accent),

          _divider(),

          // Essential Navigation Keys
          _keyChip('Esc', () => onQuickKey(0xFF1B)),
          _keyChip('Tab', () => onQuickKey(0xFF09)),
          _keyChip('↵ Enter', () => onQuickKey(0xFF0D)),
          _keyChip('Del', () => onQuickKey(0xFFFF)),
          _keyChip('Bksp', () => onQuickKey(0xFF08)),

          _divider(),

          // Arrows
          _keyChip('←', () => onQuickKey(0xFF51)),
          _keyChip('↑', () => onQuickKey(0xFF52)),
          _keyChip('↓', () => onQuickKey(0xFF54)),
          _keyChip('→', () => onQuickKey(0xFF53)),

          _divider(),

          // Common Shortcuts
          _keyChip('Ctrl+C', () => onCombo([0xFFE3, 0x63])),
          _keyChip('Ctrl+V', () => onCombo([0xFFE3, 0x76])),
          _keyChip('Ctrl+X', () => onCombo([0xFFE3, 0x78])),
          _keyChip('Ctrl+Z', () => onCombo([0xFFE3, 0x7A])),
          _keyChip('Alt+Tab', () => onCombo([0xFFE9, 0xFF09])),
          _keyChip('Term', () => onCombo([0xFFE3, 0xFFE9, 0x74])), // Ctrl+Alt+T
        ],
      ),
    );
  }

  Widget _divider() {
    return Container(
      width: 1,
      height: 24,
      margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
      color: Colors.white.withValues(alpha: 0.15),
    );
  }

  Widget _modifierChip(String label, bool active, VoidCallback onTap, Color accent) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: compact ? 2 : 3),
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 8 : 11,
            vertical: compact ? 3 : 6,
          ),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: active ? accent.withValues(alpha: 0.28) : Colors.white.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(compact ? 7 : 9),
            border: Border.all(
              color: active ? accent : Colors.white.withValues(alpha: 0.14),
              width: active ? 1.2 : 0.8,
            ),
            boxShadow: active
                ? [
                    BoxShadow(
                      color: accent.withValues(alpha: 0.35),
                      blurRadius: 8,
                      spreadRadius: 0.5,
                    ),
                  ]
                : null,
          ),
          child: Text(
            label,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: compact ? 10.5 : 12,
              fontWeight: FontWeight.bold,
              color: active ? accent : Colors.white70,
            ),
          ),
        ),
      ),
    );
  }

  Widget _keyChip(String label, VoidCallback onTap) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: compact ? 2 : 3),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            HapticFeedback.selectionClick();
            onTap();
          },
          borderRadius: BorderRadius.circular(compact ? 7 : 9),
          splashColor: Colors.white24,
          child: Container(
            padding: EdgeInsets.symmetric(
              horizontal: compact ? 7 : 10,
              vertical: compact ? 3 : 6,
            ),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.07),
              borderRadius: BorderRadius.circular(compact ? 7 : 9),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.12),
                width: 0.8,
              ),
            ),
            child: Text(
              label,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: compact ? 10.5 : 12,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
