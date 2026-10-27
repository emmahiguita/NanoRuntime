import 'package:flutter/material.dart';

import '../../application/models_notifier.dart';
import '../../domain/detected_model.dart';
import '../../data/hugging_face_gguf_import_service.dart';

Future<DetectedModel?> showHuggingFaceModelImportDialog({
  required BuildContext context,
  required ModelsNotifier notifier,
}) {
  final urlController = TextEditingController();
  var candidates = <HuggingFaceGgufArtifact>[];
  HuggingFaceGgufArtifact? selected;
  var busy = false;
  var progress = 0.0;
  String? error;

  return showDialog<DetectedModel>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        title: const Text('Importar desde Hugging Face'),
        content: SizedBox(
          width: 460,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Pega el enlace del repositorio o de un archivo. Nano buscará archivos GGUF, comprobará su checksum y los guardará en la carpeta local de modelos.',
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: urlController,
                  enabled: !busy,
                  keyboardType: TextInputType.url,
                  textInputAction: TextInputAction.done,
                  autocorrect: false,
                  decoration: const InputDecoration(
                    labelText: 'Enlace de Hugging Face',
                    hintText: 'https://huggingface.co/usuario/modelo',
                    prefixIcon: Icon(Icons.link_rounded),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: busy
                      ? null
                      : () async {
                          setState(() {
                            busy = true;
                            error = null;
                            candidates = [];
                            selected = null;
                          });
                          try {
                            final found = await notifier.inspectHuggingFaceLink(
                              urlController.text,
                            );
                            if (!context.mounted) return;
                            setState(() {
                              candidates = found;
                              selected = found.first;
                            });
                          } catch (exception) {
                            if (context.mounted) {
                              setState(() => error = '$exception');
                            }
                          } finally {
                            if (context.mounted) setState(() => busy = false);
                          }
                        },
                  icon: const Icon(Icons.search_rounded),
                  label: const Text('Buscar archivos compatibles'),
                ),
                if (candidates.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  DropdownButtonFormField<HuggingFaceGgufArtifact>(
                    initialValue: selected,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Archivo GGUF del repositorio',
                      border: OutlineInputBorder(),
                    ),
                    items: candidates
                        .map(
                          (artifact) => DropdownMenuItem(
                            value: artifact,
                            child: Text(
                              '${artifact.filePath}  ·  ${_formatSize(artifact.sizeBytes)}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: busy
                        ? null
                        : (artifact) => setState(() => selected = artifact),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'La importación confirma el formato GGUF, no identifica por sí sola si el modelo sirve para chat, visión u otra tarea. Esa compatibilidad se muestra como no verificada hasta cargarlo.',
                    style: TextStyle(fontSize: 12),
                  ),
                ],
                if (busy && selected != null) ...[
                  const SizedBox(height: 14),
                  LinearProgressIndicator(
                    value: progress > 0 ? progress : null,
                  ),
                  const SizedBox(height: 5),
                  Text(
                    progress > 0
                        ? 'Descargando ${(progress * 100).round()}%'
                        : 'Consultando Hugging Face…',
                  ),
                ],
                if (error != null) ...[
                  const SizedBox(height: 10),
                  Text(
                    error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: busy ? null : () => Navigator.pop(dialogContext),
            child: const Text('Cancelar'),
          ),
          FilledButton.icon(
            onPressed: busy || selected == null
                ? null
                : () async {
                    setState(() {
                      busy = true;
                      progress = 0;
                      error = null;
                    });
                    try {
                      final model = await notifier.importHuggingFaceArtifact(
                        selected!,
                        onProgress: (value) {
                          if (context.mounted) setState(() => progress = value);
                        },
                      );
                      if (dialogContext.mounted) {
                        Navigator.pop(dialogContext, model);
                      }
                    } catch (exception) {
                      if (context.mounted) {
                        setState(() {
                          busy = false;
                          error = '$exception';
                        });
                      }
                    }
                  },
            icon: const Icon(Icons.download_rounded),
            label: const Text('Descargar e importar'),
          ),
        ],
      ),
    ),
  ).whenComplete(urlController.dispose);
}

String _formatSize(int bytes) {
  if (bytes < 0) return 'tamaño desconocido';
  if (bytes >= 1024 * 1024 * 1024) {
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }
  return '${(bytes / (1024 * 1024)).toStringAsFixed(0)} MB';
}
