/// NANO-BUSINESS-PAYMENTS-TAB — Pestaña "Pagos" del Agente Comercial.
///
/// QUÉ HACE:
/// Configura los medios de pago que el agente informa a los clientes
/// (Bancolombia, Nequi, Daviplata, transferencias, efectivo local).
///
/// CÓMO FUNCIONA:
/// Integra con [PaymentMethodsDialog] y [businessFactsNotifierProvider],
/// permitiendo habilitar métodos y guardar instrucciones de pago.
///
/// POR QUÉ:
/// Garantiza que el bot entregue los datos exactos de cobro cuando
/// un cliente solicita cerrar una compra, en un archivo menor a 200 líneas.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../engine/business/business_facts_providers.dart';
import '../automation_visual_theme.dart';
import '../widgets/dialogs/payment_methods_dialog.dart';
import '../widgets/settings_tile_components.dart';

class NanoBusinessPaymentsTab extends ConsumerWidget {
  const NanoBusinessPaymentsTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final visual = AutomationVisual.of(context);
    final facts = ref.watch(businessFactsNotifierProvider);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: visual.surface.withValues(alpha: 0.50),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: visual.outline.withValues(alpha: 0.18)),
          ),
          child: Text(
            'Nano comparte estos métodos cuando un cliente pregunta cómo pagar o desea confirmar un pedido.',
            style: TextStyle(color: visual.textMuted, fontSize: 12),
          ),
        ),
        const SizedBox(height: 16),
        const AutomationSectionLabel('Medios de Pago Configurados'),
        SettingsCard(
          children: [
            SettingsRow(
              icon: Icons.account_balance_wallet_outlined,
              title: 'Métodos y transferencias',
              subtitle: facts.payments.trim().isNotEmpty
                  ? facts.payments.trim()
                  : 'Sin métodos de pago configurados — Toca para editar',
              onTap: () async {
                final text = await showDialog<String>(
                  context: context,
                  useRootNavigator: true,
                  builder: (_) => PaymentMethodsDialog(
                    initial: facts.payments,
                  ),
                );
                if (text != null) {
                  ref.read(businessFactsNotifierProvider.notifier).setPayments(text);
                }
              },
            ),
          ],
        ),
      ],
    );
  }
}
