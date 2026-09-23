part of 'personalization_studio_screen.dart';

/// PERSONALIZATION-STUDIO-IMPORTS-TAB — Pestaña de Historial de Lotes Importados.
///
/// **QUÉ HACE:**
/// Lista hasta 100 lotes recientes importados localmente en SQLite, permitiendo auditar
/// los orígenes o retirar registros sin tocar datos manuales previos.
///
/// **CÓMO FUNCIONA:**
/// Despliega metadatos formateados (fecha, total aceptado, archivo original) y opciones
/// seguras para ver el contenido histórico o revocar el lote por completo.
///
/// **POR QUÉ:**
/// Garantiza transparencia total y privacidad sin enviar datos a la nube, manteniendo
/// código modular y estrictamente menor a 200 líneas de código.
class _PersonalizationStudioImportsTab extends StatelessWidget {
  final List<Map> batches;
  final bool canEdit;
  final ValueChanged<Map> onViewOrigin;
  final ValueChanged<Map> onDeleteBatch;
  final Map<dynamic, dynamic> Function(dynamic) metadataParser;
  final String Function(dynamic) dateFormatter;

  const _PersonalizationStudioImportsTab({
    required this.batches,
    required this.canEdit,
    required this.onViewOrigin,
    required this.onDeleteBatch,
    required this.metadataParser,
    required this.dateFormatter,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 90),
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          margin: const EdgeInsets.only(bottom: 6),
          decoration: BoxDecoration(
            color: const Color(0x0CFFFFFF),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0x1FFFFFFF), width: 0.8),
          ),
          child: const Text(
            'Hasta 100 lotes recientes guardados localmente. Retirar un lote elimina solo sus registros importados y su copia de historial sin afectar datos manuales.',
            style: TextStyle(fontSize: 10, color: Colors.white70, height: 1.25),
          ),
        ),
        if (batches.isEmpty)
          const Padding(
            padding: EdgeInsets.all(16),
            child: Center(
              child: Text(
                'Todavía no has aceptado ninguna importación.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 11, color: Colors.grey),
              ),
            ),
          ),
        for (final batch in batches)
          Builder(
            builder: (context) {
              final metadata = metadataParser(batch['metadata']);
              return Card(
                margin: const EdgeInsets.only(bottom: 6),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(9),
                  side: const BorderSide(color: Color(0x22FFFFFF), width: 0.7),
                ),
                color: const Color(0x10FFFFFF),
                child: ListTile(
                  dense: true,
                  title: Text(
                    '${metadata['fileName'] ?? 'Importación'}',
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    '${dateFormatter(batch['atMs'])} · ${metadata['accepted'] ?? 'Cantidad desconocida'} aceptados',
                    style: const TextStyle(fontSize: 9, color: Colors.white60),
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.more_vert_rounded, size: 18),
                    onPressed: !canEdit ? null : () {
                      showModalBottomSheet<void>(
                        context: context,
                        useRootNavigator: true,
                        builder: (ctx) => SafeArea(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              ListTile(
                                dense: true,
                                leading: const Icon(Icons.visibility_outlined),
                                title: const Text('Ver origen'),
                                onTap: () {
                                  Navigator.pop(ctx);
                                  onViewOrigin(batch);
                                },
                              ),
                              ListTile(
                                dense: true,
                                leading: const Icon(Icons.delete_outline, color: Colors.redAccent),
                                title: const Text('Retirar este lote', style: TextStyle(color: Colors.redAccent)),
                                onTap: () {
                                  Navigator.pop(ctx);
                                  onDeleteBatch(batch);
                                },
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              );
            },
          ),
      ],
    );
  }
}
