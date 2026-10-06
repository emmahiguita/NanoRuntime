// model_new_badge_banner.dart — Banner informativo Material 3 Expressive para el catálogo.
//
// QUÉ HACE:
// Notifica al usuario de nuevos modelos curados instalables en el dispositivo (Gemma, Qwen,
// Qwen Omni, Whisper o importación GGUF) que aún no han sido vistos ni instalados.
//
// CÓMO FUNCIONA:
// 1. Lee SharedPreferences (`nano_seen_model_ids_v1`) para filtrar los modelos no vistos.
// 2. Se adapta fluidamente entre modo vertical y horizontal (landscape) ajustando paddings y escala.
// 3. Aplica Material 3 Expressive usando los tokens de color del tema (Theme.of(context)),
//    eliminando colores ámbar fijos y tipografías desalineadas.
//
// POR QUÉ:
// Mantiene consistencia visual con el sistema de diseño, evita elementos rígidos que
// ocupen demasiado espacio vertical en landscape y comunica con precisión los motores disponibles.

library;

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/theme/design_tokens.dart';
import '../../domain/local_model.dart';

class ModelNewBadgeBanner extends StatefulWidget {
  final List<LocalModel> models;

  const ModelNewBadgeBanner({super.key, required this.models});

  @override
  State<ModelNewBadgeBanner> createState() => _ModelNewBadgeBannerState();
}

class _ModelNewBadgeBannerState extends State<ModelNewBadgeBanner> {
  List<String> _newModelIds = [];
  bool _dismissed = false;

  static const _seenKey = 'nano_seen_model_ids_v1';

  @override
  void initState() {
    super.initState();
    _computeNew();
  }

  @override
  void didUpdateWidget(covariant ModelNewBadgeBanner oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.models.length != widget.models.length) {
      _computeNew();
    }
  }

  // QUÉ HACE: Calcula modelos pendientes de ver sin requerir conectividad de red.
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

  // QUÉ HACE: Guarda en storage local que el usuario ya cerró este aviso.
  Future<void> _dismiss() async {
    final prefs = await SharedPreferences.getInstance();
    final seen = prefs.getStringList(_seenKey) ?? [];
    seen.addAll(_newModelIds);
    await prefs.setStringList(_seenKey, seen.toSet().toList());
    if (mounted) setState(() => _dismissed = true);
  }

  @override
  Widget build(BuildContext context) {
    if (_dismissed || _newModelIds.isEmpty) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;
    final count = _newModelIds.length;

    // QUÉ HACE: Contenedor con Material Expressive adaptable a vertical/horizontal.
    return Container(
      margin: EdgeInsets.only(
        bottom: isLandscape ? NanoSpacing.xs : NanoSpacing.sm,
      ),
      padding: EdgeInsets.symmetric(
        horizontal: isLandscape ? 12 : 14,
        vertical: isLandscape ? 6 : 10,
      ),
      decoration: BoxDecoration(
        color: colorScheme.secondaryContainer.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(NanoRadius.medium),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.35),
          width: 0.8,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(
            Icons.auto_awesome_rounded,
            size: isLandscape ? 18 : 22,
            color: colorScheme.primary,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  count == 1
                      ? '1 modelo disponible para instalar'
                      : '$count modelos disponibles para instalar',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    fontSize: isLandscape ? 11.5 : 12.5,
                    color: colorScheme.onSurface,
                  ),
                ),
                Text(
                  'Catálogo curado para tu móvil: Gemma (LiteRT), Qwen, Qwen Omni (MNN), Whisper (Voz) e importación GGUF externa.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontSize: isLandscape ? 10.0 : 11.0,
                    color: colorScheme.onSurfaceVariant,
                  ),
                  maxLines: isLandscape ? 1 : 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            tooltip: 'Cerrar aviso',
            icon: Icon(
              Icons.close_rounded,
              size: isLandscape ? 16 : 18,
              color: colorScheme.onSurfaceVariant,
            ),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            onPressed: _dismiss,
          ),
        ],
      ),
    );
  }
}
