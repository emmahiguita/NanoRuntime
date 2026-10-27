import 'dart:io';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';

/// Lee el archivo seleccionado por tramos y cancela al superar el límite.
/// Evita cargar un vídeo entero antes de comprobar su tamaño.
Future<PlatformFile?> pickBoundedMetaAttachment() async {
  const maximum = 6 * 1024 * 1024;
  final result = await FilePicker.pickFiles(
    type: FileType.custom,
    allowedExtensions: [
      'pdf',
      'jpg',
      'jpeg',
      'png',
      'webp',
      'mp4',
      'mp3',
      'ogg',
      'm4a',
    ],
    withData: false,
    withReadStream: true,
  );
  if (result == null) return null;
  final file = result.files.single;
  if (file.size > maximum || file.readStream == null) {
    throw const FormatException('Selecciona un archivo de hasta 6 MB.');
  }
  final bytes = BytesBuilder(copy: false);
  await for (final chunk in file.readStream!) {
    if (bytes.length + chunk.length > maximum) {
      throw const FormatException('El archivo supera 6 MB.');
    }
    bytes.add(chunk);
  }
  return PlatformFile(
    name: file.name,
    size: bytes.length,
    bytes: bytes.takeBytes(),
  );
}

/// Lee un documento de la biblioteca privada con el mismo límite de memoria.
Future<PlatformFile> readBoundedMetaLibraryFile(File file, String name) async {
  const maximum = 6 * 1024 * 1024;
  if (await file.length() > maximum) {
    throw const FormatException('Archivo mayor de 6 MB.');
  }
  final bytes = BytesBuilder(copy: false);
  await for (final chunk in file.openRead()) {
    if (bytes.length + chunk.length > maximum) {
      throw const FormatException('Archivo mayor de 6 MB.');
    }
    bytes.add(chunk);
  }
  return PlatformFile(name: name, size: bytes.length, bytes: bytes.takeBytes());
}
