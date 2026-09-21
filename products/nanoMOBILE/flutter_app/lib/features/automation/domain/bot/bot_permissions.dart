/// BOT-PERMISSIONS-02 — Matriz de Control de Acceso Basada en Roles (RBAC).
///
/// **QUÉ HACE:**
/// Define las facultades de seguridad y permisos de ejecución de herramientas
/// asignadas a cada bot, impidiendo que agentes no autorizados ejecuten acciones críticas.
///
/// **CÓMO FUNCIONA:**
/// Evalúa banderas booleanas de subsistema y una lista de herramientas bloqueadas
/// antes de despachar cualquier llamada en AgentToolDispatcher.
///
/// **POR QUÉ:**
/// Previene que un bot comercial o externo ejecute comandos crudos de terminal (bash)
/// o manipule la interfaz del sistema operativo sin supervisión explícita.
library;

final class BotPermissions {
  final bool allowLinuxExec;
  final bool allowAndroidUiAutomation;
  final bool allowBrowserAutomation;
  final bool allowMessagingSend;
  final bool allowPaymentCreation;
  final bool allowFileSystemRead;
  final bool allowFileSystemWrite;
  final List<String> blockedTools;

  const BotPermissions({
    this.allowLinuxExec = false,
    this.allowAndroidUiAutomation = false,
    this.allowBrowserAutomation = false,
    this.allowMessagingSend = true,
    this.allowPaymentCreation = false,
    this.allowFileSystemRead = true,
    this.allowFileSystemWrite = false,
    this.blockedTools = const [],
  });

  /// Permisos plenos para el bot personal del dueño del dispositivo.
  factory BotPermissions.personalOwner() => const BotPermissions(
        allowLinuxExec: true,
        allowAndroidUiAutomation: true,
        allowBrowserAutomation: true,
        allowMessagingSend: true,
        allowPaymentCreation: false,
        allowFileSystemRead: true,
        allowFileSystemWrite: true,
        blockedTools: [],
      );

  /// Permisos restringidos para un bot comercial/ventas.
  factory BotPermissions.salesRestricted() => const BotPermissions(
        allowLinuxExec: false,
        allowAndroidUiAutomation: false,
        allowBrowserAutomation: false,
        allowMessagingSend: true,
        allowPaymentCreation: true,
        allowFileSystemRead: true,
        allowFileSystemWrite: false,
        blockedTools: ['linux.raw_exec', 'shizuku.exec', 'android.tap', 'android.shell'],
      );

  /// Permisos para bot de soporte técnico y diagnóstico.
  factory BotPermissions.supportAgent() => const BotPermissions(
        allowLinuxExec: false,
        allowAndroidUiAutomation: true,
        allowBrowserAutomation: true,
        allowMessagingSend: true,
        allowPaymentCreation: false,
        allowFileSystemRead: true,
        allowFileSystemWrite: false,
        blockedTools: ['linux.raw_exec', 'payment.charge'],
      );

  /// Evalúa si la herramienta solicitada tiene permiso de ejecución.
  bool canExecute(String toolName) {
    if (blockedTools.contains(toolName)) return false;

    if (toolName.startsWith('linux.') && !allowLinuxExec) {
      if (toolName == 'linux.file.read' && allowFileSystemRead) return true;
      return false;
    }

    if ((toolName.startsWith('android.') || toolName.startsWith('ui.')) && !allowAndroidUiAutomation) {
      return false;
    }

    if (toolName.startsWith('browser.') && !allowBrowserAutomation) {
      return false;
    }

    if (toolName.startsWith('payment.') && !allowPaymentCreation) {
      return false;
    }

    return true;
  }

  Map<String, dynamic> toMap() => {
        'allowLinuxExec': allowLinuxExec,
        'allowAndroidUiAutomation': allowAndroidUiAutomation,
        'allowBrowserAutomation': allowBrowserAutomation,
        'allowMessagingSend': allowMessagingSend,
        'allowPaymentCreation': allowPaymentCreation,
        'allowFileSystemRead': allowFileSystemRead,
        'allowFileSystemWrite': allowFileSystemWrite,
        'blockedTools': blockedTools,
      };

  factory BotPermissions.fromMap(Map<dynamic, dynamic>? map) {
    if (map == null) return const BotPermissions();
    return BotPermissions(
      allowLinuxExec: map['allowLinuxExec'] == true,
      allowAndroidUiAutomation: map['allowAndroidUiAutomation'] == true,
      allowBrowserAutomation: map['allowBrowserAutomation'] == true,
      allowMessagingSend: map['allowMessagingSend'] != false,
      allowPaymentCreation: map['allowPaymentCreation'] == true,
      allowFileSystemRead: map['allowFileSystemRead'] != false,
      allowFileSystemWrite: map['allowFileSystemWrite'] == true,
      blockedTools: (map['blockedTools'] as List? ?? const []).whereType<String>().toList(),
    );
  }
}
