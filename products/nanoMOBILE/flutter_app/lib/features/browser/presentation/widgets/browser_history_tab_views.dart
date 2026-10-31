// QUÉ: Vistas de contenido de Marcadores e Historial para Nano Browser.
// CÓMO: Renderiza listas separadas con soporte de borrado, selección y estados vacíos.
// POR QUÉ: Extraído de BrowserHistoryBookmarksDialog para cumplir con SOLID y límite de 200 líneas.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../application/browser_history_notifier.dart';

class BrowserBookmarksView extends StatelessWidget {
  final List<BrowserBookmarkItem> bookmarks;
  final bool isDark;
  final ValueChanged<String> onSelectUrl;
  final ValueChanged<String> onDeleteBookmark;

  const BrowserBookmarksView({
    super.key,
    required this.bookmarks,
    required this.isDark,
    required this.onSelectUrl,
    required this.onDeleteBookmark,
  });

  @override
  Widget build(BuildContext context) {
    if (bookmarks.isEmpty) {
      return const _EmptyState(
        msg: 'Sin marcadores guardados',
        icon: Icons.bookmark_border_rounded,
      );
    }

    return ListView.separated(
      physics: const BouncingScrollPhysics(),
      itemCount: bookmarks.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final item = bookmarks[index];
        return ListTile(
          dense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 4),
          leading: Icon(
            Icons.bookmark_rounded,
            color: isDark ? const Color(0xFF38BDF8) : const Color(0xFF007AFF),
            size: 18,
          ),
          title: Text(
            item.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
          ),
          subtitle: Text(
            item.url,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 10.5, color: Colors.grey),
          ),
          trailing: IconButton(
            icon: const Icon(Icons.delete_outline_rounded, size: 16),
            onPressed: () {
              HapticFeedback.lightImpact();
              onDeleteBookmark(item.url);
            },
          ),
          onTap: () {
            HapticFeedback.selectionClick();
            Navigator.pop(context);
            onSelectUrl(item.url);
          },
        );
      },
    );
  }
}

class BrowserHistoryView extends StatelessWidget {
  final List<BrowserHistoryItem> history;
  final ValueChanged<String> onSelectUrl;
  final VoidCallback onClearHistory;

  const BrowserHistoryView({
    super.key,
    required this.history,
    required this.onSelectUrl,
    required this.onClearHistory,
  });

  @override
  Widget build(BuildContext context) {
    if (history.isEmpty) {
      return const _EmptyState(
        msg: 'Historial vacío',
        icon: Icons.history_rounded,
      );
    }

    return Column(
      children: [
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            onPressed: () {
              HapticFeedback.mediumImpact();
              onClearHistory();
            },
            icon: const Icon(Icons.delete_sweep_rounded, size: 14),
            label: const Text('Borrar historial', style: TextStyle(fontSize: 11)),
          ),
        ),
        Expanded(
          child: ListView.separated(
            physics: const BouncingScrollPhysics(),
            itemCount: history.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final item = history[index];
              return ListTile(
                dense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                leading: const Icon(Icons.history_rounded, size: 16),
                title: Text(
                  item.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w500),
                ),
                subtitle: Text(
                  item.url,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 10.5, color: Colors.grey),
                ),
                onTap: () {
                  HapticFeedback.selectionClick();
                  Navigator.pop(context);
                  onSelectUrl(item.url);
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  final String msg;
  final IconData icon;

  const _EmptyState({required this.msg, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 36, color: Colors.grey.withValues(alpha: 0.5)),
          const SizedBox(height: 6),
          Text(msg, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        ],
      ),
    );
  }
}
