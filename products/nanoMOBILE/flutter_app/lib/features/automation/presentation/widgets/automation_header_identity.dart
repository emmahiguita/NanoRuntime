// QUÉ: identidad Nano y selector del nivel de autonomía existente.
// CÓMO: usa el búho propio y un selector de ancho intrínseco, con texto adaptable.
// POR QUÉ: «Asistido» debe verse como una elección, sin estirarse en horizontal.
import 'package:flutter/material.dart';
import '../../domain/automation_policy.dart';
import '../../../../core/widgets/navigation/nano_glyph.dart';

class AutomationHeaderIdentity extends StatelessWidget {
  const AutomationHeaderIdentity({
    super.key,
    required this.mode,
    required this.onModeTap,
    required this.running,
  });
  final AgentAutomationMode mode;
  final VoidCallback onModeTap;
  final bool running;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        // Es marca, no botón: no se anuncia como una acción inexistente.
        Semantics(
          image: true,
          label: running ? 'Nano AI, ejecución en curso' : 'Nano AI',
          child: Image.asset(
            'assets/nano/nano_owl.png',
            width: 36,
            height: 36,
            cacheWidth: (36 * MediaQuery.devicePixelRatioOf(context)).ceil(),
            excludeFromSemantics: true,
          ),
        ),
        const SizedBox(width: 9),
        Expanded(
          child: Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 12,
            runSpacing: 2,
            children: [
              Text(
                'NANO AI',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: scheme.onSurface,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Semantics(
                button: true,
                label: 'Nivel de autonomía: ${mode.label}. Cambiar nivel',
                excludeSemantics: true,
                child: Material(
                  color: scheme.surfaceContainerHigh.withValues(alpha: .65),
                  shape: StadiumBorder(
                    side: BorderSide(color: scheme.outlineVariant),
                  ),
                  child: InkWell(
                    onTap: onModeTap,
                    customBorder: const StadiumBorder(),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(minHeight: 40),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Flexible(
                              child: Text(
                                mode.label,
                                style: Theme.of(context).textTheme.labelMedium,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 5),
                            NanoGlyph(
                              type: NanoGlyphType.chevronDown,
                              size: 13,
                              color: scheme.onSurfaceVariant,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
