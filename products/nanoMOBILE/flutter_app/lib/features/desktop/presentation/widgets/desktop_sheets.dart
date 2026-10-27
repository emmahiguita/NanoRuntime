import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:nanoai/core/theme/design_tokens.dart';
import 'package:nanoai/core/widgets/nano_glass_window.dart';
import 'package:nanoai/features/desktop/presentation/widgets/desktop_stream_chrome.dart';

part 'desktop_sheets_app_tile.part.dart';
part 'desktop_sheets_apps.part.dart';
part 'desktop_sheets_command_card.part.dart';
part 'desktop_sheets_command_items.part.dart';
part 'desktop_sheets_commands_header.part.dart';
part 'desktop_sheets_commands.part.dart';
part 'desktop_sheets_helpers.part.dart';
part 'desktop_sheets_keys.part.dart';
part 'desktop_sheets_more.part.dart';
part 'desktop_sheets_zoom.part.dart';

/// Professional Frosted Glass Windows for Nano Linux Remote Desktop.
class DesktopSheets {
  /// App Launcher Window
  static void showAppsSheet({
    required BuildContext context,
    required NanoColors colors,
    required Future<void> Function(String app) onLaunchApp,
    required VoidCallback onOpenHelp,
  }) {
    showNanoGlassWindow<void>(
      context: context,
      builder: (sheetContext) => _AppsSheetContent(
        colors: colors,
        onLaunchApp: onLaunchApp,
        onOpenHelp: onOpenHelp,
      ),
    );
  }

  /// Precision Zoom Controls Window
  static void showZoomSheet({
    required BuildContext context,
    required NanoColors colors,
    required double currentZoom,
    required ValueChanged<double> onZoomChanged,
    required VoidCallback onResetZoom,
  }) {
    showNanoGlassWindow<void>(
      context: context,
      builder: (sheetContext) => _ZoomSheetContent(
        colors: colors,
        currentZoom: currentZoom,
        onZoomChanged: onZoomChanged,
        onResetZoom: onResetZoom,
      ),
    );
  }

  /// Complete PC Keyboard Grid Window
  static void showPCKeysSheet({
    required BuildContext context,
    required NanoColors colors,
    required ValueChanged<int> onQuickKey,
    required ValueChanged<List<int>> onCombo,
    required bool ctrlSticky,
    required bool altSticky,
    required bool shiftSticky,
    required bool superSticky,
    required VoidCallback onToggleCtrl,
    required VoidCallback onToggleAlt,
    required VoidCallback onToggleShift,
    required VoidCallback onToggleSuper,
  }) {
    showNanoGlassWindow<void>(
      context: context,
      builder: (sheetContext) => _PCKeysSheetContent(
        colors: colors,
        onQuickKey: onQuickKey,
        onCombo: onCombo,
        ctrlSticky: ctrlSticky,
        altSticky: altSticky,
        shiftSticky: shiftSticky,
        superSticky: superSticky,
        onToggleCtrl: onToggleCtrl,
        onToggleAlt: onToggleAlt,
        onToggleShift: onToggleShift,
        onToggleSuper: onToggleSuper,
      ),
    );
  }

  /// CyberTools & Organized Linux Commands Window
  static void showCommandsSheet({
    required BuildContext context,
    required NanoColors colors,
    required ValueChanged<String> onExecuteCommand,
  }) {
    showNanoGlassWindow<void>(
      context: context,
      builder: (sheetContext) => _CommandsSheetContent(
        colors: colors,
        onExecuteCommand: onExecuteCommand,
      ),
    );
  }

  /// Advanced Desktop Settings & Tools Window
  static void showMoreSheet({
    required BuildContext context,
    required NanoColors colors,
    required String status,
    required bool connected,
    required int fbWidth,
    required int fbHeight,
    required VoidCallback onFullscreen,
    required VoidCallback onRotate,
    required VoidCallback onMinimize,
    required VoidCallback onReconnect,
    required VoidCallback onDisconnect,
    required VoidCallback onOpenHelp,
  }) {
    showNanoGlassWindow<void>(
      context: context,
      builder: (sheetContext) => _MoreSheetContent(
        colors: colors,
        status: status,
        connected: connected,
        fbWidth: fbWidth,
        fbHeight: fbHeight,
        onFullscreen: onFullscreen,
        onRotate: onRotate,
        onMinimize: onMinimize,
        onReconnect: onReconnect,
        onDisconnect: onDisconnect,
        onOpenHelp: onOpenHelp,
      ),
    );
  }
}
