import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/design_tokens.dart';
import '../../../../core/theme/nano_type.dart';
import 'messaging_channel_sheet.dart';

/// Encabezado principal del Centro de Mensajería con título y botón de conexión.
class MessagingCenterHeader extends ConsumerWidget {
  final VoidCallback? onConnectApp;
  final VoidCallback? onOpenLibrary;

  const MessagingCenterHeader({
    super.key,
    this.onConnectApp,
    this.onOpenLibrary,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = NanoThemeExtension.of(context).colors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accentColor = isDark ? const Color(0xFF00FF88) : colors.primary;
    final canPop = Navigator.of(context).canPop();
    final compact = MediaQuery.sizeOf(context).width < 390;

    return Hero(
      tag: 'nano_messaging_hero',
      child: Material(
        type: MaterialType.transparency,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            if (canPop) ...[
              Semantics(
                label: 'Volver',
                button: true,
                child: IconButton(
                  visualDensity: VisualDensity.compact,
                  icon: Icon(Icons.arrow_back_rounded, color: colors.onSurface),
                  onPressed: () {
                    Navigator.of(context).maybePop();
                  },
                ),
              ),
              const SizedBox(width: 4),
            ],
            // Identidad visual compacta del centro.
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: accentColor.withValues(alpha: isDark ? 0.15 : 0.10),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: accentColor.withValues(alpha: isDark ? 0.35 : 0.40),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: accentColor.withValues(alpha: isDark ? 0.25 : 0.15),
                    blurRadius: 8,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: Center(
                child: Icon(Icons.forum_rounded, color: accentColor, size: 19),
              ),
            ),
            const SizedBox(width: NanoSpacing.sm + 4),
            // Título y subtítulo descriptivo
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          'Centro de Mensajería',
                          overflow: TextOverflow.ellipsis,
                          style: NanoType.title(colors.onSurface).copyWith(
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                            letterSpacing: -0.25,
                          ),
                        ),
                      ),
                      if (!compact) ...[
                        const SizedBox(width: 7),
                        _PrivateStatusPill(color: accentColor),
                      ],
                    ],
                  ),
                  const SizedBox(height: 1),
                  Text(
                    'Conversaciones reales · datos locales',
                    style: NanoType.caption(
                      colors.onSurfaceVariant,
                    ).copyWith(fontSize: 10.5),
                  ),
                ],
              ),
            ),
            const SizedBox(width: NanoSpacing.xs),
            // Acceso directo a PDFs guardados: evita buscarlos en otro módulo.
            if (onOpenLibrary != null)
              IconButton(
                tooltip: 'Biblioteca PDF',
                visualDensity: VisualDensity.compact,
                onPressed: onOpenLibrary,
                icon: Icon(Icons.folder_open_rounded, color: accentColor),
              ),
            // Abre controles reales; en ancho compacto conserva una zona táctil amplia.
            InkWell(
              onTap:
                  onConnectApp ?? () => showMessagingChannelSheet(context, ref),
              customBorder: const CircleBorder(),
              borderRadius: BorderRadius.circular(16),
              child: Container(
                padding: EdgeInsets.symmetric(
                  horizontal: compact ? 9 : 10,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: isDark ? 0.12 : 0.10),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: accentColor.withValues(alpha: isDark ? 0.30 : 0.40),
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.add_rounded, size: 14, color: accentColor),
                    if (!compact) ...[
                      const SizedBox(width: 4),
                      Text(
                        'Canales',
                        style: TextStyle(
                          color: accentColor,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PrivateStatusPill extends StatelessWidget {
  final Color color;
  const _PrivateStatusPill({required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.lock_outline_rounded, size: 8, color: color),
          const SizedBox(width: 3),
          Text(
            'PRIVADO',
            style: TextStyle(
              color: color,
              fontSize: 7.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.35,
            ),
          ),
        ],
      ),
    );
  }
}
