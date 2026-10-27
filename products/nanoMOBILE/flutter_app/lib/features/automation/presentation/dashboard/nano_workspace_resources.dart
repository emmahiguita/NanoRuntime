import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../engine/business/business_facts_providers.dart';
import '../business/business_document_library_dialog.dart';
import '../business/business_library_section_tabs.dart';
import 'dashboard_action_card.dart';

/// Entradas compartidas por Inicio y Nano Personal al MISMO almacén existente.
/// Biblioteca conserva archivos; Tienda edita el catálogo de Nano Negocio.
/// Abrirlas no adjunta documentos a contactos ni concede permisos de envío.
class NanoWorkspaceResources extends ConsumerStatefulWidget {
  const NanoWorkspaceResources({super.key});
  @override
  ConsumerState<NanoWorkspaceResources> createState() => _ResourcesState();
}

class _ResourcesState extends ConsumerState<NanoWorkspaceResources> {
  bool _opening = false;

  /// Espera la hidratación del catálogo antes de abrirlo para evitar datos vacíos
  /// de arranque. El guard impide dos modales al pulsar rápidamente.
  Future<void> _open(BusinessLibrarySection section) async {
    if (_opening) return;
    setState(() => _opening = true);
    try {
      await ref.read(businessFactsNotifierProvider.notifier).ready;
      if (!mounted) return;
      await BusinessDocumentLibraryDialog.show(
        context,
        ref.read(businessFactsNotifierProvider),
        initialSection: section,
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo abrir. Intenta de nuevo.')),
        );
      }
    } finally {
      if (mounted) setState(() => _opening = false);
    }
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      DashboardActionCard(
        title: 'Biblioteca',
        subtitle: 'Archivos, carpetas y documentos para compartir.',
        icon: Icons.folder_outlined,
        onTap: _opening ? null : () => _open(BusinessLibrarySection.documents),
      ),
      const SizedBox(height: 10),
      DashboardActionCard(
        title: 'Tienda',
        subtitle: 'Productos, precios y stock de Nano Negocio.',
        icon: Icons.storefront_outlined,
        onTap: _opening ? null : () => _open(BusinessLibrarySection.store),
      ),
      if (_opening) const LinearProgressIndicator(minHeight: 2),
    ],
  );
}
