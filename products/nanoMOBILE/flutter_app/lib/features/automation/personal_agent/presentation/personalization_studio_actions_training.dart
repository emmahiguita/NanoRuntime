part of 'personalization_studio_screen.dart';

/// QUÉ: exporta diálogos verificados desde el Estudio Personal.
/// CÓMO: confirma privacidad, genera JSONL y abre el selector del sistema.
/// POR QUÉ: la persona decide cuándo compartir datos que podrían ser privados.
extension _PersonalizationStudioTrainingActions
    on _PersonalizationStudioScreenState {
  Future<void> _exportTrainingDataset() async {
    if (!mounted || _working) return;
    final confirmed = await _confirm(
      'Exportar datos para ajuste',
      'Se incluirán pares activados y verificados del ámbito "$_scope". '
          'El archivo contiene texto conversacional y podría incluir datos personales. '
          'Se abrirá el selector del sistema para compartirlo. Exportar no entrena '
          'un modelo por sí solo.',
    );
    if (!confirmed || !mounted) return;

    _safeSetState(() => _busy = true);
    try {
      final result = await const PersonaTrainingDatasetExporter().export(
        repository: _repo,
        scopeKey: _scope,
      );
      if (result.exampleCount == 0) {
        _notice('No hay diálogos verificados para exportar en este ámbito.');
        return;
      }
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(result.file.path)],
          subject: 'Datos conversacionales verificados de Nano',
          text: '${result.exampleCount} ejemplos aprobados en formato JSONL.',
        ),
      );
    } catch (error) {
      _notice('No se pudo preparar la exportación (${error.runtimeType}).');
    } finally {
      _safeSetState(() => _busy = false);
    }
  }
}
