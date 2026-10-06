import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nanoai/core/providers/app_providers.dart';
import 'package:nanoai/core/theme/design_tokens.dart';
import 'package:nanoai/core/widgets/navigation/nano_navigation_panel.dart';
import '../widgets/account_settings_card.dart';
import '../widgets/ai_engine_settings_card.dart';
import '../widgets/appearance_settings_card.dart';
import '../widgets/desktop_vnc_settings_card.dart';
import '../widgets/device_permissions_section.dart';
import '../widgets/floating_assistant_section.dart';
import '../widgets/glass_settings_card.dart';
import '../widgets/settings_header_section.dart';

/// Coordina ajustes reales; las tarjetas conservan sus proveedores y acciones.
/// Usa el Overlay del Navigator: initialEntries locales congelaban la vista.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  /// Decide columnas por espacio Ãºtil y tamaÃ±o de texto, no solo orientaciÃ³n.
  /// AsÃ­ una ventana estrecha o letras grandes no comprimen los controles.
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);
    final colors = NanoThemeExtension.of(context).colors;
    return Material(
      type: MaterialType.transparency,
      child: SafeArea(
        top: false,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final scale = MediaQuery.textScalerOf(context).scale(16) / 16;
            final twoColumns = constraints.maxWidth >= 720 * scale;
            final primary = [
              AppearanceSettingsCard(colors: colors, currentThemeMode: state.themeMode, onThemeChanged: notifier.setThemeMode),
              GlassSettingsCard(
                state: state,
                notifier: notifier,
                colors: colors,
              ),
              const FloatingAssistantSection(),
              const DevicePermissionsSection(),
            ];
            final secondary = [
              AiEngineSettingsCard(
                state: state,
                notifier: notifier,
                colors: colors,
              ),
              const DesktopVncSettingsCard(),
            ];
            return ListView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.fromLTRB(
                16,
                12,
                16,
                kNanoBarScrollReserve,
              ),
              children: [
                SettingsHeaderSection(
                  colors: colors,
                  themeMode: state.themeMode,
                ),
                const SizedBox(height: 20),
                const AccountSettingsSection(),
                const SizedBox(height: 16),
                if (twoColumns)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: _sections(primary)),
                      const SizedBox(width: 20),
                      Expanded(child: _sections(secondary)),
                    ],
                  )
                else
                  _sections([...primary, ...secondary]),
              ],
            );
          },
        ),
      ),
    );
  }

  /// Mantiene el espaciado en un solo lugar sin duplicar las tarjetas.
  Widget _sections(List<Widget> cards) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      for (var i = 0; i < cards.length; i++) ...[
        if (i > 0) const SizedBox(height: 20),
        cards[i],
      ],
    ],
  );
}
