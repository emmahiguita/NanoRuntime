import 'package:flutter/material.dart';
import '../../domain/browser_tab_model.dart';
import 'browser_icon_button.dart';
import 'browser_options_content.dart';

/// Menú Material desplazable: sin filtros GPU, halos ni paletas por acción.
class BrowserOptionsSheet extends StatelessWidget {
  final BrowserTabModel tab;
  final bool isBookmarked, isDesktopMode, isDarkModeWeb;
  final ValueChanged<String> onAction;
  const BrowserOptionsSheet({
    super.key,
    required this.tab,
    required this.isBookmarked,
    required this.isDesktopMode,
    required this.isDarkModeWeb,
    required this.onAction,
  });

  /// El Navigator raíz proporciona el Overlay y SafeArea respeta notch y gestos.
  static Future<void> show({
    required BuildContext context,
    required BrowserTabModel tab,
    required bool isBookmarked,
    required bool isDesktopMode,
    required bool isDarkModeWeb,
    required ValueChanged<String> onAction,
  }) => showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    constraints: const BoxConstraints(maxWidth: 560),
    builder: (_) => BrowserOptionsSheet(
      tab: tab,
      isBookmarked: isBookmarked,
      isDesktopMode: isDesktopMode,
      isDarkModeWeb: isDarkModeWeb,
      onAction: onAction,
    ),
  );

  /// Cierra primero esta hoja; el despachador conserva el contexto de la página.
  void _trigger(BuildContext context, String action) {
    Navigator.of(context).pop();
    onAction(action);
  }

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
    child: SafeArea(
      top: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 16, right: 8),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Opciones del navegador',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        tab.displayHost.isEmpty
                            ? 'Página actual'
                            : tab.displayHost,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
                BrowserIconButton(
                  icon: Icons.close_rounded,
                  label: 'Cerrar opciones',
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
          BrowserOptionsContent(
            tab: tab,
            isBookmarked: isBookmarked,
            isDesktopMode: isDesktopMode,
            isDarkModeWeb: isDarkModeWeb,
            onAction: (action) => _trigger(context, action),
          ),
        ],
      ),
    ),
  );
}
