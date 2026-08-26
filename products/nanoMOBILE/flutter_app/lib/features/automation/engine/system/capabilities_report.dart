/// A14.5 — informe ejecutivo de capacidades locales, soberanía de datos y
/// déficits de seguridad. FORMATO puro: toma [SystemGraph] + estado de permisos
/// + estado Shizuku y devuelve texto legible (español). No ejecuta, no lee
/// fuentes, no dependen de canales ni Riverpod. Separado del dispatcher para
/// que el formateo sea determinista y testeable sin nativo.
library;

import 'capability_availability.dart';
import 'system_capability.dart';
import 'system_graph.dart';

/// Construye el informe textual completo. Datos ya resueltos por el llamador.
///
/// [permissions] = resultado de `devicePermissionStatus` (mic, media,
/// accessibility, notificationAccess, allFiles). [shizuku] = resultado de
/// `queryShizukuStatus` (installed, binderAlive, permissionGranted). Cualquier
/// ausencia se reporta como "desconocido" — nunca se inventa un hecho.
String buildCapabilitiesReport(
  SystemGraph? graph,
  Map<dynamic, dynamic> permissions,
  Map<dynamic, dynamic> shizuku,
) {
  final b = StringBuffer();
  b.writeln('ℹ RESUMEN EJECUTIVO — NanoAI');
  b.writeln('================================');

  // ── Dispositivo ──
  b.writeln('');
  b.writeln('📱 DISPOSITIVO');
  final device = graph?.device;
  if (device == null) {
    b.writeln('• Perfil del dispositivo: no disponible');
  } else {
    b.writeln('• ${device.manufacturer} ${device.model}');
    b.writeln('• Android ${device.release} (API ${device.sdkInt})');
    b.writeln(
      '• Launcher por defecto: ${device.defaultLauncherPackage ?? '—'}',
    );
  }

  // ── Aplicaciones ──
  final apps = graph?.apps ?? const [];
  b.writeln('');
  b.writeln('📦 APLICACIONES');
  b.writeln('• ${apps.length} apps en inventario');
  final launchable = apps.where((a) => a.launchable).length;
  b.writeln('• $launchable lanzables');

  // ── Capacidades ──
  b.writeln('');
  b.writeln('🧩 CAPACIDADES LOCALES');
  final caps = graph?.capabilities ?? const {};
  if (caps.isEmpty) {
    b.writeln('• Sin datos de capacidades');
  } else {
    // Orden estable y agrupable por estado para legibilidad.
    final entries = caps.entries.toList()
      ..sort((a, b2) => a.key.name.compareTo(b2.key.name));
    for (final e in entries) {
      final a = e.value;
      b.writeln(
        '• ${_capabilityName(e.key)}: ${_availabilityState(a.state)}'
        '${a.reason.isEmpty ? '' : ' — ${a.reason}'}',
      );
    }
  }

  // ── Permisos ──
  b.writeln('');
  b.writeln('🔐 PERMISOS');
  b.writeln('• Micrófono: ${_onOff(permissions['microphone'])}');
  b.writeln('• Medios: ${_onOff(permissions['media'])}');
  b.writeln('• Accesibilidad: ${_onOff(permissions['accessibility'])}');
  b.writeln('• Notificaciones: ${_onOff(permissions['notificationAccess'])}');
  b.writeln('• Todos los archivos: ${_onOff(permissions['allFiles'])}');

  // ── Shizuku ──
  b.writeln('');
  b.writeln('🛡 SHIZUKU (privilegios Android)');
  b.writeln('• Estado: ${_shizukuState(shizuku)}');

  // ── Soberanía de datos ──
  b.writeln('');
  b.writeln('🪙 SOBERANÍA DE DATOS');
  b.writeln(
    '• Procesamiento y almacenamiento 100% local (modelo on-device). '
    'Ningún contenido sale del dispositivo salvo descarga de modelos.',
  );

  // ── Déficits de seguridad ──
  b.writeln('');
  b.writeln('⚠ DÉFICITS DE SEGURIDAD / ACCIONES PENDIENTES');
  var deficits = 0;
  if (permissions['accessibility'] != true) {
    b.writeln(
      '• Accesibilidad NO concedida → el agente no puede interactuar '
      'con otras apps. Escribe: @conceder_accessibility',
    );
    deficits++;
  }
  if (permissions['notificationAccess'] != true) {
    b.writeln(
      '• Acceso a notificaciones NO concedido → no puede leer/responder '
      'notificaciones. Escribe: @conceder_notificaciones',
    );
    deficits++;
  }
  if (permissions['allFiles'] != true) {
    b.writeln(
      '• Acceso a todos los archivos NO concedido → scanner de modelos '
      'limitado. Escribe: @conceder_archivos',
    );
    deficits++;
  }
  if (permissions['microphone'] != true || permissions['media'] != true) {
    b.writeln(
      '• Permisos de runtime (micrófono/medios) NO concedidos → '
      'dictado/archivos limitados. Escribe: @conceder_runtime',
    );
    deficits++;
  }
  if (deficits == 0) {
    b.writeln('• Sin permisos pendientes. Superficie mínima y coherente.');
  }
  b.writeln(
    '• Principio: capability != autoridad. La disponibilidad de un '
    'privilegio no autoriza su uso sin governance.',
  );

  return b.toString();
}

