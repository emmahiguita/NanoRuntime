// payment_methods_models.dart
//
// QUÉ HACE:
// Modelo de datos y utilidades de serialización/deserialización para métodos de pago comerciales.
//
// CÓMO FUNCIONA:
// - Descompone texto libre o precargado mediante expresiones regulares tolerantes:
//   * Transferencias bancarias (Bancolombia, Banco de Bogotá, etc., tipo de cuenta, titular, documento).
//   * Billeteras digitales (Nequi, Daviplata, Dale, Movii).
//   * Enlaces de pago (Wompi, PSE, Bold, MercadoPago).
//   * Pagos contra entrega y códigos QR de recaudo.
// - Recompone un texto consolidado profesional y estructurado para respuestas directas del bot.
//
// POR QUÉ:
// Aplica SOLID (SRP) separando el parseo de datos de la interfaz de usuario, garantizando < 200 líneas.

class PaymentMethodsData {
  bool hasTransfer;
  String bankName;
  String accountType;
  String accountNumber;
  String accountHolder;
  String accountDoc;

  bool hasWallet;
  String walletName;
  String walletNumber;

  bool hasLink;
  String linkProvider;
  String linkUrl;

  bool hasCod;
  String codNotes;

  bool hasQr;
  String qrNotes;

  bool requireHumanVerify;
  String customNotes;

  PaymentMethodsData({
    this.hasTransfer = false,
    this.bankName = 'Bancolombia',
    this.accountType = 'Ahorros',
    this.accountNumber = '',
    this.accountHolder = '',
    this.accountDoc = '',
    this.hasWallet = false,
    this.walletName = 'Nequi / Daviplata',
    this.walletNumber = '',
    this.hasLink = false,
    this.linkProvider = 'Wompi / PSE',
    this.linkUrl = '',
    this.hasCod = false,
    this.codNotes = 'Pago contra entrega en efectivo al recibir',
    this.hasQr = false,
    this.qrNotes = 'Solicita el código QR por este chat',
    this.requireHumanVerify = true,
    this.customNotes = '',
  });

  factory PaymentMethodsData.fromText(String rawText) {
    final data = PaymentMethodsData();
    final clean = rawText.trim();
    if (clean.isEmpty) return data;

    final sentences = clean.split(RegExp(r'\.\s+'));
    final otherNotes = <String>[];

    for (final s in sentences) {
      final lower = s.toLowerCase();
      if (lower.contains('transferencia') || lower.contains('banco') || lower.contains('cuenta')) {
        data.hasTransfer = true;
        final mBank = RegExp(r'transferencia\s+([a-záéíóúñ\s]+?)(?:\s*\((.*?)\))?:\s*([0-9\-\s]+)', caseSensitive: false).firstMatch(s);
        if (mBank != null) {
          data.bankName = mBank.group(1)?.trim() ?? data.bankName;
          data.accountType = mBank.group(2)?.trim() ?? data.accountType;
          data.accountNumber = mBank.group(3)?.trim() ?? '';
        }
        final mHolder = RegExp(r'a nombre de\s+([a-záéíóúñ\s]+?)(?:\s*\(|\.|$)', caseSensitive: false).firstMatch(s);
        if (mHolder != null) data.accountHolder = mHolder.group(1)?.trim() ?? '';
        final mDoc = RegExp(r'(?:cc|nit)[\s:]*([0-9\.\-]+)', caseSensitive: false).firstMatch(s);
        if (mDoc != null) data.accountDoc = mDoc.group(1)?.trim() ?? '';
      } else if (lower.contains('nequi') || lower.contains('daviplata') || lower.contains('billetera') || lower.contains('celular')) {
        data.hasWallet = true;
        final mWall = RegExp(r'(nequi(?:\s*\/\s*daviplata)?|daviplata|dale|movii)[\s:]*([0-9\s]+)', caseSensitive: false).firstMatch(s);
        if (mWall != null) {
          data.walletName = mWall.group(1)?.trim() ?? data.walletName;
          data.walletNumber = mWall.group(2)?.trim() ?? '';
        }
      } else if (lower.contains('enlace de pago') || lower.contains('link') || lower.contains('wompi') || lower.contains('pse') || lower.contains('bold')) {
        data.hasLink = true;
        final mLink = RegExp(r'enlace de pago\s*(?:\((.*?)\))?:\s*(https?:\/\/[^\s]+)', caseSensitive: false).firstMatch(s);
        if (mLink != null) {
          data.linkProvider = mLink.group(1)?.trim() ?? data.linkProvider;
          data.linkUrl = mLink.group(2)?.trim() ?? '';
        }
      } else if (lower.contains('contra entrega') || lower.contains('contraentrega') || lower.contains('efectivo')) {
        data.hasCod = true;
        data.codNotes = s.trim();
      } else if (lower.contains('código qr') || lower.contains('codigo qr') || lower.contains('qr')) {
        data.hasQr = true;
        data.qrNotes = s.trim();
      } else if (lower.contains('comprobante') || lower.contains('soporte') || lower.contains('verificación')) {
        data.requireHumanVerify = true;
      } else if (s.trim().isNotEmpty) {
        otherNotes.add(s.trim());
      }
    }
    data.customNotes = otherNotes.join('. ');
    return data;
  }

  String toConsolidatedText() {
    final parts = <String>[];
    if (hasTransfer && accountNumber.trim().isNotEmpty) {
      final doc = accountDoc.trim().isNotEmpty ? ' (CC/NIT: ${accountDoc.trim()})' : '';
      final holder = accountHolder.trim().isNotEmpty ? ' a nombre de ${accountHolder.trim()}$doc' : '';
      parts.add('Transferencia ${bankName.trim()} (${accountType.trim()}): ${accountNumber.trim()}$holder');
    }
    if (hasWallet && walletNumber.trim().isNotEmpty) {
      parts.add('${walletName.trim()}: ${walletNumber.trim()}');
    }
    if (hasLink && linkUrl.trim().isNotEmpty) {
      parts.add('Enlace de pago (${linkProvider.trim()}): ${linkUrl.trim()}');
    }
    if (hasCod && codNotes.trim().isNotEmpty) {
      parts.add(codNotes.trim());
    }
    if (hasQr && qrNotes.trim().isNotEmpty) {
      parts.add(qrNotes.trim());
    }
    if (requireHumanVerify && parts.isNotEmpty) {
      parts.add('Una vez realizado el pago, envía tu comprobante por este chat para confirmar el pedido.');
    }
    if (customNotes.trim().isNotEmpty) {
      parts.add(customNotes.trim());
    }
    return parts.join('. ');
  }
}
