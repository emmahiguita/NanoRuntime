// conversation_coverage_analyzer.dart
//
// QUÉ HACE:
// Analiza las ventanas de cobertura histórica de una conversación y detecta huecos
// temporales exactos (tanto previos al primer mensaje como entre capturas).
//
// CÓMO FUNCIONA:
// - Ordena cronológicamente los registros de [ConversationCoverage].
// - Fusiona ventanas solapadas o contiguas dentro de una tolerancia configurable.
// - Identifica si el inicio del historial está incompleto (`hasLeadingGap`) y
//   calcula cada intervalo desconectado ([ConversationTimeGap]) entre proveedores.
//
// POR QUÉ:
// Completa el Punto 4 de la arquitectura canónica: el LLM y el motor de reglas
// no deben asumir continuidad cuando hubo desconexiones entre notificaciones y Web.

library;

import 'canonical_message.dart';

/// Representa un hueco temporal conocido entre dos ventanas observadas.
final class ConversationTimeGap {
  final int fromMs;
  final int toMs;
  final String previousProvider;
  final String nextProvider;

  const ConversationTimeGap({
    required this.fromMs,
    required this.toMs,
    required this.previousProvider,
    required this.nextProvider,
  });

  int get durationMs => (toMs - fromMs).clamp(0, 1 << 62);
}

/// Resultado consolidado del análisis de cobertura de una conversación.
final class ConversationCoverageReport {
  final List<ConversationCoverage> mergedWindows;
  final List<ConversationTimeGap> interWindowGaps;
  final bool hasLeadingGap;

  const ConversationCoverageReport({
    required this.mergedWindows,
    required this.interWindowGaps,
    required this.hasLeadingGap,
  });

  /// Indica si existe cualquier hueco conocido (al inicio o entre ventanas).
  bool get hasKnownGaps =>
      mergedWindows.isEmpty || hasLeadingGap || interWindowGaps.isNotEmpty;

  /// Resumen compacto para inyectar en el bloque `<CONTEXTO_CANONICO>` del LLM.
  String toPromptSummary() {
    if (mergedWindows.isEmpty) {
      return 'Cobertura: sin ventanas registradas; historial posiblemente incompleto.';
    }
    if (!hasKnownGaps) {
      return 'Cobertura: continua desde el inicio del hilo (${mergedWindows.length} ventana(s)).';
    }
    final parts = <String>[];
    if (hasLeadingGap) {
      parts.add('inicio del chat no observado');
    }
    if (interWindowGaps.isNotEmpty) {
      parts.add('${interWindowGaps.length} hueco(s) temporal(es) intermedio(s)');
    }
    return 'Cobertura: parcial (${parts.join(', ')}).';
  }
}

/// Analizador puro y determinista de cobertura histórica (SOLID - SRP).
final class ConversationCoverageAnalyzer {
  /// Tolerancia máxima en milisegundos para considerar dos ventanas como continuas.
  final int continuityToleranceMs;

  const ConversationCoverageAnalyzer({
    this.continuityToleranceMs = 60000,
  });

  ConversationCoverageReport analyze(List<ConversationCoverage> rawCoverage) {
    final valid = rawCoverage
        .where((c) => c.fromMs > 0 && c.toMs >= c.fromMs)
        .toList();
    if (valid.isEmpty) {
      return const ConversationCoverageReport(
        mergedWindows: [],
        interWindowGaps: [],
        hasLeadingGap: true,
      );
    }

    valid.sort((a, b) {
      final cmp = a.fromMs.compareTo(b.fromMs);
      return cmp != 0 ? cmp : a.toMs.compareTo(b.toMs);
    });

    final merged = <ConversationCoverage>[valid.first];
    final gaps = <ConversationTimeGap>[];

    for (var i = 1; i < valid.length; i++) {
      final current = merged.last;
      final next = valid[i];

      final isContiguous =
          next.fromMs <= current.toMs + continuityToleranceMs && !next.gapBefore;
      if (isContiguous) {
        final mergedTo = next.toMs > current.toMs ? next.toMs : current.toMs;
        merged[merged.length - 1] = ConversationCoverage(
          provider: current.provider == next.provider
              ? current.provider
              : '${current.provider}+${next.provider}',
          fromMs: current.fromMs,
          toMs: mergedTo,
          gapBefore: current.gapBefore,
        );
      } else {
        if (next.fromMs > current.toMs) {
          gaps.add(
            ConversationTimeGap(
              fromMs: current.toMs,
              toMs: next.fromMs,
              previousProvider: current.provider,
              nextProvider: next.provider,
            ),
          );
        }
        merged.add(next);
      }
    }

    return ConversationCoverageReport(
      mergedWindows: List.unmodifiable(merged),
      interWindowGaps: List.unmodifiable(gaps),
      hasLeadingGap: merged.first.gapBefore,
    );
  }
}
