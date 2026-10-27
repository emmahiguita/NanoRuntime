part of 'nanoshell_linux_fs_operations.dart';

/// Operaciones linux_fs_read: verifica rutas y conserva los resultados reales.
mixin _LinuxFsRead on _LinuxFsState {
  Future<LinuxActionResult<List<LinuxFileEntry>>> listFiles(
    String path, {
    bool recursive = false,
    Duration? timeout,
  }) async {
    final started = DateTime.now();
    // stat usa un contrato fijo: no depende de idioma, columnas de ls ni espacios del nombre.
    // El separador de registros conserva saltos de línea habituales en nombres.
    final res = await _binExecutor.toybox([
      'find',
      path,
      '-mindepth',
      '1',
      if (!recursive) ...['-maxdepth', '1'],
      '-exec',
      'stat',
      '-c',
      '%f|%s|%a|%n\u001e',
      '{}',
      '+',
    ], timeout: timeout);
    final entries = <LinuxFileEntry>[];
    if (res.exitCode == 0) {
      for (final raw in res.stdout.split('\u001e')) {
        final record = raw.replaceFirst(RegExp(r'^\r?\n'), '');
        final match = RegExp(
          r'^([0-9a-fA-F]+)\|(\d+)\|(\d+)\|([\s\S]*)$',
        ).firstMatch(record);
        if (match == null) continue;
        final mode = int.tryParse(match[1]!, radix: 16) ?? 0;
        final name = match[4]!;
        entries.add(
          LinuxFileEntry(
            path: name,
            name: name.split('/').last,
            type: switch (mode & 0xf000) {
              0x4000 => LinuxFileType.directory,
              0x8000 => LinuxFileType.file,
              0xa000 => LinuxFileType.symlink,
              _ => LinuxFileType.unknown,
            },
            sizeBytes: int.tryParse(match[2]!) ?? 0,
            permissions: match[3]!,
          ),
        );
      }
    }

    return LinuxActionResult(
      data: entries,
      exitCode: res.exitCode,
      stdout: res.stdout,
      stderr: res.stderr,
      duration: DateTime.now().difference(started),
      verification: res.exitCode == 0
          ? LinuxVerificationDetail.satisfied('fs_listed', 'Contenido listado.')
          : LinuxVerificationDetail.failed('fs_listed', res.stderr),
    );
  }

  Future<LinuxActionResult<String>> readFile(
    String path, {
    int? maxBytes,
    Duration? timeout,
  }) async {
    final started = DateTime.now();
    final List<String> args = (maxBytes != null && maxBytes > 0)
        ? ['head', '-c', '$maxBytes', path]
        : ['cat', path];
    final res = await _binExecutor.toybox(args, timeout: timeout);

    return LinuxActionResult(
      data: res.exitCode == 0 ? res.stdout : null,
      exitCode: res.exitCode,
      stdout: res.stdout,
      stderr: res.stderr,
      duration: DateTime.now().difference(started),
      verification: res.exitCode == 0
          ? LinuxVerificationDetail.satisfied(
              'file_read',
              'Lectura completada.',
            )
          : LinuxVerificationDetail.failed('file_read', res.stderr),
    );
  }

  Future<LinuxActionResult<LinuxFileEntry>> statPath(
    String path, {
    Duration? timeout,
  }) async {
    final started = DateTime.now();
    final res = await _binExecutor.toybox([
      'stat',
      '-c',
      '%s|%a|%F',
      path,
    ], timeout: timeout);

    LinuxFileEntry? entry;
    if (res.exitCode == 0) {
      final parts = res.stdout.trim().split('|');
      entry = LinuxFileEntry(
        path: path,
        name: path.split('/').last,
        type: parts.length > 2 && parts[2].toLowerCase().contains('directory')
            ? LinuxFileType.directory
            : LinuxFileType.file,
        sizeBytes: parts.isNotEmpty ? (int.tryParse(parts[0]) ?? 0) : 0,
        permissions: parts.length > 1 ? parts[1] : '',
      );
    }

    return LinuxActionResult(
      data: entry,
      exitCode: res.exitCode,
      stdout: res.stdout,
      stderr: res.stderr,
      duration: DateTime.now().difference(started),
      verification: res.exitCode == 0
          ? LinuxVerificationDetail.satisfied('stat_ok', 'Metadatos leídos.')
          : LinuxVerificationDetail.failed('stat_ok', res.stderr),
    );
  }
}
