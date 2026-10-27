// ai_web_sessions_sheet.dart — Panel interactivo de Sesiones de IA Web y selector de enrutamiento.
// QUÉ HACE: Centraliza las sesiones con ChatGPT, DeepSeek, Gemini, Kimi, Qwen y chats personalizados.
// CÓMO FUNCIONA: Abre ventanas flotantes para autenticación y gestiona el proveedor preferido de Nano.
// POR QUÉ: Permite al usuario conectar sus cuentas oficiales sin almacenar contraseñas ni salir de la app.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nanoai/core/widgets/nano_glass_window.dart';
import '../../../../core/theme/design_tokens.dart';
import '../../../browser/application/browser_pip_notifier.dart';
import '../../../browser/application/browser_tab_notifier.dart';
import '../../application/browser_ai_provider_registry.dart';
import '../../application/browser_ai_session_manager.dart';
import '../../application/browser_oauth_helper.dart';
import '../../domain/browser_ai_provider.dart';
import '../../infrastructure/browser_ai_preferences.dart';
import '../dialogs/add_custom_ai_chat_dialog.dart';
import '../widgets/ai_preferred_provider_selector.dart';
import '../widgets/ai_web_session_tile.dart';

class AiWebSessionsSheet extends ConsumerStatefulWidget {
  const AiWebSessionsSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showNanoGlassWindow(
      context: context,
      builder: (_) => const AiWebSessionsSheet(),
    );
  }

  @override
  ConsumerState<AiWebSessionsSheet> createState() => _AiWebSessionsSheetState();
}

class _AiWebSessionsSheetState extends ConsumerState<AiWebSessionsSheet> {
  void _openInFloatingWindow(BrowserAiProvider provider) {
    Navigator.of(context).pop();
    final tabNotifier = ref.read(browserTabProvider.notifier);
    final tabId = tabNotifier.addTab(
      initialUrl: provider.defaultUrl.toString(),
    );
    ref
        .read(browserPipProvider.notifier)
        .activatePip(
          tabId: tabId,
          url: provider.defaultUrl.toString(),
          title: provider.displayName,
        );
  }

  @override
  Widget build(BuildContext context) {
    final colors = NanoThemeExtension.of(context).colors;
    final registry = ref.watch(browserAiProviderRegistryProvider);
    final sessionManager = ref.watch(browserAiSessionManagerProvider);
    final preferred = ref.watch(preferredAiProviderStateProvider);
    final providers = registry.allProviders;

    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.80,
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 16, 12),
            child: Row(
              children: [
                Icon(Icons.auto_awesome, color: colors.primary, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Sesiones de IA Web',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ],
            ),
          ),
          Divider(
            height: 1,
            color: colors.outlineVariant.withValues(alpha: 0.45),
          ),
          AiPreferredProviderSelector(
            preferred: preferred,
            onSelect: (id) => ref
                .read(preferredAiProviderStateProvider.notifier)
                .setPreferred(id),
          ),
          Divider(
            height: 1,
            color: colors.outlineVariant.withValues(alpha: 0.45),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              itemCount: providers.length,
              itemBuilder: (ctx, idx) {
                final p = providers[idx];
                final session = sessionManager.getSession(p.id);
                final isConn = session?.isLoggedIn ?? false;
                final isCustom = p.id.startsWith('custom_');

                return AiWebSessionTile(
                  displayName: p.displayName,
                  url: p.defaultUrl.toString(),
                  isConnected: isConn,
                  isPreferred: preferred == p.id,
                  onConnectFloating: () => _openInFloatingWindow(p),
                  onOpenExternal: () =>
                      BrowserOAuthHelper.openInSystemBrowser(p.defaultUrl),
                  onSetPreferred: () {
                    final target = preferred == p.id ? 'auto' : p.id;
                    ref
                        .read(preferredAiProviderStateProvider.notifier)
                        .setPreferred(target);
                  },
                  onDeleteCustom: isCustom
                      ? () async {
                          await BrowserAiPreferences.removeCustomProvider(p.id);
                          setState(() {});
                        }
                      : null,
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: OutlinedButton.icon(
              onPressed: () => showDialog(
                context: context,
                builder: (_) =>
                    AddCustomAiChatDialog(onSaved: () => setState(() {})),
              ),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(46),
                side: BorderSide(color: colors.primary),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: Icon(Icons.add, color: colors.primary),
              label: Text(
                '+ Añadir otro chat',
                style: TextStyle(
                  color: colors.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
