# Auditoría de Seguridad - Módulo Terminal y Linux

## Resumen Ejecutivo
Se realizó un análisis de seguridad del módulo terminal y arquitectura Linux del proyecto NanoAI. Se identificaron **10 vulnerabilidades de seguridad críticas** que requieren atención inmediata, junto con varias recomendaciones de mejoras.

## 🔴 Vulnerabilidades Críticas Encontradas

### 1. **Vulnerabilidad de Inyección de Comandos - Shell Executor**
**Archivo**: `lib/core/services/shell_executor.dart`
**Líneas**: 369-389 (bashStream)
**Severidad**: CRÍTICA
**Descripción**: 
- La función `bashStream` ejecuta comandos vía `/system/bin/sh -c` sin sanitización
- Los comandos pasados directamente sin validación pueden permitir inyección
- Ejemplo: `bashStream("rm -rf /")` podría ejecutarse si el input no está validado

**Código vulnerable**:
```dart
Future<int> bashStream(String cmd, {...}) async {
  return stream(
    _shPath,
    ['-c', cmd],  // Inyección de comandos posible
    env: env,
    onOut: onOut,
    onErr: onErr,
    timeout: timeout,
  );
}
```

**Recomendación**: Implementar sanitización de comandos y whitelist de binarios permitidos.

### 2. **Descarga HTTP sin Validación SSL - Ubuntu Distribution**
**Archivo**: `lib/core/linux/distributions/ubuntu_distribution.dart`
**Líneas**: 199-203 (_downloadFile)
**Severidad**: ALTA
**Descripción**: 
- Descarga rootfs Ubuntu vía HTTP sin validación de certificados SSL
- Sin verificación de integridad durante la descarga (solo SHA256 post-descarga)
- Vulnerable a MITM attacks

**Código vulnerable**:
```dart
Future<void> _downloadFile(String url, String destPath, void Function(String, int) onProgress) async {
  final response = await http.get(Uri.parse(url));  // Sin validación SSL
  final file = File(destPath);
  await file.writeAsBytes(response.bodyBytes);
}
```

**Recomendación**: Usar HTTPS con validación de certificados y verificar hash durante descarga.

### 3. **Validación Insuficiente de Bind Mounts - Proot Manager**
**Archivo**: `lib/core/services/proot_manager.dart`
**Líneas**: 103-117
**Severidad**: ALTA
**Descripción**: 
- Validación de bind mounts permite paths relativos y puede ser vulnerable a path traversal
- La validación de `src.startsWith(_shell.usrDir!)` puede ser bypassed con symlinks
- No valida que el destino sea dentro del rootfs

**Código vulnerable**:
```dart
for (final bind in allBinds) {
  final src = bind.split(':').first;
  if (src.startsWith('/dev') || src.startsWith('/proc') ||
      src.startsWith('/sys') || src.startsWith('/data/data/')) {
    continue; // allowed
  }
  if (_shell.usrDir != null && src.startsWith(_shell.usrDir!)) continue;
  if (src == _shell.baseDir) continue;
  onErr?.call('Security: bind mount "$src" is not allowed');
  return 127;
}
```

**Recomendación**: Validar paths absolutos canonizados y verificar que no contengan `../` o symlinks.

### 4. **Ejecución de Comandos Network sin Validación**
**Archivo**: `lib/features/terminal/plugins/network_plugin.dart`
**Líneas**: 54-62
**Severidad**: MEDIA
**Descripción**: 
- Ejecuta `curl` y `wget` directamente sin validación de parámetros
- Los argumentos no están sanitizados, permitiendo posibles ataques

**Código vulnerable**:
```dart
r('curl', (a, c, o, af) => execNet('curl', a, o));
r('wget', (a, c, o, af) {
  if (s.shell != null && s.shell!.initialized) {
    execNet('wget', a, o);  // Sin validación de argumentos
    return;
  }
```

**Recomendación**: Validar y sanitizar argumentos antes de ejecutar comandos de red.

