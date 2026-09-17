import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nanoai/features/browser/application/browser_history_notifier.dart';

/// Modal estilo iOS para gestionar Marcadores y Registro de Historial de Navegación.
class BrowserHistoryBookmarksDialog extends ConsumerStatefulWidget {
  final int initialTabIndex; // 0 = Marcadores, 1 = Historial
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
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
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
  late TabController _tabCtrl;

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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final historyState = ref.watch(browserHistoryProvider);
    final historyNotifier = ref.read(browserHistoryProvider.notifier);
    final mq = MediaQuery.of(context);
    final isLandscape = mq.orientation == Orientation.landscape;
    final screenHeight = mq.size.height;

    return Center(
      child: Container(
        height: isLandscape ? screenHeight * 0.88 : screenHeight * 0.65,
        constraints: const BoxConstraints(maxWidth: 540),
        margin: EdgeInsets.fromLTRB(14, 0, 14, isLandscape ? 8 : 20),
        padding: EdgeInsets.all(isLandscape ? 12 : 16),
        decoration: BoxDecoration(
        color: isDark ? const Color(0xF20F1D2C) : const Color(0xF8FFFFFF),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.12)
              : Colors.black.withValues(alpha: 0.08),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.38),
            blurRadius: 30,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: isDark ? Colors.white24 : Colors.black26,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Pestañas iOS Segmented Tab
          Container(
            height: 38,
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.08)
                  : Colors.black.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(12),
            ),
            child: TabBar(
              controller: _tabCtrl,
              indicatorSize: TabBarIndicatorSize.tab,
              dividerColor: Colors.transparent,
              indicator: BoxDecoration(
                color: isDark
                    ? const Color(0xFF10B981)
                    : const Color(0xFF2563EB),
                borderRadius: BorderRadius.circular(10),
              ),
              labelColor: Colors.white,
              unselectedLabelColor: isDark ? Colors.white60 : Colors.black54,
              labelStyle: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
              tabs: const [
                Tab(iconMargin: EdgeInsets.zero, text: 'Marcadores'),
                Tab(iconMargin: EdgeInsets.zero, text: 'Historial'),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Contenido de cada pestaña
          Expanded(
            child: TabBarView(
              controller: _tabCtrl,
              children: [
                // 1. Marcadores
                historyState.bookmarks.isEmpty
                    ? _buildEmptyState(
                        'Sin marcadores guardados',
                        Icons.bookmark_border_rounded,
                      )
                    : ListView.separated(
                        physics: const BouncingScrollPhysics(),
                        itemCount: historyState.bookmarks.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, idx) {
                          final b = historyState.bookmarks[idx];
                          return ListTile(
                            dense: true,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 4,
                            ),
                            leading: const Icon(
                              Icons.bookmark_rounded,
                              color: Color(0xFF10B981),
                              size: 20,
                            ),
                            title: Text(
                              b.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            subtitle: Text(
                              b.url,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 11,
                                color: Colors.grey,
                              ),
                            ),
                            trailing: IconButton(
                              icon: const Icon(
                                Icons.delete_outline_rounded,
                                size: 18,
                              ),
                              onPressed: () {
                                HapticFeedback.lightImpact();
                                historyNotifier.removeBookmark(b.url);
                              },
                            ),
                            onTap: () {
                              HapticFeedback.selectionClick();
                              Navigator.pop(context);
                              widget.onSelectUrl(b.url);
                            },
                          );
                        },
                      ),

                // 2. Historial
                historyState.history.isEmpty
                    ? _buildEmptyState('Historial vacío', Icons.history_rounded)
                    : Column(
                        children: [
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton.icon(
                              onPressed: () {
                                HapticFeedback.mediumImpact();
                                historyNotifier.clearHistory();
                              },
                              icon: const Icon(
                                Icons.delete_sweep_rounded,
                                size: 16,
                              ),
                              label: const Text(
                                'Borrar historial',
                                style: TextStyle(fontSize: 12),
                              ),
                            ),
                          ),
                          Expanded(
                            child: ListView.separated(
                              physics: const BouncingScrollPhysics(),
                              itemCount: historyState.history.length,
                              separatorBuilder: (_, __) =>
                                  const Divider(height: 1),
                              itemBuilder: (context, idx) {
                                final h = historyState.history[idx];
                                return ListTile(
                                  dense: true,
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 4,
                                  ),
                                  leading: const Icon(
                                    Icons.history_rounded,
                                    size: 18,
                                  ),
                                  title: Text(
                                    h.title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  subtitle: Text(
                                    h.url,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: Colors.grey,
                                    ),
                                  ),
                                  onTap: () {
                                    HapticFeedback.selectionClick();
                                    Navigator.pop(context);
                                    widget.onSelectUrl(h.url);
                                  },
                                );
                              },
                            ),
                          ),
                        ],
                      ),
              ],
            ),
          ),
        ],
      ),
    ));
  }

  Widget _buildEmptyState(String message, IconData icon) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 40, color: Colors.grey.withValues(alpha: 0.5)),
          const SizedBox(height: 8),
          Text(
            message,
            style: const TextStyle(fontSize: 13, color: Colors.grey),
          ),
        ],
      ),
    );
  }
}
