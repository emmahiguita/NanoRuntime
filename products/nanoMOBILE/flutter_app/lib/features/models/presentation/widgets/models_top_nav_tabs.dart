// models_top_nav_tabs.dart — Pestañas superiores de navegación del módulo de modelos.
// QUÉ HACE: Renderiza la botonera de 4 pestañas: Explorar, Instalados, Favoritos y Descargas.
// CÓMO FUNCIONA: Micro-cápsulas estilizadas con iconos táctiles y animación de selección Material Expressive.
// POR QUÉ: Permite navegación directa y rápida en teléfonos móviles sin saturar la pantalla (< 150 líneas).
library;

import 'package:flutter/material.dart';
import '../../../../core/theme/design_tokens.dart';
import 'model_catalog_surface.dart';

/// Pestaña activa del módulo de modelos.
enum ModelsCatalogTab {
  explorar('Explorar', Icons.explore_outlined, Icons.explore_rounded),
  instalados(
    'Instalados',
    Icons.inventory_2_outlined,
    Icons.inventory_2_rounded,
  ),
  favoritos('Favoritos', Icons.favorite_border_rounded, Icons.favorite_rounded),
  descargas('Descargas', Icons.download_outlined, Icons.download_rounded);

  final String label;
  final IconData unselectedIcon;
  final IconData selectedIcon;
  const ModelsCatalogTab(this.label, this.unselectedIcon, this.selectedIcon);
}

class ModelsTopNavTabs extends StatelessWidget {
  final ModelsCatalogTab activeTab;
  final ValueChanged<ModelsCatalogTab> onTabSelected;
  final int installedCount;
  final int favoritesCount;
  final int downloadsCount;

  const ModelsTopNavTabs({
    super.key,
    required this.activeTab,
    required this.onTabSelected,
    this.installedCount = 0,
    this.favoritesCount = 0,
    this.downloadsCount = 0,
  });

  @override
  Widget build(BuildContext context) {
    final colors = NanoThemeExtension.of(context).colors;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: ModelsCatalogTab.values.map((tab) {
          final isSelected = activeTab == tab;
          final countBadge = _getBadgeCount(tab);

          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: InkWell(
                onTap: () => onTabSelected(tab),
                borderRadius: BorderRadius.circular(NanoRadius.medium),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOutCubic,
                  padding: const EdgeInsets.symmetric(
                    vertical: 9,
                    horizontal: 4,
                  ),
                  decoration: BoxDecoration(
                    // La superficie y el peso tipográfico indican selección sin verde.
                    color: isSelected
                        ? modelCatalogSurface(context)
                        : colors.surface,
                    borderRadius: BorderRadius.circular(NanoRadius.medium),
                    border: Border.all(
                      color: colors.outlineVariant,
                      width: 0.8,
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Icon(
                            isSelected ? tab.selectedIcon : tab.unselectedIcon,
                            size: 19,
                            color: isSelected
                                ? colors.onSurface
                                : colors.onSurfaceVariant,
                          ),
                          if (countBadge > 0 && !isSelected)
                            Positioned(
                              top: -4,
                              right: -8,
                              child: Container(
                                padding: const EdgeInsets.all(2.5),
                                decoration: BoxDecoration(
                                  color: modelCatalogSurface(context),
                                  shape: BoxShape.circle,
                                ),
                                constraints: const BoxConstraints(
                                  minWidth: 14,
                                  minHeight: 14,
                                ),
                                child: Text(
                                  '$countBadge',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontFamily: 'Inter',
                                    fontSize: 8.5,
                                    fontWeight: FontWeight.w700,
                                    color: colors.onSurface,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        tab.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 11,
                          fontWeight: isSelected
                              ? FontWeight.w700
                              : FontWeight.w500,
                          color: isSelected
                              ? colors.onSurface
                              : colors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  int _getBadgeCount(ModelsCatalogTab tab) => switch (tab) {
    ModelsCatalogTab.instalados => installedCount,
    ModelsCatalogTab.favoritos => favoritesCount,
    ModelsCatalogTab.descargas => downloadsCount,
    _ => 0,
  };
}
