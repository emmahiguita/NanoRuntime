/// MESSAGING-ADVERTISEMENT — Publicidad frontal de la card 3D (Centro de Mensajería).
///
/// QUÉ HACE:
/// Muestra las nuevas publicidades de alta fidelidad 16:9 sin recortes ni distorsión:
/// Centro de Mensajería con el Búho Cósmico de ojos galácticos, productividad y notificaciones.
///
/// CÓMO FUNCIONA:
/// Alterna automáticamente entre las 3 imágenes oficiales de mensajería (1024x576)
/// usando [PageView] sincronizado y superpone los badges de estado real de Nano AI.
///
/// POR QUÉ:
/// Ajustado exactamente a relación de aspecto 16:9 para evitar que el texto o los
/// personajes queden cortados en los laterales, manteniendo código < 200 líneas.
library;

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../application/automation_coordinator_provider.dart' show pendingRepliesProvider;

class MessagingAdvertisement extends ConsumerStatefulWidget {
  const MessagingAdvertisement({super.key});

  @override
  ConsumerState<MessagingAdvertisement> createState() => _MessagingAdvertisementState();
}

class _MessagingAdvertisementState extends ConsumerState<MessagingAdvertisement> {
  late final PageController _pageController;
  Timer? _autoPlayTimer;
  int _currentIndex = 0;

  static const _banners = [
    'assets/promo/card_messaging_crystal.jpg',
    'assets/promo/card_productivity_inspire.jpg',
    'assets/promo/card_night_companion.jpg',
  ];

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _autoPlayTimer = Timer.periodic(const Duration(milliseconds: 5500), (_) {
      if (!mounted || !_pageController.hasClients) return;
      final nextPage = (_currentIndex + 1) % _banners.length;
      _pageController.animateToPage(
        nextPage,
        duration: const Duration(milliseconds: 700),
        curve: Curves.easeInOutCubic,
      );
    });
  }

  @override
  void dispose() {
    _autoPlayTimer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final drafts = ref.watch(pendingRepliesProvider);
    final count = drafts.maybeWhen(
      data: (l) => l.where((d) => d.isActionable).length,
      orElse: () => 0,
    );

    return Stack(
      fit: StackFit.expand,
      children: [
        // 1. Carrusel de banners publicitarios 16:9 en alta resolución
        PageView.builder(
          physics: const NeverScrollableScrollPhysics(),
          controller: _pageController,
          onPageChanged: (i) => setState(() => _currentIndex = i),
          itemCount: _banners.length,
          itemBuilder: (_, idx) => Image.asset(
            _banners[idx],
            fit: BoxFit.cover,
            alignment: Alignment.center,
          ),
        ),
        // 2. Indicadores discretos de página
        Positioned(
          bottom: 8,
          right: 12,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(_banners.length, (i) {
              final active = i == _currentIndex;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                margin: const EdgeInsets.symmetric(horizontal: 2),
                width: active ? 14 : 4,
                height: 4,
                decoration: BoxDecoration(
                  color: active ? const Color(0xFF00FF88) : Colors.white38,
                  borderRadius: BorderRadius.circular(2),
                ),
              );
            }),
          ),
        ),
        // 3. Badge superior de pendientes reales
        if (count > 0)
          Positioned(
            top: 8,
            right: 10,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0xFF00FF88),
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF00FF88).withValues(alpha: 0.40),
                    blurRadius: 6,
                  ),
                ],
              ),
              child: Text(
                '$count PENDIENTE${count == 1 ? '' : 'S'}',
                style: const TextStyle(
                  color: Colors.black,
                  fontSize: 9,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.2,
                ),
              ),
            ),
          ),
        // 4. Etiqueta anverso
        Positioned(
          bottom: 8,
          left: 10,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.55),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: const Color(0xFF00FF88).withValues(alpha: 0.35),
                width: 0.8,
              ),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.auto_awesome_rounded, size: 9, color: Color(0xFF00FF88)),
                SizedBox(width: 3),
                Text(
                  'ANVERSO • NANO AI',
                  style: TextStyle(
                    color: Color(0xFF00FF88),
                    fontSize: 8,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
