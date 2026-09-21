import 'package:flutter/material.dart';
import '../../../../core/theme/design_tokens.dart';
import '../../../../core/theme/nano_type.dart';
import '../../../../core/widgets/nano_components.dart';
import '../../../../core/widgets/nano_owl_avatar.dart';


/// QUÉ HACE:
/// Banner sutil de apoyo y contribución voluntaria para Nano Mobile.
///
/// CÓMO FUNCIONA:
/// Soporta modos compacto y expandido, integrando al búho Nano en reposo (idle).
/// Ofrece acción para apoyar el desarrollo y acción de descarte respetuoso ("Ahora no").
///
/// POR QUÉ:
/// Cumple la regla 14 y 35: cero popups agresivos ni dark patterns.
/// Frecuencia controlada por cooldown y persistencia local.
class NanoSupportBanner extends StatefulWidget {
  final VoidCallback onSupportTap;
  final VoidCallback onDismissTap;
  final bool initiallyExpanded;

  const NanoSupportBanner({
    super.key,
    required this.onSupportTap,
    required this.onDismissTap,
    this.initiallyExpanded = false,
  });

  @override
  State<NanoSupportBanner> createState() => _NanoSupportBannerState();
}

class _NanoSupportBannerState extends State<NanoSupportBanner> {
  late bool _expanded;

  @override
  void initState() {
    super.initState();
    _expanded = widget.initiallyExpanded;
  }

  @override
  Widget build(BuildContext context) {
    final colors = NanoThemeExtension.of(context).colors;

    return NanoOpticalSurface(
      borderRadius: NanoRadius.large,
      margin: const EdgeInsets.symmetric(vertical: NanoSpacing.sm),
      padding: const EdgeInsets.all(NanoSpacing.md),
      child: AnimatedCrossFade(
        duration: const Duration(milliseconds: 250),
        crossFadeState:
            _expanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
        firstChild: _buildCompact(colors),
        secondChild: _buildExpanded(colors),
      ),
    );
  }

  Widget _buildCompact(NanoColors colors) {
    return InkWell(
      onTap: () => setState(() => _expanded = true),
      borderRadius: BorderRadius.circular(NanoRadius.medium),
      child: Row(
        children: [
          const NanoOwlAvatar(size: 28, state: NanoOwlState.idle),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '¿Nano te está siendo útil?',
              style: NanoType.body(colors.onSurface),
            ),
          ),
          Text(
            'Apoyar →',
            style: NanoType.label(colors.primary),
          ),
        ],
      ),
    );
  }

  Widget _buildExpanded(NanoColors colors) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const NanoOwlAvatar(size: 34, state: NanoOwlState.idle),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Ayuda a que Nano siga creciendo',
                    style: NanoType.title(colors.onSurface),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Si Nano te es útil, puedes apoyar su desarrollo.',
                    style: NanoType.caption(colors.onSurfaceVariant),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: NanoSpacing.md),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            TextButton(
              onPressed: widget.onDismissTap,
              child: Text('Ahora no', style: NanoType.caption(colors.onSurfaceVariant)),
            ),
            const SizedBox(width: 8),
            NanoActionButton(
              label: 'Apoyar Nano',
              primary: true,
              icon: Icons.favorite_rounded,
              onPressed: widget.onSupportTap,
            ),
          ],
        ),
      ],
    );
  }
}
