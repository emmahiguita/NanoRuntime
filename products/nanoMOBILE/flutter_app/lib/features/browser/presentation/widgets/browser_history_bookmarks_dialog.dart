// QUÉ: Modal para gestionar Marcadores y Registro de Historial de Navegación.
// CÓMO: Presenta pestañas para navegar y administrar marcadores e historial.
// POR QUÉ: Permite recuperar enlaces guardados y visitas pasadas sin fricción (< 120 líneas).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nanoai/core/widgets/nano_glass_window.dart';
import 'package:nanoai/features/browser/application/browser_history_notifier.dart';
import 'browser_history_tab_views.dart';

class BrowserHistoryBookmarksDialog extends ConsumerStatefulWidget {
  final int initialTabIndex;
  final ValueChanged<String> onSelectUrl;

  const BrowserHistoryBookmarksDialog({
    super.key,
    this.initialTabIndex = 0,
    required this.onSelectUrl,
  });

  static Future<void> show({
    required BuildContext context,
    int initialTabIndex = 0,
    required ValueChanged<String> onSelectUrl,
  }) {
    return showNanoGlassWindow(
      context: context,
      builder: (_) => BrowserHistoryBookmarksDialog(
        initialTabIndex: initialTabIndex,
        onSelectUrl: onSelectUrl,
      ),
    );
  }

  @override
  ConsumerState<BrowserHistoryBookmarksDialog> createState() =>
      _BrowserHistoryBookmarksDialogState();
}

class _BrowserHistoryBookmarksDialogState
    extends ConsumerState<BrowserHistoryBookmarksDialog>
    with SingleTickerProviderStateMixin {
  late final TabController _tabCtrl;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(
      length: 2,
      vsync: this,
      initialIndex: widget.initialTabIndex,
    );
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final state = ref.watch(browserHistoryProvider);
    final notifier = ref.read(browserHistoryProvider.notifier);
    final mq = MediaQuery.of(context);
    final isLand = mq.orientation == Orientation.landscape;

    final bg = isDark
        ? theme.colorScheme.surface.withValues(alpha: 0.94)
        : theme.colorScheme.surfaceContainerHigh.withValues(alpha: 0.96);

    return Center(
      child: Container(
        height: isLand ? mq.size.height * 0.90 : mq.size.height * 0.65,
        constraints: const BoxConstraints(maxWidth: 500),
        margin: EdgeInsets.fromLTRB(12, 0, 12, isLand ? 6 : 16),
        padding: EdgeInsets.all(isLand ? 10 : 14),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: isDark ? Colors.white12 : theme.colorScheme.outlineVariant,
          ),
          boxShadow: const [
            BoxShadow(
              color: Colors.black38,
              blurRadius: 24,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          children: [
            Container(
              width: 32,
              height: 4,
              decoration: BoxDecoration(
                color: isDark ? Colors.white24 : Colors.black26,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 10),
            Container(
              height: 36,
              decoration: BoxDecoration(
                color: isDark ? Colors.white10 : Colors.black12,
                borderRadius: BorderRadius.circular(10),
              ),
              child: TabBar(
                controller: _tabCtrl,
                indicatorSize: TabBarIndicatorSize.tab,
                dividerColor: Colors.transparent,
                indicator: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF38BDF8)
                      : const Color(0xFF007AFF),
                  borderRadius: BorderRadius.circular(8),
                ),
                labelColor: Colors.white,
                unselectedLabelColor: isDark ? Colors.white60 : Colors.black54,
                labelStyle: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.bold,
                ),
                tabs: const [Tab(text: 'Marcadores'), Tab(text: 'Historial')],
              ),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: TabBarView(
                controller: _tabCtrl,
                children: [
                  BrowserBookmarksView(
                    bookmarks: state.bookmarks,
                    isDark: isDark,
                    onSelectUrl: widget.onSelectUrl,
                    onDeleteBookmark: (url) => notifier.removeBookmark(url),
                  ),
                  BrowserHistoryView(
                    history: state.history,
                    onSelectUrl: widget.onSelectUrl,
                    onClearHistory: () => notifier.clearHistory(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
