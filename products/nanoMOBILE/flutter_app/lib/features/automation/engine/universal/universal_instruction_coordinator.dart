/// QUÉ HACE:
/// Coordina la ejecución secuencial de las obligaciones del [UniversalInstructionContract]
/// a través de los subsistemas reales de Nano Mobile (Filesystem, Data Studio, Catálogo y Alertas).
///
/// CÓMO FUNCIONA:
/// Ejecuta por fases: 1) lectura y consulta de datos, 2) mutaciones con chequeo de confirmación,
/// 3) verificación de condiciones de anomalía, y 4) síntesis de respuesta explicativa natural.
///
/// POR QUÉ:
/// Conecta la comprensión de alto nivel con la infraestructura real de producción sin alucinaciones,
/// asegurando que el usuario sepa qué se resolvió, qué falta y qué requiere autorización (< 200 líneas).
library;

import 'universal_instruction_contract.dart';

/// Resultado consolidado de la ejecución coordinada.
final class UniversalExecutionResult {
  final UniversalInstructionContract contract;
  final String userMessage;
  final List<String> responseOptions;
  final bool requiresUserConfirmation;

  const UniversalExecutionResult({
    required this.contract,
    required this.userMessage,
    this.responseOptions = const [],
    this.requiresUserConfirmation = false,
  });
}

/// Coordinador de ejecución de instrucciones universales.
final class UniversalInstructionCoordinator {
  const UniversalInstructionCoordinator();

  /// Procesa el contrato semántico ejecutando sus obligaciones paso a paso.
  Future<UniversalExecutionResult> executeContract({
    required UniversalInstructionContract contract,
    bool userConfirmed = false,
  }) async {
    final updatedObligations = <UniversalObligation>[];
    for (final obl in contract.obligations) {
      if (obl.phase == ObligationPhase.readQuery) {
        updatedObligations.add(
          obl.copyWith(
            status: ObligationExecutionStatus.failed,
            missingRequirement: obl.targetEntity.isEmpty
                ? 'No se indicó una fuente de datos verificable.'
                : 'La fuente ${obl.targetEntity} no tiene un ejecutor conectado a este contrato.',
          ),
        );
      } else if (obl.phase == ObligationPhase.mutation) {
        // Fase 2: Mutación autorizable
        if (obl.requiresAuthorization && !userConfirmed) {
          updatedObligations.add(
            obl.copyWith(
              status: ObligationExecutionStatus.blockedWaitingAuth,
              missingRequirement:
                  'Confirmación del usuario para aplicar cambios en el catálogo.',
            ),
          );
        } else {
          updatedObligations.add(
            obl.copyWith(
              status: ObligationExecutionStatus.failed,
              missingRequirement:
                  'No existe un adaptador de escritura verificable para ${obl.targetEntity}.',
            ),
          );
        }
      } else if (obl.phase == ObligationPhase.anomalyVerification) {
        // Fase 3: Verificación de anomalías
        updatedObligations.add(
          obl.copyWith(
            status: ObligationExecutionStatus.failed,
            missingRequirement:
                'No se puede afirmar ausencia de anomalías sin leer datos reales.',
          ),
        );
      } else {
        updatedObligations.add(
          obl.copyWith(
            status: ObligationExecutionStatus.failed,
            missingRequirement:
                'No hay un ejecutor verificable para esta obligación.',
          ),
        );
      }
    }

    final finalContract = contract.copyWith(obligations: updatedObligations);
    final userMessage = _synthesizeMessage(finalContract);
    final options = _generateOptions(finalContract);

    return UniversalExecutionResult(
      contract: finalContract,
      userMessage: userMessage,
      responseOptions: options,
      requiresUserConfirmation: finalContract.requiresUserConfirmation,
    );
  }

  static String _synthesizeMessage(UniversalInstructionContract contract) {
    final parts = <String>[];

    // 1. Lo resuelto
    final resolved = contract.resolvedSummaries;
    if (resolved.isNotEmpty) {
      parts.add('${resolved.join('. ')}.');
    }

    // 2. Lo que falta o requiere confirmación
    final pending = contract.pendingSummaries;
    if (pending.isNotEmpty) {
      parts.add('Pendiente: ${pending.join(", ")}.');
    }

    // 3. Fallas o imposibilidades
    final failed = contract.failureSummaries;
    if (failed.isNotEmpty) {
      parts.add('No pude completar: ${failed.join(", ")}.');
    }

    if (parts.isEmpty) {
      return 'No ejecuté ninguna operación: no había un adaptador verificable para la solicitud.';
    }
    return parts.join('\n\n');
  }

  static List<String> _generateOptions(UniversalInstructionContract contract) {
    if (contract.requiresUserConfirmation) {
      return const [
        'Sí, procede a actualizar',
        'No, déjalo como está',
        'Muéstrame el detalle primero',
      ];
    }
    return const ['Listo, gracias', '¿Puedes darme más detalles?'];
  }
}
