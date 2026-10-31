import 'dart:io';

/// Códigos de decisión y seguridad emitidos por el Firewall de Nano Browser.
enum FirewallSecurityCode {
  allowed('ALLOWED'),
  privateNetworkBlocked('PRIVATE_NETWORK_BLOCKED'),
  loopbackBlocked('LOOPBACK_BLOCKED'),
  unsafePortBlocked('UNSAFE_PORT_BLOCKED'),
  mixedContentBlocked('MIXED_CONTENT_BLOCKED'),
  blockedScheme('BLOCKED_SCHEME'),
  customScheme('CUSTOM_SCHEME'),
  externalAppRequest('EXTERNAL_APP_REQUEST'),
  unsupportedScheme('UNSUPPORTED_SCHEME');

  const FirewallSecurityCode(this.code);
  final String code;
}

/// Resultado de inspección del firewall con código semántico y motivo claro.
class FirewallEvaluation {
  const FirewallEvaluation({
    required this.code,
    required this.isAllowed,
    this.reason,
  });

  final FirewallSecurityCode code;
  final bool isAllowed;
  final String? reason;
}

/// QUÉ HACE:
/// Inspecciona hosts y direcciones IP (IPv4 e IPv6) para detectar loopback local,
/// redes privadas RFC1918, CGNAT, puertos internos y direcciones link-local/multicast.
///
/// CÓMO FUNCIONA:
/// Parsea literales IP con `InternetAddress.tryParse` y valida octetos contra
/// `127.0.0.0/8`, `0.0.0.0/8`, `10.0.0.0/8`, `172.16.0.0/12`, `192.168.0.0/16`,
/// `169.254.0.0/16`, `100.64.0.0/10` y `fc00::/7`.
///
/// POR QUÉ:
/// Aísla la lógica de detección anti-SSRF fuera de `BrowserSecurityFirewall` para
/// mantener cada módulo por debajo de 200 líneas (SRP).
class BrowserNetworkAddressGuard {
  const BrowserNetworkAddressGuard._();

  static const Set<int> blockedInternalPorts = {
    8080,
    8800,
    5900,
    5901,
    22,
    2222,
    5037,
  };

  /// Evalúa un host y puerto HTTP/HTTPS contra las reglas anti-SSRF.
  static FirewallEvaluation evaluateHttpTarget(Uri uri) {
    final host = uri.host;
    if (host.isEmpty) {
      return const FirewallEvaluation(
        code: FirewallSecurityCode.unsupportedScheme,
        isAllowed: false,
        reason: 'Host vacío no permitido.',
      );
    }
    if (isLoopbackHost(host)) {
      return const FirewallEvaluation(
        code: FirewallSecurityCode.loopbackBlocked,
        isAllowed: false,
        reason: 'Dirección loopback local bloqueada por seguridad.',
      );
    }
    if (isPrivateNetworkHost(host)) {
      return const FirewallEvaluation(
        code: FirewallSecurityCode.privateNetworkBlocked,
        isAllowed: false,
        reason: 'Dirección de red privada bloqueada por seguridad (SSRF).',
      );
    }
    if (uri.hasPort && blockedInternalPorts.contains(uri.port)) {
      return const FirewallEvaluation(
        code: FirewallSecurityCode.unsafePortBlocked,
        isAllowed: false,
        reason: 'Puerto interno sensible bloqueado por seguridad.',
      );
    }
    return const FirewallEvaluation(
      code: FirewallSecurityCode.allowed,
      isAllowed: true,
    );
  }

  /// Detecta si el host es una dirección de loopback local (localhost, 127.0.0.1, ::1).
  static bool isLoopbackHost(String host) {
    final cleanHost = host.trim().toLowerCase().replaceAll(
      RegExp(r'[\[\]]'),
      '',
    );
    if (cleanHost.isEmpty) return true;
    if (cleanHost == 'localhost' ||
        cleanHost.endsWith('.localhost') ||
        cleanHost == '0.0.0.0') {
      return true;
    }
    final parsedIp = InternetAddress.tryParse(cleanHost);
    if (parsedIp != null) {
      if (parsedIp.isLoopback) return true;
      if (parsedIp.type == InternetAddressType.IPv4) {
        final raw = parsedIp.rawAddress;
        if (raw[0] == 0 || raw[0] == 127) return true;
      } else if (parsedIp.type == InternetAddressType.IPv6) {
        if (parsedIp.isLoopback) return true;
      }
    }
    return false;
  }

  /// Detecta si el host pertenece a una red privada o link-local.
  static bool isPrivateNetworkHost(String host) {
    final cleanHost = host.trim().toLowerCase().replaceAll(
      RegExp(r'[\[\]]'),
      '',
    );
    if (cleanHost.isEmpty) return true;
    if (cleanHost == 'broadcasthost' || cleanHost.endsWith('.local')) {
      return true;
    }
    final parsedIp = InternetAddress.tryParse(cleanHost);
    if (parsedIp != null) {
      if (parsedIp.isLinkLocal || parsedIp.isMulticast) return true;
      if (parsedIp.type == InternetAddressType.IPv4) {
        final raw = parsedIp.rawAddress;
        final b0 = raw[0], b1 = raw[1];
        if (b0 == 10) return true;
        if (b0 == 172 && b1 >= 16 && b1 <= 31) return true;
        if (b0 == 192 && b1 == 168) return true;
        if (b0 == 169 && b1 == 254) return true;
        if (b0 == 100 && b1 >= 64 && b1 <= 127) return true;
      } else if (parsedIp.type == InternetAddressType.IPv6) {
        if ((parsedIp.rawAddress[0] & 0xfe) == 0xfc) return true;
      }
    }
    return false;
  }

  static bool isPrivateOrLoopbackHost(String host) =>
      isLoopbackHost(host) || isPrivateNetworkHost(host);
}
