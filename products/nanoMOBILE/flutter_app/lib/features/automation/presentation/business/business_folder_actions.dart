// business_folder_actions.dart
//
// QUÉ HACE:
// Acciones CRUD para la gestión de carpetas comerciales en la biblioteca de Nano:
// creación, renombrado y eliminación recursiva de carpetas y su contenido.
//
// CÓMO FUNCIONA:
// - Despliega modales NanoGlassDialog con soporte de orientación vertical/horizontal.
// - Aplica botones NanoMetallicButton con micro-animación táctil háptica.
// - Delega la persistencia física al gestor BusinessDocumentLibrary y notifica a la UI.
//
// POR QUÉ:
// Aplica el Principio de Responsabilidad Única (SRP) de SOLID, aislando la lógica
// de directorios de la de archivos individuales y manteniendo los archivos bajo 200 líneas.

import 'package:flutter/material.dart';
import '../../engine/business/business_document_library.dart';
import '../widgets/nano_glass_dialog.dart';
import '../widgets/nano_metallic_button.dart';

final class BusinessFolderActions {
  BusinessFolderActions._();

  /// Diálogo con diseño iOS Glass para crear una nueva carpeta comercial.
  static Future<void> createFolder({
    required BuildContext context,
    required BusinessDocumentLibrary library,
    required String business,
    required Future<void> Function() onCreated,
  }) async {
    final controller = TextEditingController();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final name = await NanoGlassDialog.show<String>(
      context: context,
      title: 'Nueva carpeta',
      subtitle: 'Organiza tus catálogos y documentos en Nano',
      icon: Icons.create_new_folder_rounded,
      iconColor: const Color(0xFFF59E0B),
      content: _buildTextField(controller, 'Ej. Promociones 2026', isDark),
      actions: [
        NanoMetallicButton(
          label: 'Cancelar',
          style: NanoMetallicButtonStyle.subtle,
          onPressed: () => Navigator.pop(context),
        ),
        NanoMetallicButton(
          label: 'Crear',
          icon: Icons.add_rounded,
          style: NanoMetallicButtonStyle.primary,
          onPressed: () => Navigator.pop(context, controller.text.trim()),
        ),
      ],
    );

    if (name == null || name.isEmpty) return;
    try {
      await library.createFolder(business, name);
      await onCreated();
    } catch (error) {
      if (context.mounted) {
        _showError(ScaffoldMessenger.of(context), 'No se pudo crear la carpeta: $error');
      }
    }
  }

  /// Diálogo con diseño iOS Glass para renombrar una carpeta existente.
  static Future<void> renameFolder({
    required BuildContext context,
    required BusinessDocumentLibrary library,
    required String business,
    required String oldName,
    required Future<void> Function() onRenamed,
  }) async {
    final controller = TextEditingController(text: oldName);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final newName = await NanoGlassDialog.show<String>(
      context: context,
      title: 'Renombrar carpeta',
      subtitle: 'Modifica el nombre de la carpeta seleccionada',
      icon: Icons.drive_file_rename_outline_rounded,
      iconColor: const Color(0xFF2563EB),
      content: _buildTextField(controller, 'Nuevo nombre', isDark),
      actions: [
        NanoMetallicButton(
          label: 'Cancelar',
          style: NanoMetallicButtonStyle.subtle,
          onPressed: () => Navigator.pop(context),
        ),
        NanoMetallicButton(
          label: 'Guardar',
          icon: Icons.check_rounded,
          style: NanoMetallicButtonStyle.primary,
          onPressed: () => Navigator.pop(context, controller.text.trim()),
        ),
      ],
    );

    if (newName == null || newName.isEmpty || newName == oldName) return;
    try {
      await library.renameFolder(business, oldName, newName);
      await onRenamed();
    } catch (error) {
      if (context.mounted) {
        _showError(ScaffoldMessenger.of(context), 'No se pudo renombrar: $error');
      }
    }
  }

  /// Diálogo de confirmación con diseño iOS Glass para eliminar una carpeta.
  static Future<void> deleteFolder({
    required BuildContext context,
    required BusinessDocumentLibrary library,
    required String business,
    required String folderName,
    required Future<void> Function() onDeleted,
  }) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final confirmed = await NanoGlassDialog.show<bool>(
      context: context,
      title: 'Eliminar carpeta',
      icon: Icons.delete_sweep_rounded,
      iconColor: const Color(0xFFEF4444),
      content: Text(
        '¿Deseas eliminar la carpeta «$folderName» y todos los archivos dentro de ella?',
        style: TextStyle(
          fontSize: 13,
          color: isDark ? Colors.white70 : const Color(0xFF475569),
          height: 1.4,
        ),
      ),
      actions: [
        NanoMetallicButton(
          label: 'Cancelar',
          style: NanoMetallicButtonStyle.subtle,
          onPressed: () => Navigator.pop(context, false),
        ),
        NanoMetallicButton(
          label: 'Eliminar',
          icon: Icons.delete_outline_rounded,
          style: NanoMetallicButtonStyle.danger,
          onPressed: () => Navigator.pop(context, true),
        ),
      ],
    );
    if (confirmed != true) return;
    try {
      await library.deleteFolder(business, folderName);
      await onDeleted();
    } catch (error) {
      if (context.mounted) {
        _showError(ScaffoldMessenger.of(context), 'No se pudo eliminar la carpeta: $error');
      }
    }
  }

  static Widget _buildTextField(TextEditingController controller, String hint, bool isDark) {
    return TextField(
      controller: controller,
      autofocus: true,
      style: TextStyle(
        fontSize: 14,
        color: isDark ? Colors.white : const Color(0xFF0F172A),
      ),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(
          fontSize: 13,
          color: isDark ? Colors.white38 : const Color(0xFF94A3B8),
        ),
        filled: true,
        fillColor: isDark
            ? const Color(0xFF1E293B).withValues(alpha: 0.60)
            : const Color(0xFFF1F5F9),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: isDark ? Colors.white.withValues(alpha: 0.12) : const Color(0xFFCBD5E1),
            width: 1,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: isDark ? Colors.white.withValues(alpha: 0.12) : const Color(0xFFCBD5E1),
            width: 1,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF2563EB), width: 1.5),
        ),
      ),
    );
  }

  static void _showError(ScaffoldMessengerState messenger, String message) {
    messenger.showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }
}
