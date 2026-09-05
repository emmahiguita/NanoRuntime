import 'dart:io';

import 'package:crypto/crypto.dart';

/// SHA256 de un archivo grande SIN cargarlo completo en RAM.
///
/// TER-32: patrón streaming — File.openRead() alimenta la conversión
/// chunked de package:crypto con memoria constante. Antes (readAsBytes +
/// sha256.convert síncrono en el isolate principal) UbuntuDistribution
/// (35MB) y KaliManager (~200MB) congelaban la UI y disparaban picos de
/// RAM en hardware barato. Fuente única para ambas instalaciones de
/// rootfs (fail-closed de integridad).
Future<String> sha256File(String path) async {
  final digest = await sha256.bind(File(path).openRead()).first;
  return digest.toString();
}
