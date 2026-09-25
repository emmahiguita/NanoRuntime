/// NANO-BUSINESS-CATALOG-TAB — Pestaña "Productos" del Agente Comercial.
///
/// QUÉ HACE:
/// Administra el catálogo de productos y servicios: creación, edición
/// de precios, control de stock, eliminación y exportación de catálogo en PDF.
///
/// CÓMO FUNCIONA:
/// - Observa [businessFactsNotifierProvider] y abre [ProductDialog] con useRootNavigator: true.
/// - Detecta si la pantalla está en orientación horizontal (landscape) y compacta
///   los botones de acción en una sola fila para eliminar scroll innecesario.
/// - Si no hay productos, renderiza un estado vacío descriptivo con llamadas a la acción.
///
/// POR QUÉ:
/// Centraliza la fuente de verdad que el LLM y los resolvers consultan para cotizar
/// y verificar disponibilidad, respetando SOLID y el límite de 200 líneas de código.
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
import '../../../../core/widgets/nano_promo_card.dart';

class NanoBusinessCatalogTab extends ConsumerWidget {
  const NanoBusinessCatalogTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final visual = AutomationVisual.of(context);
    final facts = ref.watch(businessFactsNotifierProvider);
    final notifier = ref.read(businessFactsNotifierProvider.notifier);
    final isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;

    return ListView(
      padding: EdgeInsets.fromLTRB(16, 6, 16, isLandscape ? 24 : 90),
      children: [
        // Botones de acción principales (adaptados a horizontal/vertical)
        if (isLandscape && facts.products.isNotEmpty)
          Row(
            children: [
              Expanded(child: _buildAddButton(context, visual, notifier)),
              const SizedBox(width: 8),
              Expanded(child: _buildConnectButton(context, visual)),
              const SizedBox(width: 8),
              Expanded(child: _buildPdfButton(context, facts)),
            ],
          )
        else ...[
          Row(
            children: [
              Expanded(child: _buildAddButton(context, visual, notifier)),
              const SizedBox(width: 8),
              Expanded(child: _buildConnectButton(context, visual)),
            ],
          ),
          if (facts.products.isNotEmpty) ...[
            const SizedBox(height: 8),
            _buildPdfButton(context, facts),
          ],
        ],
        const SizedBox(height: 14),
        if (facts.products.isEmpty)
          Padding(
            padding: EdgeInsets.symmetric(vertical: isLandscape ? 16 : 36),
            child: Column(
              children: [
                Icon(
                  Icons.inventory_2_outlined,
                  size: 40,
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
                  'Agrega tus productos o servicios para que Nano responda precios, descripción y stock.',
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
              final categoryLabel =
                  p.category != null && p.category!.trim().isNotEmpty
                      ? ' [${p.category!.trim()}]'
                      : '';
              final skuLabel =
                  p.sku != null && p.sku!.trim().isNotEmpty ? ' · SKU: ${p.sku!.trim()}' : '';
              final statusPrefix = !p.isAvailable ? '⛔ (Pausado) ' : '';

              return SettingsRow(
                icon: p.isAvailable ? Icons.sell_outlined : Icons.pause_circle_outline_rounded,
                title: '$statusPrefix${p.name}$categoryLabel',
                subtitle: '${p.priceLabel} · $stockLabel$skuLabel$detailLabel',
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
        const SizedBox(height: 12),
        NanoPromoCard(
          title: 'Conexión Continua & Cobros Digitales',
          description:
              'Vincula tu catálogo con hojas en la nube (Excel/Sheets) o añade pasarelas de pago para cobrar directo en WhatsApp.',
          badgeText: 'IMPULSA TU NEGOCIO',
          icon: Icons.trending_up_rounded,
          actionLabel: 'Explorar conectores',
          onActionTap: () => BusinessConnectorsSheet.show(context),
        ),
      ],
    );
  }

  Widget _buildAddButton(
    BuildContext context,
    AutomationVisualPalette visual,
    BusinessFactsNotifier notifier,
  ) {
    return FilledButton.icon(
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
        padding: const EdgeInsets.symmetric(vertical: 9),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Widget _buildConnectButton(BuildContext context, AutomationVisualPalette visual) {
    return OutlinedButton.icon(
      onPressed: () => BusinessConnectorsSheet.show(context),
      icon: const Icon(Icons.hub_rounded, size: 16),
      label: const Text('Conectar datos', style: TextStyle(fontSize: 12)),
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 9),
        side: BorderSide(color: visual.accent.withValues(alpha: 0.6)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Widget _buildPdfButton(BuildContext context, BusinessFacts facts) {
    return FilledButton.tonalIcon(
      onPressed: () => CatalogPdfPreviewDialog.show(context, facts),
      icon: const Icon(Icons.picture_as_pdf_rounded, size: 16),
      label: const Text('Catálogo en PDF', style: TextStyle(fontSize: 12)),
      style: FilledButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 9),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}
