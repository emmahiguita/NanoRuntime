part of 'automation_rules_screen.dart';

/// QUÉ HACE:
/// Tarjeta para la creación de reglas de automatización en lenguaje natural.
///
/// CÓMO FUNCIONA:
/// Captura la entrada de texto del usuario, colapsa saltos de línea en vivo,
/// permite adjuntar archivos multimedia y despacha la acción `onCreate`.
///
/// POR QUÉ:
/// Desacopla la vista de entrada del ciclo de vida de la pantalla principal (SRP),
/// garantizando que el archivo cumpla el límite de < 200 líneas.
class _RuleCreatorCard extends StatelessWidget {
  const _RuleCreatorCard({
    required this.controller,
    required this.error,
    required this.pendingMediaName,
    required this.onCreate,
    required this.onPickMedia,
  });

  final TextEditingController controller;
  final String? error;
  final String? pendingMediaName;
  final VoidCallback onCreate;
  final VoidCallback onPickMedia;

  @override
  Widget build(BuildContext context) {
    final visual = AutomationVisual.of(context);
    final colors = NanoThemeExtension.of(context).colors;

    return AutomationSurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: controller,
            minLines: 1,
            maxLines: 3,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => onCreate(),
            inputFormatters: [
              TextInputFormatter.withFunction((oldValue, newValue) {
                if (!newValue.text.contains('\n')) return newValue;
                final collapsed = newValue.text.replaceAll('\n', ' ');
                return newValue.copyWith(
                  text: collapsed,
                  selection: TextSelection.collapsed(offset: collapsed.length),
                );
              }),
            ],
            style: TextStyle(
              color: visual.text,
              fontSize: 14,
              fontFamily: 'Inter',
            ),
            decoration: InputDecoration(
              hintText: 'Nueva regla… p. ej. «a las 8:30 avísame que es hora»',
              hintStyle: TextStyle(
                color: visual.textMuted.withValues(alpha: 0.7),
                fontSize: 13,
                fontFamily: 'Inter',
              ),
              border: InputBorder.none,
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 4,
                vertical: 6,
              ),
            ),
          ),
          if (pendingMediaName != null) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                Icon(Icons.attach_file_rounded, size: 14, color: visual.accent),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    pendingMediaName!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: visual.accent,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ],
          if (error != null) ...[
            const SizedBox(height: 6),
            Text(
              error!,
              style: TextStyle(color: colors.danger, fontSize: 12),
            ),
          ],
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Escribe en lenguaje natural. Nano detectará la hora, el '
                  'contacto o la condición.',
                  style: TextStyle(
                    color: visual.textMuted,
                    fontSize: 11.5,
                    height: 1.35,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Semantics(
                label: pendingMediaName != null
                    ? 'Cambiar archivo adjunto'
                    : 'Adjuntar archivo para regla WhatsApp',
                child: IconButton(
                  onPressed: onPickMedia,
                  icon: Icon(
                    Icons.attach_file_rounded,
                    color: pendingMediaName != null
                        ? visual.accent
                        : visual.textMuted,
                    size: 20,
                  ),
                  visualDensity: VisualDensity.compact,
                ),
              ),
              const SizedBox(width: 4),
              FilledButton.icon(
                onPressed: onCreate,
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('Crear'),
                style: FilledButton.styleFrom(
                  backgroundColor: visual.accent,
                  foregroundColor: Colors.white,
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
