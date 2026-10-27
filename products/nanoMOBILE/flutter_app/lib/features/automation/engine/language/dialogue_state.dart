// Estado explícito del diálogo y exportación compatible del análisis lingüístico.
library;

export 'linguistic_analyzer.dart'
    show LinguisticSignals, LinguisticAnalyzer, linguisticAnalyzer;

/// Acto comunicativo principal inferido del mensaje.
enum DialogueAct {
  greeting,
  socialCheckin,
  technicalInquiry,
  commercialInquiry,
  correction,
  negation,
  clarification,
  closure,
  multiIntent,
  general,
}
