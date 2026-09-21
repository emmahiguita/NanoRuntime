import 'package:flutter/material.dart';
import 'package:nanoai/features/automation/presentation/automation_visual_theme.dart';

/// Diálogo profesional para la configuración de métodos de pago y políticas de cobro.
class PaymentMethodsDialog extends StatefulWidget {
  final String initial;

  const PaymentMethodsDialog({super.key, required this.initial});

  @override
  State<PaymentMethodsDialog> createState() => _PaymentMethodsDialogState();
}

class _PaymentMethodsDialogState extends State<PaymentMethodsDialog> {
  bool _transfer = true;
  late final TextEditingController _bankName;
  late final TextEditingController _accountType;
  late final TextEditingController _accountNumber;
  late final TextEditingController _accountHolder;
  late final TextEditingController _accountDoc;

  bool _wallet = true;
  late final TextEditingController _walletName;
  late final TextEditingController _walletNumber;

  bool _link = false;
  late final TextEditingController _linkProvider;
  late final TextEditingController _linkUrl;

  bool _cod = false;
  late final TextEditingController _codNotes;

  bool _qr = false;
  late final TextEditingController _qrNotes;

  bool _requireHumanVerify = true;
  late final TextEditingController _customNotes;
  bool _isRawMode = false;
  late final TextEditingController _rawController;

  @override
  void initState() {
    super.initState();
    _rawController = TextEditingController(text: widget.initial);
    _initControllersFromText(widget.initial);
  }

  void _initControllersFromText(String text) {
    String bank = 'Bancolombia';
    String type = 'Ahorros';
    String accNum = '';
    String holder = '';
    String doc = '';
    bool hasTransfer = false;

    String wallet = 'Nequi / Daviplata';
    String walletNum = '';
    bool hasWallet = false;

    String linkProv = 'Wompi / PSE';
    String linkU = '';
    bool hasLink = false;

    String codText = 'Pago contra entrega en efectivo';
    bool hasCod = false;

    String qrText = 'Solicita el código QR por este chat';
    bool hasQr = false;

    bool humanVerify = true;
    final otherNotes = <String>[];

    final cleanText = text.trim();
    if (cleanText.isNotEmpty) {
      final sentences = cleanText.split(RegExp(r'\.\s+'));
      for (final s in sentences) {
        final lower = s.toLowerCase();
        if (lower.contains('transferencia') || lower.contains('banco') || lower.contains('cuenta')) {
          hasTransfer = true;
          final matchBank = RegExp(r'transferencia\s+([a-záéíóúñ\s]+?)(?:\s*\((.*?)\))?:\s*([0-9\-\s]+)', caseSensitive: false).firstMatch(s);
          if (matchBank != null) {
            bank = matchBank.group(1)?.trim() ?? bank;
            type = matchBank.group(2)?.trim() ?? type;
            accNum = matchBank.group(3)?.trim() ?? '';
          }
          final matchHolder = RegExp(r'a nombre de\s+([a-záéíóúñ\s]+?)(?:\s*\(|\.|$)', caseSensitive: false).firstMatch(s);
          if (matchHolder != null) holder = matchHolder.group(1)?.trim() ?? '';
          final matchDoc = RegExp(r'(?:cc|nit)[\s:]*([0-9\.\-]+)', caseSensitive: false).firstMatch(s);
          if (matchDoc != null) doc = matchDoc.group(1)?.trim() ?? '';
        } else if (lower.contains('nequi') || lower.contains('daviplata') || lower.contains('billetera') || lower.contains('celular')) {
          hasWallet = true;
          final matchWallet = RegExp(r'(nequi(?:\s*\/\s*daviplata)?|daviplata|dale|movii)[\s:]*([0-9\s]+)', caseSensitive: false).firstMatch(s);
          if (matchWallet != null) {
            wallet = matchWallet.group(1)?.trim() ?? wallet;
            walletNum = matchWallet.group(2)?.trim() ?? '';
          }
        } else if (lower.contains('enlace de pago') || lower.contains('link') || lower.contains('wompi') || lower.contains('pse') || lower.contains('bold')) {
          hasLink = true;
          final matchLink = RegExp(r'enlace de pago\s*(?:\((.*?)\))?:\s*(https?:\/\/[^\s]+)', caseSensitive: false).firstMatch(s);
          if (matchLink != null) {
            linkProv = matchLink.group(1)?.trim() ?? linkProv;
            linkU = matchLink.group(2)?.trim() ?? '';
          }
        } else if (lower.contains('contra entrega') || lower.contains('contraentrega')) {
          hasCod = true;
          codText = s.trim();
        } else if (lower.contains('código qr') || lower.contains('qr')) {
          hasQr = true;
          qrText = s.trim();
        } else if (lower.contains('comprobante') || lower.contains('pendiente de verificación')) {
          humanVerify = true;
        } else if (s.trim().isNotEmpty) {
          otherNotes.add(s.trim());
        }
      }
    }

    _transfer = hasTransfer || cleanText.isEmpty;
    _bankName = TextEditingController(text: bank);
    _accountType = TextEditingController(text: type);
    _accountNumber = TextEditingController(text: accNum);
    _accountHolder = TextEditingController(text: holder);
    _accountDoc = TextEditingController(text: doc);

    _wallet = hasWallet || cleanText.isEmpty;
    _walletName = TextEditingController(text: wallet);
    _walletNumber = TextEditingController(text: walletNum);

    _link = hasLink;
    _linkProvider = TextEditingController(text: linkProv);
    _linkUrl = TextEditingController(text: linkU);

    _cod = hasCod;
    _codNotes = TextEditingController(text: codText);

    _qr = hasQr;
    _qrNotes = TextEditingController(text: qrText);

    _requireHumanVerify = humanVerify;
    _customNotes = TextEditingController(text: otherNotes.join('. '));
  }

