/// NANO-BUSINESS-CATALOG-TAB — Pestaña "Productos" del Agente Comercial.
///
/// QUÉ HACE:
/// Administra el catálogo de productos y servicios: creación, edición
/// de precios, control de stock y eliminación de artículos.
///
/// CÓMO FUNCIONA:
/// Observa [businessFactsNotifierProvider] y reutiliza [ProductDialog]
/// con useRootNavigator: true, garantizando compatibilidad total y sin duplicar storage.
///
/// POR QUÉ:
/// Es la fuente de verdad que el LLM consulta para cotizar y confirmar
/// disponibilidad en cualquier canal, en un archivo menor a 200 líneas.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../engine/business/business_facts.dart';
import '../../engine/business/business_facts_providers.dart';
import '../automation_visual_theme.dart';
import '../widgets/dialogs/product_dialog.dart';
import '../widgets/settings_tile_components.dart';

class NanoBusinessCatalogTab extends ConsumerWidget {
  const NanoBusinessCatalogTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final visual = AutomationVisual.of(context);
    final facts = ref.watch(businessFactsNotifierProvider);
    final notifier = ref.read(businessFactsNotifierProvider.notifier);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
      children: [
        FilledButton.icon(
          onPressed: () async {
            final prod = await showDialog<BusinessProduct>(
              context: context,
              useRootNavigator: true,
              builder: (_) => const ProductDialog(),
            );
            if (prod != null) notifier.upsertProduct(prod);
          },
          icon: const Icon(Icons.add_shopping_cart_rounded, size: 18),
          label: const Text('Agregar producto o servicio'),
          style: FilledButton.styleFrom(
            backgroundColor: visual.accent,
            foregroundColor: Colors.black,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        const SizedBox(height: 16),
        if (facts.products.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 40),
            child: Column(
              children: [
                Icon(
                  Icons.inventory_2_outlined,
                  size: 44,
                  color: visual.textMuted.withValues(alpha: 0.5),
                ),
                const SizedBox(height: 8),
                Text(
                  'Sin productos en el catálogo',
                  style: TextStyle(
                    color: visual.text,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Agrega tus productos para que Nano responda precios, descripción y stock a tus clientes.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: visual.textMuted, fontSize: 12),
                ),
              ],
            ),
          )
        else
          SettingsCard(
            children: facts.products.map((p) {
              final stockLabel = p.stock != null
                  ? (p.stock! > 0 ? '${p.stock} en stock' : 'Agotado')
                  : 'Stock flexible';
              final detailLabel =
                  p.details.trim().isNotEmpty ? ' · ${p.details.trim()}' : '';

              return SettingsRow(
                icon: Icons.sell_outlined,
                title: p.name,
                subtitle: '${p.priceLabel} · $stockLabel$detailLabel',
                trailing: IconButton(
                  icon: const Icon(Icons.close_rounded, size: 18),
                  color: visual.textMuted,
                  onPressed: () => notifier.removeProduct(p.id),
                ),
                showChevron: false,
                onTap: () async {
                  final updated = await showDialog<BusinessProduct>(
                    context: context,
                    useRootNavigator: true,
                    builder: (_) => ProductDialog(initial: p),
                  );
                  if (updated != null) notifier.upsertProduct(updated);
                },
              );
            }).toList(),
          ),
      ],
    );
  }
}
