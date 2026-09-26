// model_new_badge_banner.dart — Banner de notificación de nuevo modelo open-source.
// QUÉ HACE: Muestra un aviso cuando hay modelos nuevos en el catálogo no instalados ni vistos.
// CÓMO FUNCIONA: Lee SharedPreferences para saber qué modelos ya vio el usuario; calcula nuevos.
// POR QUÉ: Permite notificar en la pantalla de Modelos sin depender de push notifications externas.
library;

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/theme/design_tokens.dart';
import '../../domain/local_model.dart';

/// Widget que notifica modelos nuevos no vistos desde el último lanzamiento.
class ModelNewBadgeBanner extends StatefulWidget {
  // Lista de modelos del catálogo para calcular cuáles son nuevos.
  final List<LocalModel> models;

  const ModelNewBadgeBanner({super.key, required this.models});

  @override
  State<ModelNewBadgeBanner> createState() => _ModelNewBadgeBannerState();
}

class _ModelNewBadgeBannerState extends State<ModelNewBadgeBanner> {
  // QUÉ HACE: IDs de modelos nuevos no vistos por el usuario.
  List<String> _newModelIds = [];
  bool _dismissed = false;

  // Clave para persistir los modelos ya vistos.
  static const _seenKey = 'nano_seen_model_ids_v1';

  @override
  void initState() {
    super.initState();
    _computeNew();
  }

  // QUÉ HACE: Detecta cuando el catálogo cambia (por scan o actualización) y recalcula.
  // POR QUÉ: Permite que el banner reaccione inmediatamente tras refrescar la lista.
  @override
  void didUpdateWidget(covariant ModelNewBadgeBanner oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.models.length != widget.models.length) {
      _computeNew();
    }
  }

  // QUÉ HACE: Compara catálogo actual contra IDs ya vistos en SharedPreferences.
  // CÓMO FUNCIONA: Lee lista guardada → diff con catálogo actual → muestra los nuevos.
  // POR QUÉ: Sin red ni APIs — funciona offline; se actualiza cuando el catálogo crece.
  Future<void> _computeNew() async {
    final prefs = await SharedPreferences.getInstance();
    final seen = prefs.getStringList(_seenKey) ?? [];
    final newIds = widget.models
        .where((m) => !seen.contains(m.id) && !m.installed)
        .map((m) => m.id)
        .toList();
    if (!mounted) return;
    setState(() => _newModelIds = newIds);
  }

  // QUÉ HACE: Marca los modelos nuevos como vistos y cierra el banner.
  Future<void> _dismiss() async {
    final prefs = await SharedPreferences.getInstance();
    final seen = prefs.getStringList(_seenKey) ?? [];
    seen.addAll(_newModelIds);
    await prefs.setStringList(_seenKey, seen.toSet().toList());
    if (mounted) setState(() => _dismissed = true);
  }

  @override
  Widget build(BuildContext context) {
    // No mostrar si no hay modelos nuevos o el usuario ya lo cerró.
    if (_dismissed || _newModelIds.isEmpty) return const SizedBox.shrink();
    final colors = NanoThemeExtension.of(context).colors;
    final count = _newModelIds.length;

    return Container(
      margin: const EdgeInsets.only(bottom: NanoSpacing.sm),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF59E0B).withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(NanoRadius.medium),
        border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.35), width: 0.8),
      ),
      child: Row(children: [
        const Text('✨', style: TextStyle(fontSize: 20)),
        const SizedBox(width: 10),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              count == 1
                  ? '1 modelo nuevo disponible'
                  : '$count modelos nuevos disponibles',
              style: const TextStyle(
                fontFamily: 'Inter', fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white,
              ),
            ),
            Text(
              'Modelos open-source pequeños para móvil añadidos al catálogo.',
              style: TextStyle(
                fontFamily: 'Inter', fontSize: 10.5, color: colors.onSurfaceVariant,
              ),
            ),
          ],
        )),
        const SizedBox(width: 8),
        // Botón para cerrar el banner y marcar como visto.
        GestureDetector(
          onTap: _dismiss,
          child: Icon(Icons.close_rounded, size: 18, color: colors.onSurfaceVariant),
        ),
      ]),
    );
  }
}
