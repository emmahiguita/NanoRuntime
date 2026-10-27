import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nanoai/core/providers/settings_provider.dart';
import 'package:nanoai/core/theme/design_tokens.dart';
import 'package:nanoai/core/widgets/nano_glass_window.dart';

part 'messaging_theme_tile.part.dart';

/// Abre la ventana flotante Glassed para seleccionar el tema del panel.
Future<void> showMessagingThemeSheet(BuildContext context, WidgetRef ref) {
  return showNanoGlassWindow<void>(
    context: context,
    builder: (sheetContext) => const _MessagingThemeDialogBody(),
  );
}

class _MessagingThemeDialogBody extends ConsumerWidget {
  const _MessagingThemeDialogBody();

  static const _themeOptions = [
    (
      'Oscuro',
      'Obsidiana',
      'OLED profundo y contrastes cósmicos',
      Icons.dark_mode_rounded,
      Color(0xFF818CF8),
    ),
    (
      'Grisáceo',
      'Gris Espacial',
      'Titanio pizarra mate anti-reflejos',
      Icons.layers_rounded,
      Color(0xFF38BDF8),
    ),
    (
      'Claro',
      'Blanco Puro',
      'Interfaz luminosa y cristal escarchado',
      Icons.wb_sunny_rounded,
      Color(0xFFF59E0B),
    ),
    (
      'Sistema',
      'Automático',
      'Sincronizado con el dispositivo Android',
      Icons.brightness_auto_rounded,
      Color(0xFF10B981),
    ),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colors = NanoThemeExtension.of(context).colors;
    final currentThemeMode =
        ref.watch(settingsProvider.select((s) => s.themeMode));

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(18, 6, 18, 18),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: colors.primary.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: colors.primary.withValues(alpha: 0.35),
                  ),
                ),
                child: Icon(
                  Icons.palette_rounded,
                  size: 18,
                  color: colors.primary,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Tema Visual del Panel',
                      style: TextStyle(
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                        fontSize: 16.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 1.5),
                    Text(
                      'Personaliza el modo claro, oscuro o gris del sistema.',
                      style: TextStyle(
                        color:
                            isDark ? Colors.white60 : const Color(0xFF64748B),
                        fontSize: 11.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ..._themeOptions.map((opt) {
            final key = opt.$1;
            final isSelected = currentThemeMode == key ||
                (key == 'Grisáceo' &&
                    (currentThemeMode == 'Opaco' ||
                        currentThemeMode == 'Clásico'));

            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _ThemeOptionTile(
                title: opt.$2,
                subtitle: opt.$3,
                icon: opt.$4,
                accentColor: opt.$5,
                isSelected: isSelected,
                isDark: isDark,
                onTap: () {
                  HapticFeedback.mediumImpact();
                  ref.read(settingsProvider.notifier).setThemeMode(key);
                  Navigator.of(context).pop();
                },
              ),
            );
          }),
        ],
      ),
    );
  }
}
