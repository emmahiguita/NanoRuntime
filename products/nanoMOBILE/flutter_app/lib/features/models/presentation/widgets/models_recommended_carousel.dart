// QUÉ HACE: Presenta opciones LiteRT-LM activas del catálogo.
// CÓMO FUNCIONA: Construye las tarjetas desde NeuralCatalog y distingue la prueba del Oppo.
// POR QUÉ: Evita nombres, calificaciones y benchmarks que no pertenecen a Nano.
library;

import 'dart:async';
import 'package:flutter/material.dart';
import '../../../../core/models/catalog_models.dart';
import '../../../../core/theme/design_tokens.dart';
import 'models_carousel_card.dart';

class ModelsRecommendedCarousel extends StatefulWidget {
  final ValueChanged<String>? onModelTap;

  const ModelsRecommendedCarousel({super.key, this.onModelTap});

  // Solo aparecen modelos de chat que el runtime actual enruta por LiteRT-LM.
  static final List<RecommendedModelCardData> featuredModels = [
    for (final entry in NeuralCatalog.models)
      if (entry.kind == ModelKind.llm &&
          entry.backendType == ModelBackendType.litertlm)
        RecommendedModelCardData.fromCatalog(entry),
  ];

  @override
  State<ModelsRecommendedCarousel> createState() =>
      _ModelsRecommendedCarouselState();
}

class _ModelsRecommendedCarouselState extends State<ModelsRecommendedCarousel> {
  late final PageController _pageController;
  Timer? _autoScrollTimer;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(viewportFraction: 0.94);
    _startAutoScroll();
  }

  void _startAutoScroll() {
    _autoScrollTimer?.cancel();
    if (ModelsRecommendedCarousel.featuredModels.length < 2) return;
    _autoScrollTimer = Timer.periodic(const Duration(milliseconds: 4600), (_) {
      if (!mounted || !_pageController.hasClients) return;
      final nextPage =
          (_currentPage + 1) % ModelsRecommendedCarousel.featuredModels.length;
      _pageController.animateToPage(
        nextPage,
        duration: const Duration(milliseconds: 650),
        curve: Curves.easeInOutCubic,
      );
    });
  }

  @override
  void dispose() {
    _autoScrollTimer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = NanoThemeExtension.of(context).colors;
    final items = ModelsRecommendedCarousel.featuredModels;
    if (items.isEmpty) return const SizedBox.shrink();

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 142,
          child: NotificationListener<UserScrollNotification>(
            onNotification: (_) {
              _startAutoScroll();
              return false;
            },
            child: PageView.builder(
              controller: _pageController,
              itemCount: items.length,
              onPageChanged: (idx) => setState(() => _currentPage = idx),
              itemBuilder: (context, index) => ModelsCarouselCard(
                model: items[index],
                onTap: () => widget.onModelTap?.call(items[index].title),
              ),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(items.length, (idx) {
            final isCurrent = _currentPage == idx;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              margin: const EdgeInsets.symmetric(horizontal: 2.5),
              height: 3.5,
              width: isCurrent ? 16 : 5,
              decoration: BoxDecoration(
                color: isCurrent
                    ? colors.onSurfaceVariant
                    : colors.outlineVariant.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            );
          }),
        ),
      ],
    );
  }
}
