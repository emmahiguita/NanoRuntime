// business_store_empty_state.dart
//
// QUÉ HACE:
// Vista de estado vacío para la pestaña Tienda / Catálogo en la Biblioteca.
// Muestra mensajes contextuales cuando no hay productos creados o tras una búsqueda sin resultados.
//
// CÓMO FUNCIONA:
// - Detecta si el estado vacío proviene de un filtro de búsqueda o de un catálogo sin productos.
// - Presenta un botón de acción principal estilo iOS para añadir el primer producto o limpiar filtros.
//
// POR QUÉ:
// Aplica SOLID (SRP) aislando la vista de estado vacío en un componente reutilizable de < 100 líneas.

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class BusinessStoreEmptyState extends StatelessWidget {
  final bool isSearchOrFilter;
  final VoidCallback onAction;

  const BusinessStoreEmptyState({super.key, required this.isSearchOrFilter, required this.onAction});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 36),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Contenedor circular estilo iOS con gradiente sutil
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    colors.primaryContainer.withValues(alpha: .5),
                    colors.surface.withValues(alpha: .3),
                  ],
                ),
                border: Border.all(color: colors.outlineVariant),
              ),
              child: Icon(
                isSearchOrFilter ? CupertinoIcons.search : CupertinoIcons.bag_badge_plus,
                size: 34,
                color: colors.primary,
              ),
            ),
            const SizedBox(height: 16),
            // Título principal informativo
            Text(
              isSearchOrFilter ? 'Sin coincidencias' : 'Catálogo de tienda vacío',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: colors.onSurface,
                fontSize: 16,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 6),
            // Descripción secundaria explicativa
            Text(
              isSearchOrFilter
                  ? 'No se encontraron productos con los filtros o búsqueda actuales.'
                  : 'Agrega productos y servicios para que el agente de ventas y la tienda muestren precios, fotos y stock.',
              textAlign: TextAlign.center,
              style: TextStyle(color: colors.onSurfaceVariant, fontSize: 12.5, height: 1.35),
            ),
            const SizedBox(height: 18),
            // Botón de acción iOS (Agregar producto o limpiar búsqueda)
            CupertinoButton(
              onPressed: onAction,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              color: colors.primary,
              borderRadius: BorderRadius.circular(12),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isSearchOrFilter ? CupertinoIcons.clear_circled : CupertinoIcons.plus_circle_fill,
                    size: 16,
                    color: colors.onPrimary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    isSearchOrFilter ? 'Restablecer filtros' : 'Nuevo producto',
                    style: TextStyle(color: colors.onPrimary, fontSize: 13, fontWeight: FontWeight.w600),
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
