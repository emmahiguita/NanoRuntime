/// QUÉ HACE:
/// Parsea y descompone instrucciones en lenguaje natural en un [UniversalInstructionContract]
/// determinista con sus obligaciones atómicas secuenciales y referencias resueltas.
///
/// CÓMO FUNCIONA:
/// Analiza sintáctica y semánticamente el mensaje. Detecta referencias deícticas con
/// [DeicticReferenceResolver], clasifica el dominio principal (12 áreas) e identifica
/// fases de consulta, mutación de estado y condiciones de alerta.
///
/// POR QUÉ:
/// Garantiza que órdenes compuestas como "revisa el Excel, dime agotados y actualiza"
/// no se traten como simples preguntas de chat ni se abandonen a mitad de ejecución (< 200 líneas).
library;

import '../business/fact_selector.dart' show normalizeText;
import 'deictic_reference_resolver.dart';
import 'universal_instruction_contract.dart';

final class UniversalInstructionParser {
  final DeicticReferenceResolver _referenceResolver;

  const UniversalInstructionParser({
    DeicticReferenceResolver referenceResolver = const DeicticReferenceResolver(),
  }) : _referenceResolver = referenceResolver;

  /// Parsea la instrucción del usuario en un contrato semántico estructurado.
  UniversalInstructionContract parse({
    required String text,
    String? lastLinuxFilePath,
    String? recentTableOrReportPath,
    String? activeProductContext,
  }) {
    final clean = text.trim();
    final norm = normalizeText(clean);
    final refs = _referenceResolver.resolve(
      text: clean,
      lastLinuxFilePath: lastLinuxFilePath,
      recentTableOrReportPath: recentTableOrReportPath,
      activeProductContext: activeProductContext,
    );

    final domain = _classifyDomain(norm, refs);
    final obligations = _extractObligations(clean, norm, refs, domain);
    final mode = _determineExecutionMode(obligations);

    return UniversalInstructionContract(
      rawInstruction: clean,
      domain: domain,
      executionMode: mode,
      primaryGoal: _summarizeGoal(clean, obligations),
      deicticReferences: refs,
      obligations: obligations,
    );
  }

  static InstructionDomain _classifyDomain(String norm, List<DeicticReference> refs) {
    if (norm.contains('excel') || norm.contains('csv') || norm.contains('tabla') ||
        norm.contains('columna') || norm.contains('fila') || norm.contains('reporte')) {
      return InstructionDomain.dataStudio;
    }
    if (norm.contains('catalogo') || norm.contains('precio') || norm.contains('producto') ||
        norm.contains('pedido') || norm.contains('agotado') || norm.contains('stock')) {
      return InstructionDomain.business;
    }
    if (norm.contains('bash') || norm.contains('terminal') || norm.contains('script') ||
        norm.contains('proceso') || norm.contains('carpeta') || norm.contains('directorio')) {
      return InstructionDomain.terminal;
    }
    if (norm.contains('busca en internet') || norm.contains('navega') || norm.contains('web') ||
        norm.contains('pagina') || norm.contains('link') || norm.contains('url')) {
      return InstructionDomain.browser;
    }
    if (norm.contains('abre la app') || norm.contains('pantalla') || norm.contains('permiso') ||
        norm.contains('ajustes') || norm.contains('configuracion')) {
      return InstructionDomain.android;
    }
    if (norm.contains('cada') || norm.contains('programa') || norm.contains('automatiza') ||
        norm.contains('cuando') || norm.contains('siempre que')) {
      return InstructionDomain.automations;
    }
    return InstructionDomain.chat;
  }

  static List<UniversalObligation> _extractObligations(
    String raw,
    String norm,
    List<DeicticReference> refs,
    InstructionDomain domain,
  ) {
    final list = <UniversalObligation>[];
    var phaseSeq = 1;

    // Fase 1: Descubrimiento o lectura de datos si hay referencia o mención
    final hasReadIntent = norm.contains('revisa') || norm.contains('lee') ||
        norm.contains('mira') || norm.contains('busca') || norm.contains('dime') ||
        norm.contains('cuales');
    if (hasReadIntent || refs.isNotEmpty) {
      final refTarget = refs.isNotEmpty ? refs.first.resolvedValue ?? refs.first.phrase : '';
      list.add(UniversalObligation(
        id: 'obl_${phaseSeq++}',
        title: 'Inspeccionar fuente de datos',
        phase: ObligationPhase.readQuery,
        actionKind: ObligationActionKind.inspectData,
        targetEntity: refTarget,
      ));
    }

    // Fase 2: Mutación o actualización de estado si se solicita
    final hasMutationIntent = norm.contains('actualiza') || norm.contains('modifica') ||
        norm.contains('cambia') || norm.contains('guarda') || norm.contains('crea') ||
        norm.contains('elimina') || norm.contains('borra');
    if (hasMutationIntent) {
      final isCatalog = norm.contains('catalogo') || norm.contains('producto') || norm.contains('stock');
      list.add(UniversalObligation(
        id: 'obl_${phaseSeq++}',
        title: isCatalog ? 'Actualizar catálogo comercial' : 'Modificar estado persistente',
        phase: ObligationPhase.mutation,
        actionKind: ObligationActionKind.updateState,
        requiresAuthorization: true,
      ));
    }

    // Fase 3: Verificación de anomalías o condiciones de alerta
    final hasAlertIntent = norm.contains('avisame') || norm.contains('alerta') ||
        norm.contains('raro') || norm.contains('inconsistencia') || norm.contains('si hay');
    if (hasAlertIntent) {
      list.add(UniversalObligation(
        id: 'obl_${phaseSeq++}',
        title: 'Verificar alertas e inconsistencias',
        phase: ObligationPhase.anomalyVerification,
        actionKind: ObligationActionKind.verifyCondition,
      ));
    }

    // Si no se extrajeron fases estructuradas, se asigna una obligación general de respuesta
    if (list.isEmpty) {
      list.add(const UniversalObligation(
        id: 'obl_1',
        title: 'Responder consulta',
        phase: ObligationPhase.reporting,
        actionKind: ObligationActionKind.notifyUser,
      ));
    }

    return list;
  }

  static InstructionExecutionMode _determineExecutionMode(List<UniversalObligation> obls) {
    final hasAction = obls.any((o) =>
        o.phase == ObligationPhase.readQuery ||
        o.phase == ObligationPhase.mutation ||
        o.phase == ObligationPhase.anomalyVerification);
    if (!hasAction) return InstructionExecutionMode.conversationalOnly;
    return InstructionExecutionMode.hybrid;
  }

  static String _summarizeGoal(String raw, List<UniversalObligation> obls) {
    if (raw.length <= 60) return raw;
    final titles = obls.map((o) => o.title).join(', ');
    return 'Ejecutar: $titles';
  }
}
