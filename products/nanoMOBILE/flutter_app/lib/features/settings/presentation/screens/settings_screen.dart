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

/// Pantalla de Ajustes de Nano AI con diseño iOS Glassed Metálico compacto y optimizado.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);
    final colors = NanoThemeExtension.of(context).colors;

    return Material(
      type: MaterialType.transparency,
      child: DefaultTextStyle(
        style: TextStyle(
          fontFamily: 'Inter',
          color: colors.onSurface,
          decoration: TextDecoration.none,
        ),
        child: SafeArea(
          top: false,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final scale = MediaQuery.textScalerOf(context).scale(16) / 16;
              final twoColumns = constraints.maxWidth >= 720 * scale;

              final col1 = [
                AppearanceSettingsCard(
                  colors: colors,
                  currentThemeMode: state.themeMode,
                  onThemeChanged: notifier.setThemeMode,
                ),
                GlassSettingsCard(
                  state: state,
                  notifier: notifier,
                  colors: colors,
                ),
                const FloatingAssistantSection(),
              ];

              final col2 = [
                AiEngineSettingsCard(
                  state: state,
                  notifier: notifier,
                  colors: colors,
                ),
                const DevicePermissionsSection(),
                const DesktopVncSettingsCard(),
              ];

              return ListView(
                physics: const BouncingScrollPhysics(
                  parent: AlwaysScrollableScrollPhysics(),
                ),
                keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                // El dock flota sobre el contenido: la reserva final sigue la
                // altura real del dock en cada orientación, sin vacío extra.
                padding: EdgeInsets.fromLTRB(
                  14,
                  10,
                  14,
                  (MediaQuery.orientationOf(context) == Orientation.landscape
                          ? kNanoBarScrollReserveLandscape
                          : kNanoBarScrollReserve) +
                      28,
                ),
                children: [
                  SettingsHeaderSection(
                    colors: colors,
                    themeMode: state.themeMode,
                  ),
                  const SizedBox(height: 12),
                  const AccountSettingsSection(),
                  const SizedBox(height: 10),
                  if (twoColumns)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: _sections(col1)),
                        const SizedBox(width: 14),
                        Expanded(child: _sections(col2)),
                      ],
                    )
                  else
                    _sections([...col1, ...col2]),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _sections(List<Widget> cards) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      for (var i = 0; i < cards.length; i++) ...[
        if (i > 0) const SizedBox(height: 12),
        cards[i],
      ],
    ],
  );
}
