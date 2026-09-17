import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:nanoai/features/browser/domain/browser_tab_model.dart';
import 'package:nanoai/features/browser/presentation/widgets/browser_tab_bar_widget.dart';

/// Visual tab manager. It renders WebView snapshots, never a second WebView.
class BrowserTabOverview extends StatefulWidget {
  const BrowserTabOverview({
    super.key,
    required this.tabs,
    required this.activeIndex,
    required this.snapshots,
    required this.isCapturing,
    required this.onSelect,
    required this.onOpen,
    required this.onCloseTab,
    required this.onDone,
  });

  final List<BrowserTabModel> tabs;
  final int activeIndex;
  final Map<String, Uint8List> snapshots;
  final bool isCapturing;
  final ValueChanged<int> onSelect;
  final ValueChanged<int> onOpen;
  final ValueChanged<String> onCloseTab;
  final VoidCallback onDone;

  @override
  State<BrowserTabOverview> createState() => _BrowserTabOverviewState();
}

class _BrowserTabOverviewState extends State<BrowserTabOverview> {
  late final PageController _controller;

  @override
  void initState() {
    super.initState();
    _controller = PageController(
      initialPage: widget.activeIndex,
      viewportFraction: 0.84,
    );
  }

  @override
  void didUpdateWidget(covariant BrowserTabOverview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.activeIndex != widget.activeIndex &&
        _controller.hasClients &&
        _controller.page?.round() != widget.activeIndex) {
      _controller.animateToPage(
        widget.activeIndex,
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ColoredBox(
      color: isDark ? const Color(0xFA07101C) : const Color(0xFAE9EEF5),
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            _OverviewHeader(
              count: widget.tabs.length,
              isCapturing: widget.isCapturing,
              isDark: isDark,
              onDone: widget.onDone,
            ),
            Expanded(
              child: PageView.builder(
                key: const ValueKey('browser_snapshot_carousel'),
                controller: _controller,
                physics: const BouncingScrollPhysics(),
                itemCount: widget.tabs.length,
                onPageChanged: widget.onSelect,
                itemBuilder: (context, index) {
                  final tab = widget.tabs[index];
                  return AnimatedBuilder(
                    animation: _controller,
                    builder: (context, child) {
                      var page = widget.activeIndex.toDouble();
                      if (_controller.hasClients &&
                          _controller.position.haveDimensions) {
                        page = _controller.page ?? page;
                      }
                      final delta = (page - index).clamp(-1.0, 1.0);
                      final scale = 1 - (delta.abs() * 0.07);
                      final matrix = Matrix4.identity()
                        ..setEntry(3, 2, 0.0012)
                        ..rotateY(delta * -0.16)
                        ..scaleByDouble(scale, scale, 1, 1);
                      return Transform(
                        alignment: delta > 0
                            ? Alignment.centerRight
                            : Alignment.centerLeft,
                        transform: matrix,
                        child: child,
                      );
                    },
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(8, 8, 8, 18),
                      child: _SnapshotCard(
                        tab: tab,
                        bytes: widget.snapshots[tab.id],
                        isDark: isDark,
                        onTap: () => widget.onOpen(index),
                        onClose: widget.tabs.length > 1
                            ? () => widget.onCloseTab(tab.id)
                            : null,
                      ),
                    ),
                  );
                },
              ),
            ),
            _PageIndicator(
              count: widget.tabs.length,
              activeIndex: widget.activeIndex,
              isDark: isDark,
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}

class _OverviewHeader extends StatelessWidget {
  const _OverviewHeader({
    required this.count,
    required this.isCapturing,
    required this.isDark,
    required this.onDone,
  });

  final int count;
  final bool isCapturing;
  final bool isDark;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 12, 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Pestañas',
                  style: TextStyle(
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                    fontSize: 19,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.35,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  isCapturing
                      ? 'Actualizando vistas…'
                      : '$count ${count == 1 ? 'pestaña abierta' : 'pestañas abiertas'}',
                  style: TextStyle(
                    color: isDark ? Colors.white54 : const Color(0xFF64748B),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: onDone,
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFF60A5FA),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
            child: const Text(
              'Listo',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

class _SnapshotCard extends StatelessWidget {
  const _SnapshotCard({
    required this.tab,
    required this.bytes,
    required this.isDark,
    required this.onTap,
    this.onClose,
  });

  final BrowserTabModel tab;
  final Uint8List? bytes;
  final bool isDark;
  final VoidCallback onTap;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    final brandColor = BrowserTabBarWidget.getBrandColor(tab.url, isDark);
    final brandIcon = BrowserTabBarWidget.getBrandIcon(tab.url);
    return Material(
      color: isDark ? const Color(0xFF101A28) : Colors.white,
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: isDark ? Colors.white12 : const Color(0xFFD8E0EA),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.38 : 0.14),
                blurRadius: 26,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Column(
            children: [
              SizedBox(
                height: 48,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Row(
                    children: [
                      Container(
                        width: 26,
                        height: 26,
                        decoration: BoxDecoration(
                          color: brandColor.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(brandIcon, size: 15, color: brandColor),
                      ),
                      const SizedBox(width: 9),
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              tab.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: isDark
                                    ? Colors.white
                                    : const Color(0xFF0F172A),
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              tab.displayHost,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: isDark
                                    ? Colors.white38
                                    : const Color(0xFF64748B),
                                fontSize: 10.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (onClose != null)
                        IconButton(
                          tooltip: 'Cerrar pestaña',
                          onPressed: onClose,
                          icon: const Icon(Icons.close_rounded, size: 18),
                          visualDensity: VisualDensity.compact,
                        ),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    bottom: Radius.circular(21),
                  ),
                  child: bytes == null
                      ? _SnapshotPlaceholder(isDark: isDark, color: brandColor)
                      : Image.memory(
                          bytes!,
                          width: double.infinity,
                          height: double.infinity,
                          fit: BoxFit.cover,
                          alignment: Alignment.topCenter,
                          gaplessPlayback: true,
                          filterQuality: FilterQuality.medium,
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SnapshotPlaceholder extends StatelessWidget {
  const _SnapshotPlaceholder({required this.isDark, required this.color});

  final bool isDark;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: isDark ? const Color(0xFF08111E) : const Color(0xFFF1F5F9),
      child: Center(
        child: SizedBox(
          width: 28,
          height: 28,
          child: CircularProgressIndicator(strokeWidth: 2.2, color: color),
        ),
      ),
    );
  }
}

class _PageIndicator extends StatelessWidget {
  const _PageIndicator({
    required this.count,
    required this.activeIndex,
    required this.isDark,
  });

  final int count;
  final int activeIndex;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(count, (index) {
        final active = index == activeIndex;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          width: active ? 18 : 6,
          height: 6,
          margin: const EdgeInsets.symmetric(horizontal: 3),
          decoration: BoxDecoration(
            color: active
                ? const Color(0xFF3B82F6)
                : (isDark ? Colors.white24 : const Color(0xFFB8C2D0)),
            borderRadius: BorderRadius.circular(4),
          ),
        );
      }),
    );
  }
}
