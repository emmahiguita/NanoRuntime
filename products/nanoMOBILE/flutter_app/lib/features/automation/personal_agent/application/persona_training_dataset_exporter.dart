// QUÉ HACE: exporta ejemplos verificados a JSONL de mensajes conversacionales.
// CÓMO: recorre el repositorio por páginas y elimina pares duplicados normalizados.
// POR QUÉ: prepara datos auditables para ajuste externo sin afirmar que entrena el modelo.
import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../domain/persona_example.dart';
import 'persona_repository.dart';
import 'personal_learning_text.dart';

final class PersonaTrainingDatasetExport {
  const PersonaTrainingDatasetExport(this.file, this.exampleCount);

  final File file;
  final int exampleCount;
}

final class PersonaTrainingDatasetExporter {
  const PersonaTrainingDatasetExporter();

  static const _pageSize = 100;

  /// Incluye únicamente contenido confirmado y escribe a caché temporal para compartir.
  Future<PersonaTrainingDatasetExport> export({
    required PersonaRepository repository,
    required String scopeKey,
  }) async {
    final cache = await getTemporaryDirectory();
    final folder = await Directory(
      '${cache.path}/nano_training_exports',
    ).create(recursive: true);
    final file = File(
      '${folder.path}/nano_verified_${DateTime.now().microsecondsSinceEpoch}.jsonl',
    );
    final sink = file.openWrite();
    final seenPairs = <String>{};
    var count = 0;
    var offset = 0;

    try {
      while (true) {
        final page = await repository.listExamples(
          limit: _pageSize,
          offset: offset,
          scopeKey: scopeKey,
        );
        for (final example in page) {
          count += _writeExample(sink, seenPairs, example);
        }
        offset += page.length;
        if (page.length < _pageSize) break;
      }
      await sink.flush();
    } catch (_) {
      await sink.close();
      if (await file.exists()) await file.delete();
      rethrow;
    }
    await sink.close();
    if (count == 0) await file.delete();
    return PersonaTrainingDatasetExport(file, count);
  }

  /// Descarta pendientes, plantillas, frases solo de estilo y repeticiones.
  int _writeExample(IOSink sink, Set<String> seen, PersonaExample example) {
    if (!example.enabled ||
        !example.ownerVerified ||
        !example.isPaired ||
        example.isTemplate ||
        example.isStyleOnly) {
      return 0;
    }
    final prompt = example.incomingText.trim();
    final options = example.responseOptions
        .where((option) => option.enabled)
        .map((option) => option.text.trim())
        .where((text) => text.isNotEmpty);
    final answers = options.isEmpty ? [example.body.trim()] : options;
    var written = 0;
    for (final answer in answers) {
      final key =
          '${normalizePersonalLearningText(prompt)}\u0000'
          '${normalizePersonalLearningText(answer)}';
      if (prompt.isEmpty || answer.isEmpty || !seen.add(key)) continue;
      sink.writeln(
        jsonEncode({
          'messages': [
            {'role': 'user', 'content': prompt},
            {'role': 'assistant', 'content': answer},
          ],
        }),
      );
      written++;
    }
    return written;
  }
}
