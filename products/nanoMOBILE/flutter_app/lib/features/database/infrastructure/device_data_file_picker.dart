// QUÉ: adapta FilePicker a una ruta de fuente tabular aceptada.
// CÓMO: limita extensiones y retorna null cuando el usuario cancela.
// POR QUÉ: la aplicación no debe depender directamente del plugin de UI.

import 'package:file_picker/file_picker.dart';

final class DeviceDataFilePicker {
  const DeviceDataFilePicker();

  Future<String?> pick() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const [
        'csv',
        'tsv',
        'txt',
        'xlsx',
        'sqlite',
        'sqlite3',
        'db',
      ],
    );
    return result?.files.firstOrNull?.path;
  }
}