String _onOff(Object? v) {
  if (v == null) return 'Desconocido';
  return v == true ? 'Concedido' : 'Denegado';
}

String _capabilityName(SystemCapability c) => switch (c) {
  SystemCapability.readDeviceProfile => 'Perfil del dispositivo',
  SystemCapability.listLaunchableApps => 'Listar apps lanzables',
  SystemCapability.launchApps => 'Abrir apps',
  SystemCapability.globalBack => 'Atrás global',
  SystemCapability.globalHome => 'Inicio',
  SystemCapability.globalRecents => 'Recientes',
  SystemCapability.openNotifications => 'Panel de notificaciones',
  SystemCapability.openQuickSettings => 'Ajustes rápidos',
  SystemCapability.readNotifications => 'Leer notificaciones',
  SystemCapability.replyNotifications => 'Responder notificaciones',
  SystemCapability.observeAccessibility => 'Observar accesibilidad',
  SystemCapability.interactAccessibility => 'Interactuar vía accesibilidad',
  SystemCapability.openSystemSettings => 'Abrir ajustes del sistema',
  SystemCapability.openWifiSettings => 'Abrir ajustes de WiFi',
  SystemCapability.openBluetoothSettings => 'Abrir ajustes de Bluetooth',
  SystemCapability.linuxExecution => 'Ejecución Linux',
  SystemCapability.mediaProjection => 'Grabación de pantalla',
  SystemCapability.developerAdb => 'ADB de desarrollo',
  SystemCapability.shizuku => 'Shizuku (privilegios)',
  SystemCapability.deviceOwner => 'Device owner',
  SystemCapability.root => 'Root',
};

String _availabilityState(CapabilityAvailabilityKind k) => switch (k) {
  CapabilityAvailabilityKind.available => 'Disponible',
  CapabilityAvailabilityKind.unavailable => 'No disponible',
  CapabilityAvailabilityKind.requiresUserEnablement => 'Requiere habilitación',
  CapabilityAvailabilityKind.requiresAccessibility => 'Requiere accesibilidad',
  CapabilityAvailabilityKind.requiresNotificationAccess =>
    'Requiere acceso a notificaciones',
  CapabilityAvailabilityKind.unsupported => 'No soportado',
  CapabilityAvailabilityKind.unknown => 'Desconocido',
};

String _shizukuState(Map<dynamic, dynamic> s) {
  final installed = s['installed'];
  final binderAlive = s['binderAlive'];
  final granted = s['permissionGranted'];
  if (installed == null) return 'No disponible (canal nativo ausente)';
  if (installed != true) return 'No instalado';
  if (binderAlive != true) return 'Instalado pero servicio no disponible';
  if (granted != true) return 'Instalado, Nano no autorizado';
  return 'Disponible y autorizado';
}
