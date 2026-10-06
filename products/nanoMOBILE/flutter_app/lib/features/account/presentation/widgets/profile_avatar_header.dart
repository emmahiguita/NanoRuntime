import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';

/// Imagen local/remota o iniciales; nunca sustituye identidad por datos inventados.
class ProfileAvatarHeader extends StatelessWidget {
  final String displayName, username;
  final String? photoPath;
  final ValueChanged<String?> onPhotoChanged;
  const ProfileAvatarHeader({
    super.key,
    required this.displayName,
    required this.username,
    required this.photoPath,
    required this.onPhotoChanged,
  });

  /// Lee caracteres completos para iniciales con emoji o acentos.
  String get _initials {
    final parts = displayName.trim().split(RegExp(r'\s+'));
    if (parts.first.isEmpty) return 'U';
    return [
      parts.first,
      if (parts.length > 1) parts.last,
    ].map((part) => part.characters.first.toUpperCase()).join();
  }

  /// Cierra el modal antes del selector Android y verifica montaje al volver.
  Future<void> _choosePhoto(BuildContext context) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      useRootNavigator: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (sheetContext) => SingleChildScrollView(
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.photo_library_outlined),
                title: const Text('Elegir imagen'),
                onTap: () => Navigator.of(sheetContext).pop('choose'),
              ),
              if ((photoPath ?? '').isNotEmpty)
                ListTile(
                  leading: const Icon(Icons.delete_outline_rounded),
                  title: const Text('Quitar foto'),
                  onTap: () => Navigator.of(sheetContext).pop('remove'),
                ),
            ],
          ),
        ),
      ),
    );
    if (!context.mounted || action == null) return;
    if (action == 'remove') {
      onPhotoChanged(null);
      return;
    }
    try {
      final result = await FilePicker.pickFiles(type: FileType.image);
      if (!context.mounted) return;
      final path = result?.files.single.path;
      if (path != null) onPhotoChanged(path);
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No se pudo abrir la imagen. Intenta de nuevo.'),
          ),
        );
      }
    }
  }

  /// Carga asíncrona sin existsSync en cada frame; errores muestran iniciales.
  Widget _photo(BuildContext context) {
    final fallback = Center(
      child: Text(_initials, style: Theme.of(context).textTheme.headlineMedium),
    );
    final path = photoPath;
    if (path == null || path.isEmpty) return fallback;
    final uri = Uri.tryParse(path);
    if (uri?.scheme == 'https' || uri?.scheme == 'http') {
      return Image.network(
        path,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => fallback,
      );
    }
    return Image.file(
      File(path),
      fit: BoxFit.cover,
      errorBuilder: (_, _, _) => fallback,
    );
  }

  /// Una acción de foto y textos envolventes evitan redundancia y recortes.
  @override
  Widget build(BuildContext context) => Column(
    children: [
      ClipOval(child: SizedBox(width: 80, height: 80, child: _photo(context))),
      TextButton.icon(
        onPressed: () => _choosePhoto(context),
        icon: const Icon(Icons.edit_outlined, size: 18),
        label: const Text('Cambiar foto'),
      ),
      Text(
        displayName.trim().isEmpty ? 'Tu perfil' : displayName.trim(),
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.titleLarge,
      ),
      if (username.trim().isNotEmpty) ...[
        const SizedBox(height: 4),
        Text(
          username.startsWith('@') ? username : '@$username',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ],
    ],
  );
}