  @override
  void dispose() {
    _bankName.dispose();
    _accountType.dispose();
    _accountNumber.dispose();
    _accountHolder.dispose();
    _accountDoc.dispose();
    _walletName.dispose();
    _walletNumber.dispose();
    _linkProvider.dispose();
    _linkUrl.dispose();
    _codNotes.dispose();
    _qrNotes.dispose();
    _customNotes.dispose();
    _rawController.dispose();
    super.dispose();
  }

  String _buildConsolidated() {
    final parts = <String>[];
    if (_transfer && _accountNumber.text.trim().isNotEmpty) {
      final bank = _bankName.text.trim();
      final type = _accountType.text.trim();
      final num = _accountNumber.text.trim();
      final holder = _accountHolder.text.trim();
      final doc = _accountDoc.text.trim();
      final b = StringBuffer('Transferencia $bank ($type): $num');
      if (holder.isNotEmpty) b.write(' a nombre de $holder');
      if (doc.isNotEmpty) b.write(' (CC/NIT: $doc)');
      parts.add(b.toString());
    }
    if (_wallet && _walletNumber.text.trim().isNotEmpty) {
      final wName = _walletName.text.trim();
      final wNum = _walletNumber.text.trim();
      parts.add('$wName: $wNum');
    }
    if (_link) {
      final provider = _linkProvider.text.trim();
      final url = _linkUrl.text.trim();
      parts.add('Enlace de pago ($provider)${url.isNotEmpty ? ': $url' : ''}');
    }
    if (_cod) {
      final cod = _codNotes.text.trim();
      if (cod.isNotEmpty) parts.add(cod);
    }
    if (_qr) {
      final qr = _qrNotes.text.trim();
      if (qr.isNotEmpty) parts.add(qr);
    }
    if (_customNotes.text.trim().isNotEmpty) {
      parts.add(_customNotes.text.trim());
    }
    if (_requireHumanVerify) {
      parts.add(
        'Enviar comprobante de pago. Todo pedido queda en estado "Pendiente de verificación" hasta confirmación humana en cuenta bancaria.',
      );
    }
    if (parts.isEmpty && widget.initial.trim().isNotEmpty) {
      return widget.initial.trim();
    }
    return parts.join('. ');
  }

