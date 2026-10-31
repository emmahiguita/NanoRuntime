import 'dart:io';

/// Conserva como máximo 32 capturas temporales propias. Las evidencias de QA
/// ya copiadas a su informe y los historiales importados nunca se eliminan aquí.
Future<void> trimOwlScreens(Directory directory) async {
  final files = await directory
      .list(followLinks: false)
      .where(
        (entry) =>
            entry is File &&
            RegExp(
              r'/screen_\d+\.png$',
            ).hasMatch(entry.path.replaceAll('\\', '/')),
      )
      .cast<File>()
      .toList();
  files.sort((a, b) => a.path.compareTo(b.path));
  for (final file in files.take((files.length - 31).clamp(0, files.length))) {
    await file.delete();
  }
}