### 5. **Falta de Validación de SHA256 en Ubuntu Distribution**
**Archivo**: `lib/core/linux/distributions/ubuntu_distribution.dart`
**Líneas**: 70-74
**Severidad**: MEDIA
**Descripción**: 
- El SHA256 está hardcoded con un valor placeholder inválido
- La verificación de integridad es básicamente no funcional

**Código vulnerable**:
```dart
@override
String? get expectedSha256 {
  // SHA256 de ubuntu-base-24.04-base-arm64.tar.gz
  return '7a2b5c8e9f3d4a6b8c9d0e1f2a3b4c5d6e7f8a9b0c1d2e3f4a5b6c7d8e9f0a1b2';  // Placeholder inválido
}
```

**Recomendación**: Usar el SHA256 real oficial de Ubuntu.

### 6. **Descarga de Archivos sin Validación de Contenido**
**Archivo**: `android/app/src/main/kotlin/dev/nanoai/mobile/channels/ExecBinChannelHandler.kt`
**Líneas**: 500-502
**Severidad**: MEDIA
**Descripción**: 
- La función `downloadFile` descarga archivos sin validación de contenido durante la descarga
- Solo verifica el tamaño después de descargar completamente

**Recomendación**: Implementar validación progresiva durante la descarga.

### 7. **PTY sin Validación de Entrada**
**Archivo**: `lib/core/services/pty_shell.dart`
**Líneas**: 213-234 (write/writeBytes)
**Severidad**: MEDIA
**Descripción**: 
- Los métodos `write` y `writeBytes` no validan el contenido antes de enviar al PTY
- Posible inyección de secuencias de control ANSI maliciosas

**Código vulnerable**:
```dart
Future<int> write(String text) => writeBytes(utf8.encode(text));

Future<int> writeBytes(List<int> bytes) async {
  if (_closed) return 0;
  // Sin validación del contenido
  final written = await _runtime.ptyWrite(_id, Uint8List.fromList(bytes));
  return written;
}
```

**Recomendación**: Validar y sanitizar entradas antes de enviar al PTY.

### 8. **Ejecución sin Verificación de Binarios**
**Archivo**: `lib/features/terminal/pty_manager.dart`
**Líneas**: 183-205 (_resolveExecutableArgv)
**Severidad**: BAJA
**Descripción**: 
- La resolución de ejecutables solo verifica existencia del archivo
- No verifica permisos, propietario, o si es realmente un binario válido

**Código vulnerable**:
```dart
List<String>? _resolveExecutableArgv(List<String> argv) {
  if (argv.isEmpty) return null;
  final executable = argv.first;
  if (executable.startsWith('/')) {
    return File(executable).existsSync() ? argv : null;  // Solo verifica existencia
  }
  // ... más código sin validación adicional
}
```

**Recomendación**: Verificar permisos de ejecución y validar que sea un binario ELF válido.

### 9. **Falta de Rate Limiting en Operaciones de Red**
**Archivo**: `lib/core/services/docker_manager.dart`
**Líneas**: 283-358
**Severidad**: BAJA
**Descripción**: 
- Las llamadas a Docker Hub API no tienen rate limiting
- Posible abuso o agotamiento de cuotas

**Recomendación**: Implementar rate limiting y caché de respuestas.

### 10. **Manejo Inseguro de Variables de Entorno**
**Archivo**: `lib/core/services/shell_executor.dart`
**Líneas**: 244-254
**Severidad**: BAJA
**Descripción**: 
- Las variables de entorno se construyen sin validación
- Posible inyección de variables maliciosas

**Código vulnerable**:
```dart
final effectiveEnv = <String, String>{
  'HOME': _baseDir!,
  'PATH': '$_baseDir:/system/bin:/system/xbin',
  'TMPDIR': '$_baseDir/tmp',
  'SHELL': _shPath,
  'TERM': 'xterm-256color',
  'LANG': 'en_US.UTF-8',
  if (_rootfs.isInstalled) ..._linuxEnv(),
  ...?env,  // Variables externas sin validación
};
```

**Recomendación**: Validar y sanitizar variables de entorno externas.