  @override
  Widget build(BuildContext context) {
    final visual = AutomationVisual.of(context);

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 480, maxHeight: 680),
        decoration: BoxDecoration(
          color: visual.isDark ? const Color(0xFF0F172A) : Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: visual.isDark
                ? Colors.white.withValues(alpha: 0.16)
                : const Color(0xFFCBD5E1),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.35),
              blurRadius: 28,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 14, 12),
              child: Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: visual.accentSoft,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.payments_outlined, color: visual.accent, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Métodos de pago',
                      style: TextStyle(
                        color: visual.text,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.4,
                      ),
                    ),
                  ),
                  // Semantics en lugar de Tooltip: previene el fallo "No Overlay" (cajas rojas con texto amarillo)
                  // al evitar llamadas a Overlay.of(context) en sub-árboles de diálogo.
                  Semantics(
                    label: _isRawMode ? 'Cambiar a modo guiado' : 'Editar como texto libre',
                    button: true,
                    child: IconButton(
                      icon: Icon(
                        _isRawMode ? Icons.view_list_rounded : Icons.edit_note_rounded,
                        color: visual.accent,
                      ),
                      onPressed: () {
                        if (!_isRawMode) {
                          _rawController.text = _buildConsolidated();
                        }
                        setState(() => _isRawMode = !_isRawMode);
                      },
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),

            // Scrollable Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: _isRawMode
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Modo texto libre: escribe los datos de pago exactamente como deseas que el asistente los transmita.',
                            style: TextStyle(color: visual.textMuted, fontSize: 13),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _rawController,
                            maxLines: 8,
                            style: TextStyle(color: visual.text, fontSize: 14),
                            decoration: InputDecoration(
                              hintText: 'Ej. Bancolombia Ahorros # 12345... Nequi: 3001234567...',
                              filled: true,
                              fillColor: visual.inputFill,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: BorderSide.none,
                              ),
                            ),
                          ),
                        ],
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            'La IA y el motor responderán con estos datos exactos sin inventar números ni cuentas.',
                            style: TextStyle(color: visual.textMuted, fontSize: 12.5),
                          ),
                          const SizedBox(height: 16),

                          // 1. Transferencia Bancaria
                          _buildSwitchHeader('1. Transferencia Bancaria', _transfer, (v) => setState(() => _transfer = v)),
                          if (_transfer) ...[
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(
                                  flex: 3,
                                  child: TextField(
                                    controller: _bankName,
                                    style: TextStyle(color: visual.text, fontSize: 13.5),
                                    decoration: InputDecoration(
                                      labelText: 'Banco',
                                      filled: true,
                                      fillColor: visual.inputFill,
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                                      isDense: true,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  flex: 2,
                                  child: TextField(
                                    controller: _accountType,
                                    style: TextStyle(color: visual.text, fontSize: 13.5),
                                    decoration: InputDecoration(
                                      labelText: 'Tipo de cuenta',
                                      filled: true,
                                      fillColor: visual.inputFill,
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                                      isDense: true,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            TextField(
                              controller: _accountNumber,
                              keyboardType: TextInputType.number,
                              style: TextStyle(color: visual.text, fontSize: 13.5),
                              decoration: InputDecoration(
                                labelText: 'Número de cuenta',
                                hintText: 'Ej. 123-456789-01',
                                filled: true,
                                fillColor: visual.inputFill,
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                                isDense: true,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: _accountHolder,
                                    style: TextStyle(color: visual.text, fontSize: 13.5),
                                    decoration: InputDecoration(
                                      labelText: 'Titular de la cuenta',
                                      filled: true,
                                      fillColor: visual.inputFill,
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                                      isDense: true,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: TextField(
                                    controller: _accountDoc,
                                    style: TextStyle(color: visual.text, fontSize: 13.5),
                                    decoration: InputDecoration(
                                      labelText: 'CC o NIT (opcional)',
                                      filled: true,
                                      fillColor: visual.inputFill,
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                                      isDense: true,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],

                          const Divider(height: 24),

                          // 2. Billeteras Móviles
                          _buildSwitchHeader('2. Billeteras Móviles (Nequi / Daviplata)', _wallet, (v) => setState(() => _wallet = v)),
                          if (_wallet) ...[
                            const SizedBox(height: 8),
                            TextField(
                              controller: _walletName,
                              style: TextStyle(color: visual.text, fontSize: 13.5),
                              decoration: InputDecoration(
                                labelText: 'Plataforma',
                                filled: true,
                                fillColor: visual.inputFill,
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                                isDense: true,
                              ),
                            ),
                            const SizedBox(height: 8),
                            TextField(
                              controller: _walletNumber,
                              keyboardType: TextInputType.phone,
                              style: TextStyle(color: visual.text, fontSize: 13.5),
                              decoration: InputDecoration(
                                labelText: 'Número de celular o depósito',
                                hintText: 'Ej. 3001234567',
                                filled: true,
                                fillColor: visual.inputFill,
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                                isDense: true,
                              ),
                            ),
                          ],

                          const Divider(height: 24),

                          // 3. Link de Pago
                          _buildSwitchHeader('3. Link de Pago / Pasarela (Wompi, Bold)', _link, (v) => setState(() => _link = v)),
                          if (_link) ...[
                            const SizedBox(height: 8),
                            TextField(
                              controller: _linkProvider,
                              style: TextStyle(color: visual.text, fontSize: 13.5),
                              decoration: InputDecoration(
                                labelText: 'Pasarela',
                                filled: true,
                                fillColor: visual.inputFill,
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                                isDense: true,
                              ),
                            ),
                            const SizedBox(height: 8),
                            TextField(
                              controller: _linkUrl,
                              style: TextStyle(color: visual.text, fontSize: 13.5),
                              decoration: InputDecoration(
                                labelText: 'Enlace web (URL)',
                                hintText: 'https://checkout.wompi.co/...',
                                filled: true,
                                fillColor: visual.inputFill,
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                                isDense: true,
                              ),
                            ),
                          ],

                          const Divider(height: 24),

                          // 4. Contra Entrega & QR
                          _buildSwitchHeader('4. Pago Contra Entrega', _cod, (v) => setState(() => _cod = v)),
                          if (_cod) ...[
                            const SizedBox(height: 8),
                            TextField(
                              controller: _codNotes,
                              style: TextStyle(color: visual.text, fontSize: 13.5),
                              decoration: InputDecoration(
                                labelText: 'Instrucciones contra entrega',
                                filled: true,
                                fillColor: visual.inputFill,
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                                isDense: true,
                              ),
                            ),
                          ],

                          const SizedBox(height: 12),
                          _buildSwitchHeader('5. Código QR de Cobro', _qr, (v) => setState(() => _qr = v)),
                          if (_qr) ...[
                            const SizedBox(height: 8),
                            TextField(
                              controller: _qrNotes,
                              style: TextStyle(color: visual.text, fontSize: 13.5),
                              decoration: InputDecoration(
                                labelText: 'Instrucción código QR',
                                filled: true,
                                fillColor: visual.inputFill,
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                                isDense: true,
                              ),
                            ),
                          ],

                          const Divider(height: 24),

                          // Verificación Humana
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: visual.accentSoft.withValues(alpha: 0.25),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: visual.accent.withValues(alpha: 0.3),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(Icons.shield_outlined, size: 18, color: visual.accent),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        'Verificación de Comprobante',
                                        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: visual.text),
                                      ),
                                    ),
                                    Switch(
                                      value: _requireHumanVerify,
                                      onChanged: (v) => setState(() => _requireHumanVerify = v),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'El bot solicitará el comprobante y aclarará que el pedido entra a "Pendiente de verificación" hasta validación humana en cuenta.',
                                  style: TextStyle(fontSize: 11.5, color: visual.textMuted, height: 1.3),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 14),
                          TextField(
                            controller: _customNotes,
                            style: TextStyle(color: visual.text, fontSize: 13.5),
                            decoration: InputDecoration(
                              labelText: 'Notas adicionales (opcional)',
                              filled: true,
                              fillColor: visual.inputFill,
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                              isDense: true,
                            ),
                          ),
                        ],
                      ),
              ),
            ),

            const Divider(height: 1),
            // Actions
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: TextButton.styleFrom(
                      foregroundColor: visual.textMuted,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    ),
                    child: const Text('Cancelar'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: () {
                      final result = _isRawMode ? _rawController.text.trim() : _buildConsolidated();
                      Navigator.of(context).pop(result.isNotEmpty ? result : null);
                    },
                    style: FilledButton.styleFrom(
                      backgroundColor: visual.accent,
                      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: const Text('Guardar'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSwitchHeader(String title, bool value, ValueChanged<bool> onChanged) {
    final visual = AutomationVisual.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(
            title,
            style: TextStyle(color: visual.text, fontWeight: FontWeight.w600, fontSize: 13.5),
          ),
        ),
        Switch(
          value: value,
          onChanged: onChanged,
        ),
      ],
    );
  }
}
