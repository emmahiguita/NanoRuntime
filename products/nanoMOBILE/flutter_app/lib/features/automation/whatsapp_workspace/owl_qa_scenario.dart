import 'dart:convert';
import 'package:crypto/crypto.dart';

/// Escenario determinista acotado a WhatsApp instalado. No admite comandos
/// arbitrarios ni envíos implícitos: cada acción y aserción queda serializada.
class OwlQaScenario {
  const OwlQaScenario(this.id, this.steps);
  final String id;
  final List<Map<String, String>> steps;
  Map<String, dynamic> toJson() => {
    'id': id,
    'version': 1,
    'allowedPackages': ['com.whatsapp', 'dev.nanoai.mobile'],
    'steps': steps,
  };

  /// El contacto es dato JSON. Abrir no añade texto a enviar ni usa WhatsApp Web.
  factory OwlQaScenario.whatsApp({String? contact}) {
    final target = contact?.trim() ?? '';
    if (target.contains('\n') || target.length > 150) {
      throw const FormatException('Contacto de prueba inválido.');
    }
    final steps = <Map<String, String>>[
      {
        'command': '@abrir com.whatsapp',
        'package': 'com.whatsapp',
        'expected': 'WhatsApp instalado visible',
      },
      if (target.isNotEmpty)
        {
          'command': '@whatsapp ${jsonEncode(target)}',
          'package': 'com.whatsapp',
          'recipient': target,
          'expected': 'Perfil del destinatario exacto y retorno al chat',
        },
      {
        'command': '@abrir dev.nanoai.mobile',
        'package': 'dev.nanoai.mobile',
        'expected': 'Nano visible de nuevo',
      },
    ];
    final id =
        'whatsapp_${sha256.convert(utf8.encode(jsonEncode(steps))).toString().substring(0, 16)}';
    return OwlQaScenario(id, steps);
  }

  /// Solo restaura el contrato generado, comprobando pasos e ID. Un fichero
  /// editado no puede convertirse en una orden de enviar, borrar o abrir URLs.
  factory OwlQaScenario.fromJson(Map<String, dynamic> json) {
    final raw = (json['steps'] as List).cast<Map>();
    final target = raw
        .where((s) => s.containsKey('recipient'))
        .map((s) => s['recipient'] as String)
        .toList();
    if (target.length > 1) {
      throw const FormatException('Escenario no permitido.');
    }
    final expected = OwlQaScenario.whatsApp(
      contact: target.isEmpty ? null : target.single,
    );
    if (jsonEncode(json) != jsonEncode(expected.toJson())) {
      throw const FormatException(
        'El contrato QA cambió o contiene acciones no autorizadas.',
      );
    }
    return expected;
  }
}
