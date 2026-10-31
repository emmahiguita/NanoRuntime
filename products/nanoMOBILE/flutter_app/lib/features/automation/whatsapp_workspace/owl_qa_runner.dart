import 'dart:convert';
import 'dart:io';
import '../engine/execution/agent_executor.dart';
import '../engine/execution/handlers/whatsapp_open_verifier.dart';
import 'owl_workspace_store.dart';
import 'owl_qa_scenario.dart';
import 'owl_screen_evidence.dart';
import 'owl_qa_report.dart';

/// QA de navegación real. Reutiliza comandos del motor, instantáneas Android
/// y SQLite. No genera mensajes de prueba ni simula clics o resultados.
class OwlQaRunner {
  OwlQaRunner(this.store, this.executor);
  final OwlWorkspaceStore store;
  final AgentExecutor executor;

  /// Preparar solo persiste contrato; la ejecución exige otra orden explícita.
  Future<String> prepare(String? contact) async {
    final scenario = OwlQaScenario.whatsApp(contact: contact);
    final folder = await store.folder('qa', scenario.id);
    await store.jsonFile(folder, 'scenario.json', scenario.toJson());
    await store.record('owl_qa_scenarios_v1', scenario.id, {
      'id': scenario.id,
      'createdAt': DateTime.now().millisecondsSinceEpoch,
    });
    return 'Escenario QA guardado: ${scenario.id}.\n${scenario.steps.map((s) => s['expected']).join('\n')}\n'
        'No se ha ejecutado. Para iniciarlo: «Ejecuta QA de WhatsApp». No envía mensajes.';
  }

  /// Un run tiene ID propio, esperado/observado y capturas reales antes/después.
  /// Fallo, bloqueo, cancelación y evidencia insuficiente nunca equivalen a pasar.
  Future<String> run({
    required Future<String> Function(String) command,
    required bool Function() cancelled,
    required void Function(String) progress,
  }) async {
    final rows =
        (await store.index(
          'owl_qa_scenarios_v1',
        )).values.whereType<Map>().toList()..sort(
          (a, b) => (b['createdAt'] as num).compareTo(a['createdAt'] as num),
        );
    if (rows.isEmpty) {
      throw const FormatException(
        'Prepara primero QA de WhatsApp, con tu contacto si lo deseas.',
      );
    }
    final source = await store.folder('qa', rows.first['id'] as String);
    final scenario = OwlQaScenario.fromJson(
      Map<String, dynamic>.from(
        jsonDecode(await File('${source.path}/scenario.json').readAsString())
            as Map,
      ),
    );
    final runId = 'run_${DateTime.now().microsecondsSinceEpoch}';
    final folder = await store.folder('qa', runId);
    final report = <String, dynamic>{
      'id': runId,
      'scenario': scenario.toJson(),
      'startedAt': DateTime.now().toIso8601String(),
      'state': 'running',
      'steps': <Map<String, dynamic>>[],
    };
    await store.record('owl_qa_runs_v1', runId, {
      'id': runId,
      'state': 'running',
    });
    final results = report['steps'] as List<Map<String, dynamic>>;
    var state = 'passed';
    try {
      if (await executor.snapshot() == null) {
        state = 'blocked';
        throw StateError(
          'Accesibilidad sin respuesta; no se ejecutaron comandos.',
        );
      }
      for (var i = 0; i < scenario.steps.length; i++) {
        if (cancelled()) {
          state = 'cancelled';
          break;
        }
        final step = scenario.steps[i];
        progress('QA WhatsApp: paso ${i + 1}/${scenario.steps.length}');
        final before = await _capture(folder, 'before_$i');
        final output = await command(step['command']!);
        if (cancelled()) {
          state = 'cancelled';
          break;
        }
        for (var poll = 0; poll < 16; poll++) {
          if ((await executor.snapshot())?.package == step['package']) break;
          if (cancelled()) {
            state = 'cancelled';
            break;
          }
          await Future<void>.delayed(const Duration(milliseconds: 150));
        }
        bool? identity;
        if (step['recipient'] != null && state != 'cancelled') {
          identity = (await WhatsAppOpenVerifier(executor).verify(
            step['recipient']!,
            step['package']!,
            cancelled: cancelled,
          )).verified;
        }
        final after = await _capture(folder, 'after_$i');
        final reached = after['package'] == step['package'];
        final captured = before['image'] != null && after['image'] != null;
        final dispatch = _commandFailure(output);
        final outcome = state == 'cancelled'
            ? 'cancelled'
            : dispatch ??
                  (!reached
                      ? 'failed'
                      : identity == false || !captured
                      ? 'unverifiable'
                      : 'passed');
        results.add({
          'step': i + 1,
          'expected': step['expected'],
          'observed': {
            'package': after['package'],
            'recipientVerified': identity,
            'toolOutput': output,
          },
          'state': outcome,
          'before': before,
          'after': after,
        });
        await store.jsonFile(folder, 'report.json', report);
        if (outcome != 'passed') {
          state = outcome;
          break;
        }
      }
    } catch (error) {
      if (state == 'passed') state = 'failed';
      report['error'] = '${error.runtimeType}: $error';
    } finally {
      report['state'] = state;
      report['endedAt'] = DateTime.now().toIso8601String();
      await store.jsonFile(folder, 'report.json', report);
      await writeOwlQaHtml(folder, report);
      await store.record('owl_qa_runs_v1', runId, {
        'id': runId,
        'state': state,
        'scenario': scenario.id,
        'at': DateTime.now().millisecondsSinceEpoch,
      });
    }
    return 'QA: $state. ${results.length}/${scenario.steps.length} pasos registrados.\n'
        'Informe JSON/HTML y evidencias: ${folder.path}. No se enviaron mensajes.';
  }

  /// Un paquete que ya estaba abierto no convierte un comando rechazado en
  /// éxito. Las aserciones pueden confirmar un launch aceptado, no un error.
  String? _commandFailure(String output) {
    if (output.startsWith('[completed]') ||
        output.startsWith('[completedUnverified]')) {
      return null;
    }
    if (output.startsWith('[cancelled]')) return 'cancelled';
    if (RegExp(
      r'^\[(blocked|denied|busy|paused|clarification)\]',
    ).hasMatch(output)) {
      return 'blocked';
    }
    if (RegExp(r'^\[(error|failed)\]').hasMatch(output)) return 'failed';
    return 'unverifiable';
  }

  /// Cada evidencia corresponde a una captura real. Una captura ausente queda
  /// explícita; las imágenes permanentes se copian junto a este informe.
  Future<Map<String, dynamic>> _capture(Directory folder, String label) async {
    final value = await OwlScreenEvidence().capture();
    String? image;
    if (value.imagePath != null) {
      image = '$label.png';
      await File(value.imagePath!).copy('${folder.path}/$image');
    }
    return {
      'at': value.snapshot.hierarchy.capturedAt.toIso8601String(),
      'package': value.snapshot.hierarchy.package,
      'image': image,
      'sha256': value.sha256,
      'screenshotError': value.snapshot.screenshotErrorCode,
      'partialHierarchy': value.snapshot.hierarchy.truncated,
    };
  }
}
