final class NanoWindow {
  final int windowId;
  final int windowType;
  final int displayId;
  final String packageName;
  final String rootIdentity;
  final bool active;
  final bool focused;

  const NanoWindow({
    required this.windowId,
    required this.windowType,
    required this.displayId,
    required this.packageName,
    required this.rootIdentity,
    required this.active,
    required this.focused,
  });

  factory NanoWindow.fromMap(Map<dynamic, dynamic> map) => NanoWindow(
    windowId: (map['windowId'] as num?)?.toInt() ?? 0,
    windowType: (map['windowType'] as num?)?.toInt() ?? 1,
    displayId: (map['displayId'] as num?)?.toInt() ?? 0,
    packageName: map['package'] as String? ?? '',
    rootIdentity: map['rootIdentity'] as String? ?? '',
    active: map['active'] == true,
    focused: map['focused'] == true,
  );
}
