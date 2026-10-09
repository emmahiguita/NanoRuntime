import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/design_tokens.dart';
import 'profile_metric_card.dart';

/// Sección de miniaturas KPI estilo iOS Glass para perfil profesional completo.
class AccountKpiSection extends StatelessWidget {
  final NanoColors colors;
  final void Function(String message)? onFeedback;

  const AccountKpiSection({
    super.key,
    required this.colors,
    this.onFeedback,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ProfileMetricCard(
                icon: Icons.shield_rounded,
                label: 'Bóveda Vault',
                value: 'AES-256',
                statusText: 'Keystore',
                accentColor: const Color(0xFF6366F1),
                onTap: () => onFeedback?.call('Bóveda criptográfica respaldada por Android Keystore.'),
              ),
              const SizedBox(width: 8),
              ProfileMetricCard(
                icon: Icons.storage_rounded,
                label: 'Base de Datos',
                value: 'Local WAL',
                statusText: 'SQLite',
                accentColor: colors.primary,
                onTap: () {
                  if (context.canPop()) {
                    // Feedback si se presiona
                    onFeedback?.call('Base de datos SQLite local activa.');
                  }
                },
              ),
              const SizedBox(width: 8),
              ProfileMetricCard(
                icon: Icons.hub_rounded,
                label: 'Nodo Local',
                value: 'Activo',
                statusText: 'En Línea',
                accentColor: const Color(0xFF10B981),
                onTap: () => context.push('/account/devices'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
