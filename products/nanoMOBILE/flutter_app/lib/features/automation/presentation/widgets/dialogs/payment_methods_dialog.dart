// payment_methods_dialog.dart
//
// QUÉ HACE:
// Diálogo principal con Material Expressive 3 para configurar los métodos de pago comerciales.
//
// CÓMO FUNCIONA:
// - Integra DialogContainerShell para adaptación ergonómica a modo horizontal y vertical sin overflow.
// - Conmuta con un toque entre vista guiada estructurada (PaymentMethodsGuidedView) y edición en texto libre.
// - Utiliza Semantics en lugar de Tooltip para garantizar cero fallos de 'No Overlay'.
//
// POR QUÉ:
// Aplica SOLID (SRP/DIP), descomponiendo la lógica en submódulos especializados (< 150 líneas).

import 'package:flutter/material.dart';
import 'package:nanoai/features/automation/presentation/automation_visual_theme.dart';
import 'dialog_container_shell.dart';
import 'payment_methods_guided_view.dart';
import 'payment_methods_models.dart';

class PaymentMethodsDialog extends StatefulWidget {
  final String initial;

  const PaymentMethodsDialog({super.key, required this.initial});

  @override
  State<PaymentMethodsDialog> createState() => _PaymentMethodsDialogState();
}

class _PaymentMethodsDialogState extends State<PaymentMethodsDialog> {
  late final PaymentMethodsData _data;
  late final TextEditingController _rawController;
  bool _isRawMode = false;

  @override
  void initState() {
    super.initState();
    _data = PaymentMethodsData.fromText(widget.initial);
    _rawController = TextEditingController(text: widget.initial);
  }

  @override
  void dispose() {
    _rawController.dispose();
    super.dispose();
  }

  void _toggleMode() {
    if (!_isRawMode) {
      _rawController.text = _data.toConsolidatedText();
    } else {
      final updated = PaymentMethodsData.fromText(_rawController.text);
      _data.hasTransfer = updated.hasTransfer;
      _data.bankName = updated.bankName;
      _data.accountType = updated.accountType;
      _data.accountNumber = updated.accountNumber;
      _data.accountHolder = updated.accountHolder;
      _data.accountDoc = updated.accountDoc;
      _data.hasWallet = updated.hasWallet;
      _data.walletName = updated.walletName;
      _data.walletNumber = updated.walletNumber;
      _data.hasLink = updated.hasLink;
      _data.linkProvider = updated.linkProvider;
      _data.linkUrl = updated.linkUrl;
      _data.hasCod = updated.hasCod;
      _data.codNotes = updated.codNotes;
      _data.hasQr = updated.hasQr;
      _data.qrNotes = updated.qrNotes;
      _data.requireHumanVerify = updated.requireHumanVerify;
      _data.customNotes = updated.customNotes;
    }
    setState(() => _isRawMode = !_isRawMode);
  }

  void _onSave() {
    final result = _isRawMode ? _rawController.text.trim() : _data.toConsolidatedText().trim();
    Navigator.of(context).pop(result.isNotEmpty ? result : null);
  }

  @override
  Widget build(BuildContext context) {
    final visual = AutomationVisual.of(context);

    return DialogContainerShell(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 12, 8),
            child: Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(color: visual.accentSoft, borderRadius: BorderRadius.circular(10)),
                  child: Icon(Icons.account_balance_wallet_rounded, color: visual.accent, size: 20),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text('Métodos de Pago', style: TextStyle(color: visual.text, fontSize: 16, fontWeight: FontWeight.bold)),
                ),
                Semantics(
                  label: _isRawMode ? 'Cambiar a modo guiado' : 'Editar como texto libre',
                  button: true,
                  child: IconButton(
                    icon: Icon(_isRawMode ? Icons.view_list_rounded : Icons.edit_note_rounded, color: visual.accent, size: 22),
                    onPressed: _toggleMode,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: _isRawMode
                ? Padding(
                    padding: const EdgeInsets.all(16),
                    child: TextField(
                      controller: _rawController,
                      maxLines: 8,
                      style: TextStyle(color: visual.text, fontSize: 13),
                      decoration: InputDecoration(
                        hintText: 'Describe aquí cómo tus clientes pueden pagarte (Nequi, Daviplata, Bancolombia, efectivo)...',
                        filled: true,
                        fillColor: visual.inputFill,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      ),
                    ),
                  )
                : PaymentMethodsGuidedView(
                    data: _data,
                    onChanged: () => setState(() {}),
                  ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text('Cancelar', style: TextStyle(color: visual.textMuted, fontSize: 12)),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: _onSave,
                  style: FilledButton.styleFrom(
                    backgroundColor: visual.accent,
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text('Guardar', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
