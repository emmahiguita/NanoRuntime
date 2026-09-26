// conversation_topic_extractor.dart
//
// QUÉ HACE:
// Extractor determinista y rápido de dominios temáticos (`TopicDomain`) y entidades clave
// a partir del texto entrante en español colombiano para conversaciones cotidianas.
//
// CÓMO FUNCIONA:
// - Analiza la presencia de marcadores léxicos categorizados en salud, trabajo, planes,
//   logística o vida personal.
// - Filtra palabras vacías (stop words en español) para aislar sustantivos y entidades operativas.
// - Determina si el turno actual continúa el tema previo o si inicia un cambio de conversación.
//
// POR QUÉ:
// Evita el uso de LLM para la extracción básica de contexto temático, respondiendo en < 5ms
// y asegurando que Nano conserve el foco narrativo. Sigue SOLID (SRP), estrictamente < 200 líneas.

library;

import '../business/fact_selector.dart' show normalizeText, tokenizeText;
import 'conversation_topic.dart';

final class ConversationTopicExtractor {
  const ConversationTopicExtractor();

  /// Identifica el tema principal o la continuidad con el tema actual.
  ConversationTopic? extractTopic({
    required String text,
    ConversationTopic? activeTopic,
    int currentTurn = 0,
  }) {
    final norm = normalizeText(text);
    if (norm.isEmpty) return activeTopic;

    final tokens = tokenizeText(norm);
    final entities = _extractSalientEntities(tokens);

    // 1. Verificar si continúa el tema activo por entidad o dominio
    if (activeTopic != null && activeTopic.isFresh()) {
      if (activeTopic.containsEntityReference(norm) || _matchesDomain(tokens, activeTopic.domain)) {
        return activeTopic.evolve(newEntities: entities, currentTurn: currentTurn);
      }
    }

    // 2. Clasificar nuevo dominio a partir de los marcadores del mensaje
    final domain = _classifyDomain(tokens, norm);
    if (domain == null) {
      // Si no hay dominio claro pero hay tema activo y son frases de avance ("sí", "ya"), mantener
      if (activeTopic != null && activeTopic.isFresh() && tokens.length <= 4) {
        return activeTopic.evolve(newEntities: entities, currentTurn: currentTurn);
      }
      return null;
    }

    final label = _generateLabel(domain, entities);
    return ConversationTopic.initial(
      domain: domain,
      label: label,
      keyEntities: entities,
      currentTurn: currentTurn,
    );
  }

  /// Clasifica el dominio del turno según palabras clave de alta frecuencia.
  TopicDomain? _classifyDomain(Iterable<String> tokens, String fullText) {
    if (tokens.any(_healthWords.contains)) return TopicDomain.healthWellbeing;
    if (tokens.any(_workWords.contains)) return TopicDomain.workProjects;
    if (tokens.any(_planWords.contains)) return TopicDomain.plansOuting;
    if (tokens.any(_logisticsWords.contains)) return TopicDomain.logisticsErrands;
    if (tokens.any(_socialWords.contains)) return TopicDomain.socialPersonal;
    return null;
  }

  /// Comprueba si los tokens reafirman el dominio del tema activo.
  bool _matchesDomain(Iterable<String> tokens, TopicDomain domain) {
    return switch (domain) {
      TopicDomain.healthWellbeing => tokens.any(_healthWords.contains),
      TopicDomain.workProjects => tokens.any(_workWords.contains),
      TopicDomain.plansOuting => tokens.any(_planWords.contains),
      TopicDomain.logisticsErrands => tokens.any(_logisticsWords.contains),
      TopicDomain.socialPersonal => tokens.any(_socialWords.contains),
      _ => false,
    };
  }

  /// Aísla sustantivos y términos descriptivos eliminando stop words comunes en español.
  Set<String> _extractSalientEntities(Iterable<String> tokens) {
    final entities = <String>{};
    for (final token in tokens) {
      if (token.length >= 4 && !_spanishStopWords.contains(token)) {
        entities.add(token);
      }
    }
    return entities;
  }

