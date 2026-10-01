// payment_methods_guided_view.dart
//
// QUÉ HACE:
// Vista de formulario guiado con Material Expressive 3 para configurar métodos de pago.
//
// CÓMO FUNCIONA:
// - Despliega tarjetas colapsables/activables por método (Transferencia, Billetera, Link, Contra entrega, QR).
// - Provee campos con espaciado ergonómico optimizado para modo horizontal y vertical.
// - Evita llamadas a Overlay.of(context) en tooltips usando Semantics accesible.
//
// POR QUÉ:
// Mantiene el código desacoplado (SOLID - SRP) con menos de 200 líneas y navegación táctil intuitiva.

import 'package:flutter/material.dart';
import 'package:nanoai/features/automation/presentation/automation_visual_theme.dart';
import 'payment_method_card.dart';
import 'payment_methods_models.dart';

class PaymentMethodsGuidedView extends StatelessWidget {
  final PaymentMethodsData data;
  final VoidCallback onChanged;

  const PaymentMethodsGuidedView({
    super.key,
    required this.data,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final visual = AutomationVisual.of(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PaymentMethodCard(
            visual: visual,
            title: 'Transferencia Bancaria',
            icon: Icons.account_balance_rounded,
            enabled: data.hasTransfer,
            onToggle: (v) {
              data.hasTransfer = v;
              onChanged();
            },
            fields: [
              PaymentMethodField(
                visual,
                'Banco',
                data.bankName,
                (v) => data.bankName = v,
                hint: 'Ej. Bancolombia',
              ),
              PaymentMethodField(
                visual,
                'Tipo',
                data.accountType,
                (v) => data.accountType = v,
                hint: 'Ahorros / Corriente',
              ),
              PaymentMethodField(
                visual,
                'Número de cuenta',
                data.accountNumber,
                (v) => data.accountNumber = v,
                hint: 'Ej. 123-456789-01',
              ),
              PaymentMethodField(
                visual,
                'Titular',
                data.accountHolder,
                (v) => data.accountHolder = v,
                hint: 'Nombre o Razón Social',
              ),
              PaymentMethodField(
                visual,
                'CC / NIT',
                data.accountDoc,
                (v) => data.accountDoc = v,
                hint: 'Opcional para transferencias',
              ),
            ],
          ),
          const SizedBox(height: 10),
          PaymentMethodCard(
            visual: visual,
            title: 'Billetera Móvil (Nequi / Daviplata)',
            icon: Icons.phone_android_rounded,
            enabled: data.hasWallet,
            onToggle: (v) {
              data.hasWallet = v;
              onChanged();
            },
            fields: [
              PaymentMethodField(
                visual,
                'Billetera',
                data.walletName,
                (v) => data.walletName = v,
                hint: 'Nequi / Daviplata / Dale',
              ),
              PaymentMethodField(
                visual,
                'Número de celular',
                data.walletNumber,
                (v) => data.walletNumber = v,
                hint: 'Ej. 300 123 4567',
              ),
            ],
          ),
          const SizedBox(height: 10),
          PaymentMethodCard(
            visual: visual,
            title: 'Enlace de Pago (Wompi / PSE / Bold)',
            icon: Icons.link_rounded,
            enabled: data.hasLink,
            onToggle: (v) {
              data.hasLink = v;
              onChanged();
            },
            fields: [
              PaymentMethodField(
                visual,
                'Pasarela',
                data.linkProvider,
                (v) => data.linkProvider = v,
                hint: 'Wompi / PSE / Bold',
              ),
              PaymentMethodField(
                visual,
                'Enlace URL',
                data.linkUrl,
                (v) => data.linkUrl = v,
                hint: 'https://checkout...',
              ),
            ],
          ),
          const SizedBox(height: 10),
          PaymentMethodCard(
            visual: visual,
            title: 'Contra entrega y QR',
            icon: Icons.local_shipping_outlined,
            enabled: data.hasCod || data.hasQr,
            onToggle: (v) {
              data.hasCod = v;
              data.hasQr = v;
              onChanged();
            },
            fields: [
              PaymentMethodField(
                visual,
                'Política contra entrega',
                data.codNotes,
                (v) => data.codNotes = v,
                hint: 'Efectivo al recibir',
              ),
              PaymentMethodField(
                visual,
                'Instrucción QR',
                data.qrNotes,
                (v) => data.qrNotes = v,
                hint: 'Solicita QR por este chat',
              ),
            ],
          ),
          const SizedBox(height: 10),
          SwitchListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            value: data.requireHumanVerify,
            activeThumbColor: visual.accent,
            title: Text(
              'Pedir comprobante al cliente',
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: visual.text,
              ),
            ),
            subtitle: Text(
              'Instruye enviar comprobante de pago para validar la compra.',
              style: TextStyle(fontSize: 10.5, color: visual.textMuted),
            ),
            onChanged: (v) {
              data.requireHumanVerify = v;
              onChanged();
            },
          ),
        ],
      ),
    );
  }
}
