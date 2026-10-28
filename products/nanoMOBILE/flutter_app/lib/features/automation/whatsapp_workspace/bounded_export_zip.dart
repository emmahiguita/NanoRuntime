import 'dart:io' as io;
import 'dart:typed_data';
import 'package:archive/archive.dart';

/// Lee solo un TXT sin extraer archivos. La descompresión tiene límite real
/// de salida, además del tamaño declarado, para evitar ZIP bombs en el móvil.
List<int> readExportZip(List<int> bytes) {
  final directory = ZipDirectory.read(InputStream(bytes));
  if (directory.fileHeaders.length > 512)
    throw const FormatException('Demasiados archivos en el ZIP.');
  final entries = directory.fileHeaders
      .where((h) => h.filename.toLowerCase().endsWith('.txt'))
      .toList();
  if (entries.length != 1)
    throw const FormatException('El ZIP debe contener un único TXT.');
  final header = entries.single;
  if ((((header.externalFileAttributes ?? 0) >> 16) & 0xf000) == 0xa000 ||
      (header.uncompressedSize ?? 0) > 8 * 1024 * 1024) {
    throw const FormatException('TXT enlazado o demasiado grande.');
  }
  final file = header.file!;
  final raw = file.rawContent?.toUint8List();
  if (raw == null) throw const FormatException('ZIP sin contenido legible.');
  final sink = _BoundedBytes();
  if (file.compressionMethod == ZipFile.zipCompressionStore) {
    sink.add(raw);
  } else if (file.compressionMethod == ZipFile.zipCompressionDeflate) {
    final decoder = io.ZLibDecoder(raw: true).startChunkedConversion(sink);
    try {
      for (var i = 0; i < raw.length; i += 8192) {
        decoder.add(raw.sublist(i, (i + 8192).clamp(0, raw.length)));
      }
    } finally {
      decoder.close();
    }
  } else {
    throw const FormatException(
      'Compresión ZIP no compatible; exporta sin archivos multimedia.',
    );
  }
  final result = sink.bytes.takeBytes();
  if (result.length != header.uncompressedSize ||
      getCrc32(result) != header.crc32) {
    throw const FormatException('El TXT del ZIP está incompleto o dañado.');
  }
  return result;
}

/// Detiene el codec al superar el máximo, sin reservar el tamaño anunciado.
class _BoundedBytes implements Sink<List<int>> {
  final bytes = BytesBuilder(copy: false);
  @override
  void add(List<int> data) {
    if (bytes.length + data.length > 8 * 1024 * 1024) {
      throw const FormatException('La salida real del ZIP supera 8 MB.');
    }
    bytes.add(data);
  }

  @override
  void close() {}
}
