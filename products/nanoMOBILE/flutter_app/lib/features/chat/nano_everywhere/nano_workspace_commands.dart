import 'dart:convert';
import 'dart:async';
import '../../automation/whatsapp_workspace/owl_workspace_store.dart';
import '../../automation/whatsapp_workspace/owl_export_library.dart';
import '../../automation/whatsapp_workspace/owl_export_analysis.dart';
import '../../automation/whatsapp_workspace/owl_qa_runner.dart';
import '../../automation/whatsapp_workspace/owl_report_export.dart';
import '../../automation/whatsapp_workspace/owl_screen_evidence.dart';
import '../../automation/engine/planning/owl_workspace_input.dart';
import '../../automation/engine/execution/agent_executor.dart';
import 'nano_ai_models.dart';

/// Puerta de las capacidades locales del búho. Reutiliza almacenamiento,
/// ejecutor y modelo existentes; preparar QA nunca ejecuta un escenario.
class NanoWorkspaceCommands {
  NanoWorkspaceCommands({
    required this.executor,
    required this.localProvider,
    required this.progress,
    required this.modelKey,
    required this.resolveContact,
  });
  final AgentExecutor Function() executor;
  final NanoProvider Function() localProvider;
  final void Function(String) progress;
  final String Function() modelKey;
  final Future<String?> Function(String) resolveContact;
  final store = OwlWorkspaceStore();
  NanoProvider? _ownedModel;

  /// Cancela solo la generación adquirida por este comando, no todo el motor.
  void cancel() {
    unawaited(_ownedModel?.cancel?.call());
  }

  Future<String?> execute(
    String text, {
    required Future<String> Function(String) command,
    required bool Function() cancelled,
  }) async {
    final kind = OwlWorkspaceInput.kind(text);
    if (kind == null) return null;
    if (cancelled()) return '[cancelled] Solicitud detenida.';
    switch (kind) {
      case 'screen':
        return '[completed] ${await OwlScreenEvidence().read()}';
      case 'import':
        return OwlExportLibrary(store).pickAndImport();
      case 'analyze':
        final model = localProvider();
        if (model.kind != NanoProviderKind.local ||
            model.isOnDevice?.call() != true ||
            model.ask == null ||
            model.isReady?.call() != true) {
          return '[blocked] Carga un modelo local compatible para analizar el historial. No se enviará a la web.';
        }
        _ownedModel = model;
        final selectedModel = modelKey();
        try {
          return await OwlExportAnalysis(OwlExportLibrary(store), store).run(
            ask: (prompt) async {
              if (model.isOnDevice?.call() != true ||
                  modelKey() != selectedModel) {
                throw StateError('El modelo cambió; análisis detenido.');
              }
              final result = await model.ask!(prompt);
              if (model.isOnDevice?.call() != true ||
                  modelKey() != selectedModel) {
                throw StateError(
                  'El modelo cambió; no se mezcló el resultado.',
                );
              }
              return result;
            },
            cancelled: cancelled,
            progress: progress,
            modelKey: selectedModel,
          );
        } finally {
          _ownedModel = null;
        }
      case 'prepare_qa':
        final match = RegExp(
          r'^prepara(?:r)? qa de whatsapp(?: con (.+))?$',
          caseSensitive: false,
        ).firstMatch(text.trim());
        var contact = match?.group(1)?.trim();
        if (contact?.startsWith('"') == true) {
          contact = jsonDecode(contact!) as String;
        }
        if (contact != null && contact.isNotEmpty) {
          contact = await resolveContact(contact);
          if (contact == null) {
            return '[clarification] Destinatario ambiguo o no encontrado. Usa el número internacional o @usuario exacto.';
          }
        }
        if (cancelled()) return '[cancelled] No se guardó el escenario.';
        return OwlQaRunner(store, executor()).prepare(contact);
      case 'run_qa':
        return OwlQaRunner(
          store,
          executor(),
        ).run(command: command, cancelled: cancelled, progress: progress);
      case 'export_qa':
        return exportLatestQa(store);
      case 'history_qa':
        final rows = await store.index('owl_qa_runs_v1');
        return rows.isEmpty
            ? 'Todavía no hay runs QA.'
            : rows.values
                  .whereType<Map>()
                  .map(
                    (r) =>
                        '${r['id']} · ${r['state'] == 'running' ? 'interrumpido o aún en curso; no aprobado' : r['state']}',
                  )
                  .join('\n');
    }
    return null;
  }
}