  String _generateLabel(TopicDomain domain, Set<String> entities) {
    final entitySummary = entities.take(2).join(', ');
    final suffix = entitySummary.isNotEmpty ? ' ($entitySummary)' : '';
    return switch (domain) {
      TopicDomain.healthWellbeing => 'Salud y bienestar$suffix',
      TopicDomain.workProjects => 'Trabajo y proyectos$suffix',
      TopicDomain.plansOuting => 'Planes y salidas$suffix',
      TopicDomain.logisticsErrands => 'Logística y trámites$suffix',
      TopicDomain.socialPersonal => 'Vida personal y familia$suffix',
      TopicDomain.casualGreeting => 'Saludo informal',
      TopicDomain.general => 'Tema cotidiano',
    };
  }

  // --- Diccionarios léxicos cotidianos colombianos ---

  static const Set<String> _healthWords = {
    'medico', 'doctor', 'hospital', 'clinica', 'cita', 'enfermo', 'enferma', 'dolor',
    'pastilla', 'remedio', 'moto', 'caida', 'cai', 'cae', 'raspon', 'golpe', 'fractura',
    'fiebre', 'gripe', 'examen', 'terapia', 'reposo', 'pastillas', 'urgencias', 'sano',
    'herida', 'sangre', 'cirugia', 'incapacidad', 'jarabe', 'mareo',
  };

  static const Set<String> _workWords = {
    'trabajo', 'trabajar', 'trabajando', 'camello', 'camellar', 'camellando', 'oficina',
    'jefe', 'reunion', 'cliente', 'clientes', 'proyecto', 'codigo', 'software', 'entrega',
    'entregas', 'sueldo', 'pago', 'nomina', 'turno', 'empresa', 'reporte', 'labor', 'jornada',
    'trasnocho', 'trasnochar', 'reuniones', 'sistema', 'computador',
  };

  static const Set<String> _planWords = {
    'salida', 'salir', 'plan', 'planes', 'parche', 'parchar', 'rumba', 'fiesta', 'cine',
    'viaje', 'viajar', 'paseo', 'finde', 'semana', 'almuerzo', 'almorzar', 'cena', 'cenar',
    'asado', 'cerveza', 'pola', 'tomar', 'comer', 'restaurante', 'invito', 'vamos', 'caer',
  };

  static const Set<String> _logisticsWords = {
    'banco', 'plata', 'cuenta', 'consignar', 'transferencia', 'carro', 'mecanico', 'taller',
    'repuesto', 'reparar', 'trasteo', 'mudanza', 'arriendo', 'casa', 'comprar', 'compra',
    'factura', 'tramite', 'papeles', 'notaria', 'mercado', 'tienda', 'envio', 'paquete',
  };

  static const Set<String> _socialWords = {
    'familia', 'mama', 'papa', 'hermano', 'hermana', 'hijo', 'hija', 'novia', 'novio',
    'esposa', 'esposo', 'amigo', 'amiga', 'parce', 'pana', 'cuento', 'chisme', 'imaginate',
    'paso', 'ocurrio', 'noticia', 'supiste', 'viste',
  };

  static const Set<String> _spanishStopWords = {
    'para', 'como', 'pero', 'esta', 'este', 'esto', 'estos', 'estas', 'tengo', 'tiene',
    'tenemos', 'hacer', 'hace', 'haciendo', 'todo', 'toda', 'todos', 'todas', 'bien',
    'bueno', 'buena', 'hola', 'aqui', 'alla', 'solo', 'sola', 'nada', 'algo', 'porque',
    'cuando', 'donde', 'quien', 'cual', 'mucho', 'poco', 'antes', 'despues', 'sobre',
    'entre', 'hasta', 'desde', 'estoy', 'estabas', 'estaba', 'somos', 'ellos', 'ellas',
  };
}
