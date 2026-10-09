// business_document_actions.dart
//
// QUÉ HACE:
// Acciones CRUD para la gestión de archivos individuales en la biblioteca de Nano:
// compartir múltiples archivos, renombrar documentos y eliminarlos de forma segura.
//
// CÓMO FUNCIONA:
// - Despliega modales NanoGlassDialog con soporte de orientación vertical/horizontal.
// - Aplica botones NanoMetallicButton con micro-animación háptica y estética metálica.
// - Ejecuta las operaciones en BusinessDocumentLibrary y notifica a la UI mediante callbacks asíncronos.
//
// POR QUÉ:
// Mantiene el código desacoplado (SRP / SOLID), sin simulaciones y bajo el límite de 150 líneas.

import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import '../../engine/business/business_document_library.dart';
import '../widgets/nano_glass_dialog.dart';
import '../widgets/nano_metallic_button.dart';

final class BusinessDocumentActions {
  BusinessDocumentActions._();

  /// Comparte uno o múltiples documentos mediante el despachador nativo.
  static Future<void> share({
    required BuildContext context,
    required List<BusinessDocument> documents,
  }) async {
    if (documents.isEmpty) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      final xFiles = documents.map((doc) => XFile(doc.file.path, name: doc.name)).toList();
      await SharePlus.instance.share(ShareParams(files: xFiles));
    } on Object catch (error) {
      _showError(messenger, 'No se pudo compartir: $error');
    }
  }

  /// Diálogo con diseño iOS Glass para renombrar un archivo existente.
  static Future<void> rename({
    required BuildContext context,
    required BusinessDocumentLibrary library,
    required BusinessDocument document,
    required Future<void> Function() onRenamed,
  }) async {
    final controller = TextEditingController(text: document.name);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final newName = await NanoGlassDialog.show<String>(
      context: context,
      title: 'Renombrar archivo',
      subtitle: 'Ingresa el nuevo nombre para este archivo',
      icon: Icons.edit_note_rounded,
      iconColor: const Color(0xFF2563EB),
      content: _buildTextField(controller, 'Nombre del archivo', isDark),
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

    if (newName == null || newName.isEmpty || newName == document.name) return;
    try {
      await library.renameDocument(document, newName);
      await onRenamed();
    } catch (error) {
      if (context.mounted) {
        _showError(ScaffoldMessenger.of(context), 'No se pudo renombrar: $error');
      }
    }
  }

  /// Diálogo de confirmación con diseño iOS Glass para eliminar un archivo.
  static Future<void> delete({
    required BuildContext context,
    required BusinessDocumentLibrary library,
    required BusinessDocument document,
    required Future<void> Function() onDeleted,
  }) async {
    final messenger = ScaffoldMessenger.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final confirmed = await NanoGlassDialog.show<bool>(
      context: context,
      title: 'Eliminar archivo',
      icon: Icons.delete_outline_rounded,
      iconColor: const Color(0xFFEF4444),
      content: Text(
        '¿Deseas eliminar «${document.name}» de forma permanente?',
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
      await library.delete(document);
      await onDeleted();
    } on Object catch (error) {
      _showError(messenger, 'No se pudo eliminar: $error');
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
