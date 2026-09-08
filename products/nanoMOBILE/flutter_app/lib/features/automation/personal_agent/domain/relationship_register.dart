/// RelationshipRegister (A08) — motor de relación determinista y puro:
/// UNKNOWN / KNOWN / CLOSE / PROFESSIONAL / CUSTOM.
///
/// Invariantes del brief:
/// - KNOWN CONTACT != CLOSE CONTACT: registrar a un contacto no lo hace
///   cercano. El nivel deriva SOLO de evidencia que el dueño dejó escrita
///   (displayName + facts del perfil de relación), jamás del LLM ni del
///   tono del mensaje.
/// - PERSONA CHANGES HOW / NOT WHAT IS TRUE: el nivel alimenta FORMA
///   (registro de trato en el prompt) y jamás hechos nuevos.
/// - Sin keyword hell: las listas son etiquetas de RELACIÓN reutilizables
///   y acotadas, no intents; lo que no matchea queda `custom` o `known`.
library;

import '../../engine/business/fact_selector.dart' show tokenizeText;
import 'conversation_agent_role.dart' show familyTokens;
import 'persona_profile.dart' show RelationshipProfile;
import '../../engine/messaging/tone_profile.dart';
import 'dart:convert';

/// Nivel de relación derivado de evidencia registrada.
enum RelationshipLevel {
  /// Sin perfil registrado para el remitente.
  unknown,

  /// Registrado, sin etiquetas de cercanía ni profesionales.
  known,

  /// Marcadores de cercanía (familia/amistad) en el registro.
  close,

  /// Marcadores profesionales (cliente/trabajo/negocio) en el registro.
  professional,

  /// Registro personalizado (facts) sin etiqueta estándar reconocida.
  custom,
}

/// Etiquetas de cercanía: familia (reutiliza [familyTokens] del router) +
/// amistad. Lista acotada de RELACIÓN, no de contenido.
const Set<String> _closeTokens = {
  ...familyTokens,
  'amigo',
  'amiga',
  'amistad',
  'parcero',
  'parcera',
  'primo',
  'prima',
  'cunado',
  'cuñado',
  'suegro',
  'suegra',
  'yerno',
  'nuera',
  'vecino',
  'vecina',
};

/// Frases compuestas de cercanía (matching por contains, no token).
const List<String> _closePhrases = ['mejor amigo', 'mejor amiga'];

/// Etiquetas profesionales: vínculo de trabajo/negocio con el dueño.
const Set<String> _professionalTokens = {
  'cliente',
  'clienta',
  'proveedor',
  'trabajo',
  'negocio',
  'socio',
  'empresa',
  'doctor',
  'doctora',
  'abogado',
  'abogada',
  'contador',
  'contadora',
  'tienda',
  'pedido',
  'envio',
  'envío',
  'factura',
  'cotizacion',
  'cotización',
};

/// Etiqueta legible del nivel (línea de trato del prompt).
const Map<RelationshipLevel, String> _levelLabel = {
  RelationshipLevel.unknown: '',
  RelationshipLevel.known: 'conocido',
  RelationshipLevel.close: 'cercano',
  RelationshipLevel.professional: 'profesional',
  RelationshipLevel.custom: 'personalizado',
};

final class RelationshipRegister {
  const RelationshipRegister();

  /// Deriva el nivel SOLO de evidencia registrada. Prioridad:
  /// professional > close > custom > known. `unknown` sin perfil.
  static RelationshipLevel derive({required RelationshipProfile? profile}) {
    if (profile == null || profile.facts['profileEnabled'] == 'false') {
      return RelationshipLevel.unknown;
    }
    final explicit = profile.facts['relationship'];
    if (explicit == 'professional') return RelationshipLevel.professional;
    if (explicit == 'close' || explicit == 'family') {
      return RelationshipLevel.close;
    }
    if (explicit == 'known') return RelationshipLevel.known;
    final evidence = [...profile.facts.values].join(' ').toLowerCase();
    final tokens = tokenizeText(evidence).toSet();
    if (tokens.any(_professionalTokens.contains)) {
      return RelationshipLevel.professional;
    }
    if (tokens.any(_closeTokens.contains) ||
        _closePhrases.any(evidence.contains)) {
      return RelationshipLevel.close;
    }
    if (profile.facts.isNotEmpty) return RelationshipLevel.custom;
    return RelationshipLevel.known;
  }

  /// Línea opcional de trato para el bloque <DATOS DE LA PERSONA>.
  /// null cuando no hay perfil: el prompt social mínimo no se infla y la
  /// relación sigue siendo una señal del router (hasRelationshipFor).
  static String? relationLineFor({required RelationshipProfile? profile}) {
    if (profile == null) return null;
    final level = derive(profile: profile);
    final label = _levelLabel[level];
    if (label == null || label.isEmpty) return null;
    return 'Trato declarado: $label. ${styleLine(profile.facts)}';
  }

  static String styleLine(Map<String, String> facts) {
    final register = facts['styleRegister'];
    if (register == null) return '';
    ToneProfile tone;
    try {
      tone = ToneProfile.fromJson(
        jsonDecode(facts['tone'] ?? '{}') as Map<String, dynamic>,
      );
    } catch (_) {
      tone = const ToneProfile();
    }
    final style = switch (register) {
      'formal' =>
        'Formal natural, respetuoso, ortografía correcta; sin slang ni diminutivos de confianza.',
      'close' =>
        'Cercano con naturalidad; no repitas muletillas en cada respuesta.',
      'casual' => 'Casual neutral y natural; sin intimidad inventada.',
      _ => 'Personalizado, manteniendo claridad y respeto.',
    };
    final length = switch (tone.verbosity) {
      ToneVerbosity.breve => 'Breve.',
      ToneVerbosity.media => 'Extensión media.',
      ToneVerbosity.extensa => 'Desarrolla solo lo necesario.',
    };
    final custom = (facts['customStyle'] ?? '')
        .replaceAll('<', '‹')
        .replaceAll('>', '›');
    return '$style $length ${tone.emojis ? 'Emojis moderados si encajan.' : 'Sin emojis.'} '
        '${facts['allowSlang'] == 'true' && register != 'formal' ? 'Slang solo si hay evidencia del dueño y encaja.' : 'No fuerces slang.'} '
        '${facts['usesContactName'] == 'never' ? 'No uses el nombre al saludar.' : 'Usa el nombre solo cuando sea natural; no es obligatorio.'} '
        '${custom.length > 240 ? custom.substring(0, 240) : custom}';
  }
}
