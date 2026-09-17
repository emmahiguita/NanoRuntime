import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/design_tokens.dart';
import '../../../../core/theme/nano_type.dart';
import '../../executors/notification_executor_provider.dart';

/// Encabezado principal del Centro de Mensajería con título y botón de conexión.
class MessagingCenterHeader extends ConsumerWidget {
  final VoidCallback? onConnectApp;

  const MessagingCenterHeader({super.key, this.onConnectApp});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = NanoThemeExtension.of(context).colors;

    final canPop = Navigator.of(context).canPop();

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        if (canPop) ...[
          IconButton(
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
            tooltip: 'Volver',
            onPressed: () {
              Navigator.of(context).maybePop();
            },
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
            child: Icon(
              Icons.forum_rounded,
              color: Color(0xFF00FF88),
              size: 22,
            ),
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
                style: NanoType.title(colors.onSurface).copyWith(
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 1),
              Text(
                'Gestión multicanal activa y privada',
                style: NanoType.caption(colors.onSurfaceVariant).copyWith(
                  fontSize: 11.5,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: NanoSpacing.xs),
        // Botón "+ Conectar App"
        InkWell(
          onTap: onConnectApp ?? () => _showConnectAppsDialog(context, ref),
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFF00FF88).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: const Color(0xFF00FF88).withValues(alpha: 0.30),
                width: 1,
              ),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.add_rounded,
                  size: 14,
                  color: Color(0xFF00FF88),
                ),
                SizedBox(width: 4),
                Text(
                  'Conectar',
                  style: TextStyle(
                    color: Color(0xFF00FF88),
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _showConnectAppsDialog(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0F172A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.all(NanoSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.hub_rounded, color: Color(0xFF00A3FF)),
                  const SizedBox(width: 8),
                  const Text(
                    'Gestión de Canales y Permisos',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white70),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Text(
                'NanoAI escucha y responde a través del Listener de Notificaciones de Android. Las respuestas automáticas se envían de forma nativa sin modificar las aplicaciones.',
                style: TextStyle(color: Colors.white70, fontSize: 13),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () async {
                    Navigator.pop(ctx);
                    await ref.read(notificationExecutorProvider).requestAccess();
                  },
                  icon: const Icon(Icons.security_rounded),
                  label: const Text('Configurar Permisos de Android'),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF00A3FF),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        );
      },
    );
  }
}
