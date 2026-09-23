import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/design_tokens.dart';
import '../../../../core/theme/nano_type.dart';
import 'messaging_channel_sheet.dart';

/// Encabezado principal del Centro de Mensajería con título y botón de conexión.
class MessagingCenterHeader extends ConsumerWidget {
  final VoidCallback? onConnectApp;

  const MessagingCenterHeader({super.key, this.onConnectApp});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = NanoThemeExtension.of(context).colors;
    final canPop = Navigator.of(context).canPop();
    final compact = MediaQuery.sizeOf(context).width < 390;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        if (canPop) ...[
          Semantics(
            label: 'Volver',
            button: true,
            child: IconButton(
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
              onPressed: () {
                Navigator.of(context).maybePop();
              },
            ),
          ),
          const SizedBox(width: 4),
        ],
        // Icono principal estilizado con resplandor verde original (#00FF88)
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: const Color(0xFF00FF88).withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: const Color(0xFF00FF88).withValues(alpha: 0.35),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF00FF88).withValues(alpha: 0.25),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: const Center(
            child: Icon(Icons.forum_rounded, color: Color(0xFF00FF88), size: 22),
          ),
        ),
        const SizedBox(width: NanoSpacing.sm + 4),
        // Título y subtítulo descriptivo
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Centro de Mensajería',
                style: NanoType.title(
                  colors.onSurface,
                ).copyWith(fontWeight: FontWeight.w800, fontSize: 18, letterSpacing: -0.3),
              ),
              const SizedBox(height: 1),
              Text(
                'Gestión multicanal activa y privada',
                style: NanoType.caption(colors.onSurfaceVariant).copyWith(fontSize: 11.5),
              ),
            ],
          ),
        ),
        const SizedBox(width: NanoSpacing.xs),
        // Abre controles reales; en ancho compacto conserva una zona táctil amplia.
        InkWell(
          onTap: onConnectApp ?? () => showMessagingChannelSheet(context, ref),
          customBorder: const CircleBorder(),
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: compact ? 9 : 10, vertical: 7),
            decoration: BoxDecoration(
              color: const Color(0xFF00FF88).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: const Color(0xFF00FF88).withValues(alpha: 0.30),
                width: 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.add_rounded, size: 14, color: Color(0xFF00FF88)),
                if (!compact) ...[
                  const SizedBox(width: 4),
                  const Text(
                    'Canales',
                    style: TextStyle(
                      color: Color(0xFF00FF88),
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
    );
  }
}
