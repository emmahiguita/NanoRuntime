// models_promo_hero_banner.dart — Banner carrusel publicitario sincronizado con tiempo de lectura.
// QUÉ HACE: Rota frases de producto e identidad con reveal tipográfico, shimmer y pausa de lectura.
// CÓMO FUNCIONA: AnimationController cíclico de 6s con indicadores de progreso interactivos por toque.
// POR QUÉ: Permite lectura 100% cómoda, fluidez iOS Glassed y cumplimiento estricto < 200 líneas.
library;

import 'dart:ui';
import 'package:flutter/material.dart';
import '../../../../core/theme/design_tokens.dart';

part 'models_promo_hero_banner.part.dart';

class ModelsPromoHeroBanner extends StatefulWidget {
  const ModelsPromoHeroBanner({super.key});

  @override
  State<ModelsPromoHeroBanner> createState() => _ModelsPromoHeroBannerState();
}

class _ModelsPromoHeroBannerState extends State<ModelsPromoHeroBanner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 6200),
    );

    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        if (!mounted) return;
        setState(() {
          _currentIndex = (_currentIndex + 1) % kPromoPhrases.length;
        });
        _controller.forward(from: 0.0);
      }
    });

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _selectSlide(int index) {
    if (!mounted || index == _currentIndex) return;
    setState(() => _currentIndex = index);
    _controller.forward(from: 0.0);
  }

  void _handleSwipe(DragEndDetails details) {
    final vx = details.primaryVelocity ?? 0.0;
    if (vx < -200) {
      _selectSlide((_currentIndex + 1) % kPromoPhrases.length);
    } else if (vx > 200) {
      _selectSlide((_currentIndex - 1 + kPromoPhrases.length) % kPromoPhrases.length);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = NanoThemeExtension.of(context).colors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final phrase = kPromoPhrases[_currentIndex];

    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 10),
      child: GestureDetector(
        onHorizontalDragEnd: _handleSwipe,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: Container(
            height: 144,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.16)
                    : colors.outlineVariant.withValues(alpha: 0.5),
                width: 1.0,
              ),
              boxShadow: [
                BoxShadow(
                  color: phrase.accentColor.withValues(alpha: isDark ? 0.20 : 0.10),
                  blurRadius: 18,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Stack(
              fit: StackFit.expand,
              children: [
                Image.asset(
                  'assets/promo/banner_hero_cosmic.png',
                  fit: BoxFit.cover,
                  alignment: Alignment.centerRight,
                ),
                buildCosmicGlassScaffold(isDark),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: AnimatedBuilder(
                    animation: _controller,
                    builder: (context, _) {
                      final t = _controller.value;
                      final typeProgress = (t / 0.15).clamp(0.0, 1.0);
                      final shimmerPos = ((t - 0.10) / 0.35).clamp(0.0, 1.0) * 3.0 - 1.0;
                      final contentOpacity = t < 0.90
                          ? 1.0
                          : (1.0 - ((t - 0.90) / 0.10)).clamp(0.0, 1.0);

                      final charCount = (typeProgress * phrase.title.length)
                          .clamp(1, phrase.title.length)
                          .toInt();

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Row(
                            children: [
                              buildPromoBadge(phrase),
                              const Spacer(),
                              buildProgressDots(
                                currentIndex: _currentIndex,
                                currentProgress: t,
                                onDotTapped: _selectSlide,
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Opacity(
                            opacity: contentOpacity,
                            child: buildGlowingTitle(
                              phrase.title.substring(0, charCount),
                              shimmerPos,
                              phrase.accentColor,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Opacity(
                            opacity: contentOpacity,
                            child: buildSubtitle(phrase.subtitle),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