## 🟡 Problemas de Arquitectura y Diseño

### 1. **Ubuntu Distribution Placeholder**
- El SHA256 de Ubuntu es un placeholder inválido
- La distribución Ubuntu no está completamente implementada
- El `stop()` es un no-op

### 2. **Kali Distribution Dependencia Externa**
- Depende completamente de KaliManager existente
- No tiene implementación propia de repair
- La información de distribución es fallback cuando no hay rootfs

### 3. **Proot Manager Falta de Aislamiento Completo**
- Los bind mounts permiten acceso al filesystem del host
- No hay aislamiento completo de red
- Los procesos rootfs pueden acceder a recursos del sistema

### 4. **Terminal Core Monolítico**
- La clase `NanoTerminal` es demasiado grande (1473 líneas)
- Múltiples responsabilidades mezcladas
- Difícil de mantener y auditar

## 🟢 Buenas Prácticas de Seguridad Encontradas

### 1. **Validación de SHA256 en Kali Manager**
- Verificación estricta de hash SHA256
- Fail-closed si el hash no coincide
- Descarga desde fuentes oficiales

### 2. **AllowedBinaries Allowlist**
- Sistema de allowlist para binarios ejecutables
- Implementación fail-closed por defecto
- Prevención de ejecución de binarios no autorizados

### 3. **Audit Logging Completo**
- Sistema de auditoría detallado en TerminalAuditLogger
- Registro de todas las operaciones PTY
- Trazabilidad de comandos ejecutados

### 4. **Validación de Path Policy**
- Sistema PathPolicy para validación de rutas
- Restricción de operaciones a directorios seguros
- Prevención de path traversal básico

### 5. **PTY Session Management**
- Manejo adecuado de lifecycle de sesiones PTY
- Limpieza de recursos al cerrar
- Prevención de leaks de file descriptors

## 📋 Recomendaciones de Seguridad

### Inmediatas (Críticas)
1. **Implementar sanitización de comandos** en ShellExecutor
2. **Agregar validación SSL** en todas las descargas HTTP
3. **Corregir el SHA256 placeholder** de Ubuntu Distribution
4. **Mejorar validación de bind mounts** en ProotManager

### Corto Plazo (Alta Prioridad)
5. **Implementar validación de binarios** antes de ejecución
6. **Agregar sanitización de inputs PTY**
7. **Implementar rate limiting** en operaciones de red
8. **Validar variables de entorno** externas

### Medio Plazo (Mejoras)
9. **Refactorizar NanoTerminal** en componentes más pequeños
10. **Implementar aislamiento de red** en Proot
11. **Agregar verificación progresiva** de descargas
12. **Implementar firma de binarios**

## 🔍 Análisis de Arquitectura Linux

### Proyector de Linux
- **Estado**: Implementación parcial
- **Distribuciones**: Kali (funcional), Ubuntu (placeholder), Termux (funcional)
- **Arquitectura**: Multi-distro con interfaz unificada
- **Problema**: Ubuntu no está completamente implementada

### Ubuntu Real
- **Estado**: NO es real actualmente
- **Problema**: SHA256 placeholder, implementación incompleta
- **URL**: Usa mirror oficial de Ubuntu pero verificación rota
- **Conclusión**: Ubuntu no es funcional en su estado actual

### Conectividad
- **Red**: Soporte completo vía curl/wget
- **Aislamiento**: Limitado - Proot permite acceso al host
- **Seguridad**: Validación insuficiente de operaciones de red

## 🎯 Conclusión

El módulo terminal tiene una arquitectura sólida pero presenta **vulnerabilidades de seguridad significativas** que deben ser abordadas. Las implementaciones de Kali y Termux son robustas, pero Ubuntu requiere trabajo completo antes de ser considerada funcional.

**Prioridad 1**: Corregir las vulnerabilidades de inyección de comandos y validación SSL.
**Prioridad 2**: Completar la implementación de Ubuntu Distribution.
**Prioridad 3**: Mejorar el aislamiento y seguridad de Proot Manager.