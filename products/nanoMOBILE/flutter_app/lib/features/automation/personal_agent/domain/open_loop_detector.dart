/// LOOP-4-OPEN-LOOPS — detector determinista de compromisos pendientes.
///
/// Sin LLM: reglas léxicas del mismo estilo que los clasificadores
/// existentes (saludos, risas, correcciones). Un compromiso detectado es
/// una HIPÓTESIS con confianza derivada — jamás se convierte en hecho;
/// el router (LOOP 6) podrá refinarlo. Solo metadatos compactos.
///
/// Señales: "te aviso cuando llegue", "mañana te paso eso", "confírmame la
/// hora", "después te cuento", "te mando el archivo", etc.
library;

import 'dart:convert';
import 'package:crypto/crypto.dart';

import 'personal_conversation_state.dart';

abstract final class OpenLoopDetector {
  static final List<RegExp> _strongSignals = [
    RegExp(
      r'te\s+(?:aviso|avisar[eé]|confirmo|mando|env[ií]o|paso|cuento|escribo|llamo)\b',
      caseSensitive: false,
    ),
    RegExp(
      r'(?:avisame|avísame|confirmame|confírmame|recu[eé]rdame|escr[ií]beme)\b',
      caseSensitive: false,
    ),
    RegExp(r'te\s+confirmo\b', caseSensitive: false),
    RegExp(
      r'\b(?:llegando|llegue|llegu[eé]|est[eé]|salga|salgo)\s+te\s+(?:aviso|digo|escribo|confirmo)',
      caseSensitive: false,
    ),
  ];

  static final List<RegExp> _weakSignals = [
    RegExp(
      r'\b(?:luego|despu[eé]s|m[aá]s\s+tarde|en\s+un\s+rato|al\s+rato)\s+te\s+(?:digo|cuento|aviso|escribo|paso|mando)\b',
      caseSensitive: false,
    ),
    RegExp(
      r'\bte\s+(?:digo|cuento|aviso|escribo|paso|mando)\s+(?:luego|despu[eé]s|m[aá]s\s+tarde)\b',
      caseSensitive: false,
    ),
    RegExp(
      r'\b(?:pendiente|quedamos\s+en|cuando\s+puedas|apenas\s+pueda)\b',
      caseSensitive: false,
    ),
  ];

  static final List<RegExp> _dueHints = [
    RegExp(
      r'\b(?:hoy|esta\s+noche|esta\s+tarde|ahorita|ahora\s+mismo)\b',
      caseSensitive: false,
    ),
    RegExp(r'\bma[nñ]ana\b', caseSensitive: false),
    RegExp(
      r'\b(?:el\s+)?(?:lunes|martes|mi[eé]rcoles|jueves|viernes|s[aá]bado|domingo)\b',
      caseSensitive: false,
    ),
  ];

  /// Firma idempotente: misma descripción normalizada → mismo id, para que
  /// dos turnos con el mismo compromiso no dupliquen el loop.
  static String loopId(String normalizedDescription) {
    final digest = sha256.convert(utf8.encode(normalizedDescription));
    return 'loop:${digest.toString().substring(0, 12)}';
  }

  static String _normalize(String raw) {
    final single = raw.replaceAll(RegExp(r'\s+'), ' ').trim().toLowerCase();
    return single.replaceAll(RegExp(r'[.,;:!?¿¡]'), '');
  }

  /// Detecta como máximo un compromiso por mensaje para evitar ruido.
  static List<OpenLoopSummary> detect(String text, {required int nowMs}) {
    final raw = text.trim();
    if (raw.isEmpty) return const [];
    final norm = _normalize(raw);
    final strong = _strongSignals.where((r) => r.hasMatch(norm)).length;
    final weak = _weakSignals.where((r) => r.hasMatch(norm)).length;
    if (strong == 0 && weak == 0) return const [];

    final confidence = strong > 0 ? 0.85 : 0.6;
    final dueHint = _dueHints
        .map((r) => r.firstMatch(raw)?.group(0)?.toLowerCase() ?? '')
        .where((h) => h.isNotEmpty)
        .firstOrNull;

    // El compromiso lo contrae el CONTACTO cuando el texto es una promesa
    // de avisar/enviar ("te aviso"); el dueño cuando es una petición de
    // confirmación ("confírmame"). Clasificación por la persona verbal.
    final owner =
        RegExp(
          r'\b(?:avisame|avísame|confirmame|confírmame|recu[eé]rdame)\b',
          caseSensitive: false,
        ).hasMatch(norm)
        ? 'owner'
        : 'contact';

    final type = dueHint != null ? 'reminder' : 'pending_commitment';
    // No persiste el mensaje ni una porción del mismo. La descripción es una
    // etiqueta semántica estable y el hash conserva idempotencia sin PII.
    final description = [
      owner == 'owner'
          ? 'Compromiso pendiente del dueño'
          : 'Compromiso pendiente del contacto',
      if (dueHint != null) dueHint,
    ].join(' · ');
    return [
      OpenLoopSummary(
        id: loopId(norm),
        description: description,
        type: type,
        owner: owner,
        status: 'OPEN',
        dueHint: dueHint ?? '',
        createdAt: nowMs,
        confidence: confidence,
      ),
    ];
  }
}
