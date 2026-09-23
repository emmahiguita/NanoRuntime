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
import '../connectors/business_connectors_sheet.dart';
import 'catalog_pdf_preview_dialog.dart';
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
        Row(
          children: [
            Expanded(
              child: FilledButton.icon(
                onPressed: () async {
                  final prod = await showDialog<BusinessProduct>(
                    context: context,
                    useRootNavigator: true,
                    builder: (_) => const ProductDialog(),
                  );
                  if (prod != null) notifier.upsertProduct(prod);
                },
                icon: const Icon(Icons.add_shopping_cart_rounded, size: 16),
                label: const Text('Agregar manual', style: TextStyle(fontSize: 12)),
                style: FilledButton.styleFrom(
                  backgroundColor: visual.accent,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => BusinessConnectorsSheet.show(context),
                icon: const Icon(Icons.hub_rounded, size: 16),
                label: const Text('Conectar datos', style: TextStyle(fontSize: 12)),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  side: BorderSide(color: visual.accent.withValues(alpha: 0.6)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
        ),
        if (facts.products.isNotEmpty) ...[
          const SizedBox(height: 8),
          FilledButton.tonalIcon(
            onPressed: () => CatalogPdfPreviewDialog.show(context, facts),
            icon: const Icon(Icons.picture_as_pdf_rounded, size: 16),
            label: const Text('Compartir Catálogo en PDF para WhatsApp', style: TextStyle(fontSize: 12)),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
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
