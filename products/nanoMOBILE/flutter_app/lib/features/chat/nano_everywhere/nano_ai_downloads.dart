part of 'nano_ai_controller.dart';

/// Descarga con dueño exclusivo; cancelar libera el lote y no publica éxitos tardíos.
extension NanoAiDownloads on NanoAiController {
  Future<int> downloadMedia(List<NanoMediaResource> items) async {
    if (_disposed || items.isEmpty || isBusy) return 0;
    _turnActive = true;
    final token = ++_requestId;
    activity = NanoActivity.acting;
    status = 'Descargando ${items.length} archivos…';
    _emit();
    try {
      final downloaded = await _mediaDownloader.downloadBatch(items);
      if (!_current(token)) return 0;
      activity = downloaded.isNotEmpty
          ? NanoActivity.success
          : NanoActivity.error;
      status = downloaded.isNotEmpty
          ? 'Guardados ${downloaded.length}/${items.length} en Download/NanoAI/'
          : 'No se confirmó ninguna descarga.';
      return downloaded.length;
    } on Object {
      if (_current(token)) {
        activity = NanoActivity.error;
        status = 'No se pudo guardar el archivo.';
      }
      return 0;
    } finally {
      _turnActive = false;
      _emit();
    }
  }
}
