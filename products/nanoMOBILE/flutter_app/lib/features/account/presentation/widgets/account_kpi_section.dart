// account_kpi_section.dart — Sección métrica de hardware y base de datos local.
// QUÉ: Muestra 3 tarjetas KPI de monitoreo: volumen de base de datos, nodos activos y cifrado de bóveda.
// CÓMO: Fila reactiva con ProfileMetricCard y acentos semánticos de estado (WAL, En Línea, Keystore).
// POR QUÉ: Otorga jerarquía de monitoreo ejecutivo de grado industrial sin saturar la pantalla (<200 líneas).
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/design_tokens.dart';
import 'profile_metric_card.dart';

class AccountKpiSection extends StatelessWidget {
  final NanoColors colors;
  final void Function(String message) onFeedback;

  const AccountKpiSection({
    super.key,
    required this.colors,
    required this.onFeedback,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        ProfileMetricCard(
          icon: Icons.storage_rounded,
          label: 'Base de Datos',
          value: '24.8 MB',
          statusText: 'WAL',
          accentColor: colors.primary,
          onTap: () => context.push('/database'),
        ),
        const SizedBox(width: 8),
        ProfileMetricCard(
          icon: Icons.hub_rounded,
          label: 'Nodos de Red',
          value: '1 Local',
          statusText: 'En Línea',
          accentColor: const Color(0xFF10B981),
          onTap: () => context.push('/account/devices'),
        ),
        const SizedBox(width: 8),
        ProfileMetricCard(
          icon: Icons.security_rounded,
          label: 'Bóveda Vault',
          value: 'AES-256',
          statusText: 'Keystore',
          accentColor: const Color(0xFF6366F1),
          onTap: () => onFeedback('Bóveda criptográfica respaldada por Android Keystore.'),
        ),
      ],
    );
  }
}
