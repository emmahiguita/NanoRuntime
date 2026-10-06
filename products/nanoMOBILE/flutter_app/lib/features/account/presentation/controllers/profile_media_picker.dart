import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';

/// Controlador auxiliar para selección y persistencia de imágenes de perfil y portada.
class ProfileMediaPicker {
  const ProfileMediaPicker._();

  static Future<String> copyToAppDirectory(String sourcePath, String prefix) async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final ext = sourcePath.contains('.') ? sourcePath.split('.').last : 'jpg';
      final fileName = '${prefix}_${DateTime.now().millisecondsSinceEpoch}.$ext';
      final targetFile = File('${dir.path}/$fileName');
      await File(sourcePath).copy(targetFile.path);
      return targetFile.path;
    } catch (_) {
      return sourcePath;
    }
  }

  static Future<String?> pickImage({
    required BuildContext context,
    required String title,
    required bool hasExisting,
  }) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      useRootNavigator: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: Text('Elegir $title'),
              subtitle: const Text('Seleccionar imagen de la galería'),
              onTap: () => Navigator.of(ctx).pop('choose'),
            ),
            if (hasExisting)
              ListTile(
                leading: const Icon(Icons.delete_outline_rounded, color: Colors.red),
                title: Text('Quitar $title', style: const TextStyle(color: Colors.red)),
                onTap: () => Navigator.of(ctx).pop('remove'),
              ),
          ],
        ),
      ),
    );

    if (action == 'remove') return '';
    if (action != 'choose') return null;

    try {
      final result = await FilePicker.pickFiles(type: FileType.image);
      final tempPath = result?.files.single.path;
      if (tempPath != null && tempPath.isNotEmpty) {
        return await copyToAppDirectory(tempPath, title);
      }
    } catch (_) {}
    return null;
  }
}
