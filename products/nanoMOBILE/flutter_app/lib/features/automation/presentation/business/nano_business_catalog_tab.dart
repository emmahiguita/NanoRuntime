/// Administra productos reales, stock, edición y exportación PDF.
/// Observa [businessFactsNotifierProvider] para que cada cambio llegue al agente.
/// En horizontal compacta las acciones sin duplicar la lógica del catálogo.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../engine/business/business_facts.dart';
import '../../engine/business/business_facts_providers.dart';
import '../automation_visual_theme.dart';
import '../connectors/business_connectors_sheet.dart';
import 'catalog_pdf_preview_dialog.dart';
import 'business_document_library_dialog.dart';
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
        // Biblioteca persistente: guarda catálogos e importa PDF del teléfono.
        const SizedBox(height: 8),
        // Abre la biblioteca persistente para importar o compartir PDFs.
        OutlinedButton.icon(
          onPressed: () => BusinessDocumentLibraryDialog.show(context, facts),
          icon: const Icon(Icons.folder_open_rounded, size: 16),
          label: const Text('Documentos para compartir'),
        ),
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
              final detailLabel = p.details.trim().isNotEmpty
                  ? ' · ${p.details.trim()}'
                  : '';
              final categoryLabel =
                  p.category != null && p.category!.trim().isNotEmpty
                  ? ' [${p.category!.trim()}]'
                  : '';
              final skuLabel = p.sku != null && p.sku!.trim().isNotEmpty
                  ? ' · SKU: ${p.sku!.trim()}'
                  : '';
              final statusPrefix = !p.isAvailable ? '⛔ (Pausado) ' : '';

              return SettingsRow(
                icon: p.isAvailable
                    ? Icons.sell_outlined
                    : Icons.pause_circle_outline_rounded,
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

  Widget _buildConnectButton(
    BuildContext context,
    AutomationVisualPalette visual,
  ) {
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

  // Abre carpetas Nano para reutilizar PDF y compartirlo con la app elegida.
}
