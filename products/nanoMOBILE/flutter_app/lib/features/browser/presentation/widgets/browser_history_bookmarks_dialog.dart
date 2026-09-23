import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nanoai/features/browser/application/browser_history_notifier.dart';

/// Modal para gestionar Marcadores y Registro de Historial de Navegación.
/// 
/// - QUÉ HACE: Presenta pestañas para navegar y administrar marcadores e historial.
/// - CÓMO FUNCIONA: Observa [browserHistoryProvider] y despacha navegación mediante [onSelectUrl].
/// - POR QUÉ: Permite recuperar enlaces guardados y visitas pasadas sin fricción (<200 líneas).
class BrowserHistoryBookmarksDialog extends ConsumerStatefulWidget {
  final int initialTabIndex;
  final ValueChanged<String> onSelectUrl;

  const BrowserHistoryBookmarksDialog({super.key, this.initialTabIndex = 0, required this.onSelectUrl});

  static Future<void> show({required BuildContext context, int initialTabIndex = 0, required ValueChanged<String> onSelectUrl}) {
    return showModalBottomSheet(
      context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
      builder: (_) => BrowserHistoryBookmarksDialog(initialTabIndex: initialTabIndex, onSelectUrl: onSelectUrl),
    );
  }

  @override
  ConsumerState<BrowserHistoryBookmarksDialog> createState() => _BrowserHistoryBookmarksDialogState();
}

class _BrowserHistoryBookmarksDialogState extends ConsumerState<BrowserHistoryBookmarksDialog> with SingleTickerProviderStateMixin {
  late final TabController _tabCtrl;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this, initialIndex: widget.initialTabIndex);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final state = ref.watch(browserHistoryProvider);
    final notifier = ref.read(browserHistoryProvider.notifier);
    final mq = MediaQuery.of(context);
    final isLand = mq.orientation == Orientation.landscape;

    return Center(
      child: Container(
        height: isLand ? mq.size.height * 0.90 : mq.size.height * 0.65,
        constraints: const BoxConstraints(maxWidth: 500),
        margin: EdgeInsets.fromLTRB(12, 0, 12, isLand ? 6 : 16),
        padding: EdgeInsets.all(isLand ? 10 : 14),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xF20F1D2C) : const Color(0xF8FFFFFF),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: isDark ? Colors.white12 : Colors.black12),
          boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 24, offset: Offset(0, 8))],
        ),
        child: Column(children: [
          Container(width: 32, height: 4, decoration: BoxDecoration(color: isDark ? Colors.white24 : Colors.black26, borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 10),
          Container(
            height: 36,
            decoration: BoxDecoration(color: isDark ? Colors.white10 : Colors.black12, borderRadius: BorderRadius.circular(10)),
            child: TabBar(
              controller: _tabCtrl, indicatorSize: TabBarIndicatorSize.tab, dividerColor: Colors.transparent,
              indicator: BoxDecoration(color: isDark ? const Color(0xFF10B981) : const Color(0xFF2563EB), borderRadius: BorderRadius.circular(8)),
              labelColor: Colors.white, unselectedLabelColor: isDark ? Colors.white60 : Colors.black54,
              labelStyle: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold),
              tabs: const [Tab(text: 'Marcadores'), Tab(text: 'Historial')],
            ),
          ),
          const SizedBox(height: 10),
          Expanded(child: TabBarView(
            controller: _tabCtrl,
            children: [
              state.bookmarks.isEmpty
                  ? _empty('Sin marcadores guardados', Icons.bookmark_border_rounded)
                  : ListView.separated(
                      physics: const BouncingScrollPhysics(), itemCount: state.bookmarks.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (c, i) {
                        final b = state.bookmarks[i];
                        return ListTile(
                          dense: true, contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                          leading: const Icon(Icons.bookmark_rounded, color: Color(0xFF10B981), size: 18),
                          title: Text(b.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
                          subtitle: Text(b.url, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 10.5, color: Colors.grey)),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete_outline_rounded, size: 16),
                            onPressed: () { HapticFeedback.lightImpact(); notifier.removeBookmark(b.url); },
                          ),
                          onTap: () { HapticFeedback.selectionClick(); Navigator.pop(context); widget.onSelectUrl(b.url); },
                        );
                      },
                    ),
              state.history.isEmpty
                  ? _empty('Historial vacío', Icons.history_rounded)
                  : Column(children: [
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton.icon(
                          onPressed: () { HapticFeedback.mediumImpact(); notifier.clearHistory(); },
                          icon: const Icon(Icons.delete_sweep_rounded, size: 14),
                          label: const Text('Borrar historial', style: TextStyle(fontSize: 11)),
                        ),
                      ),
                      Expanded(child: ListView.separated(
                        physics: const BouncingScrollPhysics(), itemCount: state.history.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (c, i) {
                          final h = state.history[i];
                          return ListTile(
                            dense: true, contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                            leading: const Icon(Icons.history_rounded, size: 16),
                            title: Text(h.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w500)),
                            subtitle: Text(h.url, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 10.5, color: Colors.grey)),
                            onTap: () { HapticFeedback.selectionClick(); Navigator.pop(context); widget.onSelectUrl(h.url); },
                          );
                        },
                      )),
                    ]),
            ],
          )),
        ]),
      ),
    );
  }

  Widget _empty(String msg, IconData icon) => Center(
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 36, color: Colors.grey.withValues(alpha: 0.5)),
      const SizedBox(height: 6),
      Text(msg, style: const TextStyle(fontSize: 12, color: Colors.grey)),
    ]),
  );
}
