// automation_inbox_card.dart — Hero Card 3D Hiper-Realista con Movimiento 360° y Sombra Pro.
// QUÉ HACE: Tarjeta publicitaria gran formato con inclinación 3D táctil, órbita 360° y sombras realistas.
// CÓMO FUNCIONA: Matrix4 con perspectiva, animación continua 360°, PageView publicitario y luz especular.
// POR QUÉ: Otorga presencia de alto impacto visual M3 Expressive sin superar 200 líneas.
library;

import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../application/automation_coordinator_provider.dart' show pendingRepliesProvider;
import 'automation_glass_360.dart';

class AutomationInboxCard extends ConsumerStatefulWidget {
  final VoidCallback onTap;
  const AutomationInboxCard({super.key, required this.onTap});

  @override
  ConsumerState<AutomationInboxCard> createState() => _AutomationInboxCardState();
}

class _AutomationInboxCardState extends ConsumerState<AutomationInboxCard>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final PageController _pageController;
  late final AnimationController _orbitController;
  Timer? _autoPlayTimer;
  int _currentIndex = 0;
  double _touchTiltX = 0.0, _touchTiltY = 0.0;
  bool _pressed = false;

  static const _banners = [
    'assets/promo/ad_messaging_1.png',
    'assets/promo/ad_messaging_2.png',
    'assets/promo/ad_messaging_3.png',
    'assets/promo/ad_messaging_4.png',
  ];

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _orbitController = AnimationController(vsync: this, duration: const Duration(milliseconds: 5500))..repeat();
    _autoPlayTimer = Timer.periodic(const Duration(milliseconds: 4500), (_) {
      if (!mounted || !_pageController.hasClients) return;
      _pageController.animateToPage((_currentIndex + 1) % _banners.length,
          duration: const Duration(milliseconds: 650), curve: Curves.easeInOutCubic);
    });
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState s) {
    if (s == AppLifecycleState.resumed) {
      if (!_orbitController.isAnimating) _orbitController.repeat();
    } else {
      if (_orbitController.isAnimating) _orbitController.stop();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _autoPlayTimer?.cancel();
    _orbitController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final drafts = ref.watch(pendingRepliesProvider);
    final count = drafts.maybeWhen(data: (l) => l.where((d) => d.isActionable).length, orElse: () => 0);
    final isLand = MediaQuery.of(context).orientation == Orientation.landscape;
    final accent = count > 0 ? const Color(0xFF10B981) : const Color(0xFF22D3EE);

    return AnimatedBuilder(
      animation: _orbitController,
      builder: (context, _) {
        final phase = _orbitController.value * 2 * math.pi;
        final rotX = (_touchTiltX + math.sin(phase) * 0.038).clamp(-0.12, 0.12);
        final rotY = (_touchTiltY + math.cos(phase) * 0.048).clamp(-0.14, 0.14);
        final sX = rotY * 45, sY = 12 - (rotX * 35);

        return Transform(
          alignment: Alignment.center,
          transform: Matrix4.identity()..setEntry(3, 2, 0.0010)..rotateX(rotX)..rotateY(rotY),
          child: GestureDetector(
            onPanUpdate: (d) => setState(() {
              _touchTiltX = (d.localPosition.dy - 90) / 900;
              _touchTiltY = -(d.localPosition.dx - 160) / 1100;
            }),
            onPanEnd: (_) => setState(() { _touchTiltX = 0; _touchTiltY = 0; }),
            onTapDown: (_) => setState(() => _pressed = true),
            onTapUp: (_) => setState(() => _pressed = false),
            onTapCancel: () => setState(() => _pressed = false),
            onTap: () { HapticFeedback.lightImpact(); widget.onTap(); },
            child: AnimatedScale(
              scale: _pressed ? 0.98 : 1.0,
              duration: const Duration(milliseconds: 140),
              curve: Curves.easeOutCubic,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(26),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withValues(alpha: 0.70), blurRadius: 30, spreadRadius: -2, offset: Offset(sX, sY)),
                    const BoxShadow(color: Colors.black45, blurRadius: 14, offset: Offset(0, 6)),
                    BoxShadow(color: accent.withValues(alpha: 0.22), blurRadius: 28, spreadRadius: -3, offset: Offset(sX * 0.4, 4)),
                  ],
                ),
                child: AutomationGlass360(
                  borderRadius: 26.0,
                  accentColor: accent,
                  isActionable: count > 0,
                  child: AspectRatio(
                    aspectRatio: isLand ? 3.5 : 2.45,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        PageView.builder(
                          controller: _pageController,
                          onPageChanged: (i) => setState(() => _currentIndex = i),
                          itemCount: _banners.length,
                          itemBuilder: (_, idx) => Image.asset(_banners[idx], fit: BoxFit.cover, alignment: Alignment.center),
                        ),
                        // Reflejo especular hiper-realista que viaja en 360°
                        Positioned.fill(
                          child: IgnorePointer(
                            child: Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment(math.cos(phase), math.sin(phase)),
                                  end: Alignment(-math.cos(phase), -math.sin(phase)),
                                  colors: [Colors.white.withValues(alpha: 0.12), Colors.transparent, Colors.white.withValues(alpha: 0.04)],
                                  stops: const [0.0, 0.45, 1.0],
                                ),
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          bottom: 10,
                          right: 14,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: List.generate(_banners.length, (i) {
                              final active = i == _currentIndex;
                              return AnimatedContainer(
                                duration: const Duration(milliseconds: 300),
                                margin: const EdgeInsets.symmetric(horizontal: 2.5),
                                width: active ? 16 : 5,
                                height: 4.5,
                                decoration: BoxDecoration(
                                  color: active ? const Color(0xFF10B981) : Colors.white30,
                                  borderRadius: BorderRadius.circular(3),
                                ),
                              );
                            }),
                          ),
                        ),
                        if (count > 0)
                          Positioned(
                            top: 10,
                            right: 12,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                              decoration: BoxDecoration(
                                color: const Color(0xFF10B981),
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [BoxShadow(color: const Color(0xFF10B981).withValues(alpha: 0.4), blurRadius: 6)],
                              ),
                              child: Text(
                                '$count PENDIENTE${count == 1 ? '' : 'S'}',
                                style: const TextStyle(color: Colors.black, fontSize: 9.5, fontWeight: FontWeight.w900),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
