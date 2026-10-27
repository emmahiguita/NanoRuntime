import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';

/// QUÉ: valida destinos de lectura web automática de mensajes.
/// CÓMO: solo HTTP(S), sin credenciales y con DNS público en cada redirección.
/// POR QUÉ: un enlace de chat no debe acceder a localhost ni a la red privada.
abstract final class PublicLinkTarget {
  /// Valida también la dirección usada por el socket: evita otro DNS privado
  /// entre la comprobación de la URL y la conexión (DNS rebinding).
  static http.Client client() {
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 3);
    client.connectionFactory = (uri, proxyHost, proxyPort) async {
      if (!validUri(uri) || proxyHost != null) {
        throw const SocketException('Destino no permitido');
      }
      final addresses = await InternetAddress.lookup(
        uri.host,
      ).timeout(const Duration(seconds: 2));
      if (addresses.isEmpty || !addresses.every(publicAddress)) {
        throw const SocketException('Dirección privada');
      }
      return Socket.startConnect(addresses.first, uri.port);
    };
    return IOClient(client);
  }

  static bool validUri(Uri uri) =>
      const {'http', 'https'}.contains(uri.scheme) &&
      uri.userInfo.isEmpty &&
      uri.host.contains('.') &&
      (!uri.hasPort || const {80, 443}.contains(uri.port));

  static bool publicAddress(InternetAddress address) {
    if (address.isLoopback || address.isLinkLocal || address.isMulticast) {
      return false;
    }
    final bytes = address.rawAddress;
    if (bytes.length == 16) {
      if (bytes.every((b) => b == 0) || (bytes[0] & 0xfe) == 0xfc) return false;
      // IPv4-mapped IPv6 debe pasar la misma validación IPv4.
      if (bytes.take(10).every((b) => b == 0) &&
          bytes[10] == 255 &&
          bytes[11] == 255) {
        return publicAddress(InternetAddress.fromRawAddress(bytes.sublist(12)));
      }
      return true;
    }
    final a = bytes[0], b = bytes[1];
    return !(a == 0 ||
        a == 10 ||
        a == 127 ||
        a >= 224 ||
        (a == 169 && b == 254) ||
        (a == 172 && b >= 16 && b <= 31) ||
        (a == 192 && b == 168) ||
        (a == 100 && b >= 64 && b <= 127) ||
        (a == 198 && (b == 18 || b == 19)));
  }

  static Future<bool> resolve(Uri uri) async {
    if (!validUri(uri)) return false;
    final addresses = await InternetAddress.lookup(
      uri.host,
    ).timeout(const Duration(seconds: 2));
    return addresses.isNotEmpty && addresses.every(publicAddress);
  }
}
