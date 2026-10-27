import 'package:flutter/material.dart';
import 'package:nanoai/core/services/package_service.dart';

/// Instala paquetes mediante el canal nativo ya existente, con dependencias y hashes.
/// Esta acción solo se inicia desde una petición explícita del usuario en el menú.
Future<void> showTerminalPackageDialog(BuildContext context) =>
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const _PackageDialog(),
    );

class _PackageDialog extends StatefulWidget {
  const _PackageDialog();
  @override
  State<_PackageDialog> createState() => _PackageDialogState();
}

class _PackageDialogState extends State<_PackageDialog> {
  final _names = TextEditingController();
  bool _busy = false;
  String? _result;
  @override
  void dispose() {
    _names.dispose();
    super.dispose();
  }

  /// Valida nombres, no comandos de shell. El backend decide dependencias reales.
  Future<void> _install() async {
    final names = _names.text
        .trim()
        .split(RegExp(r'\s+'))
        .where((n) => n.isNotEmpty)
        .toSet()
        .toList();
    final valid = RegExp(r'^[a-z0-9][a-z0-9+.-]*$');
    if (names.isEmpty ||
        names.length > 20 ||
        names.any((n) => !valid.hasMatch(n))) {
      setState(
        () => _result =
            'Escribe entre 1 y 20 nombres de paquetes, separados por espacios.',
      );
      return;
    }
    setState(() {
      _busy = true;
      _result = null;
    });
    try {
      final ok = await const PackageService().installPackages(names);
      if (mounted) {
        setState(
          () => _result = ok
              ? 'Instalación completada. Comprueba la versión del programa en la consola.'
              : 'El instalador nativo no confirmó todos los paquetes. Revisa el registro de instalación.',
        );
      }
    } on Object {
      if (mounted) {
        setState(() => _result = 'No se pudo confirmar la instalación.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_busy,
    child: AlertDialog(
      title: const Text('Instalar paquetes de terminal'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Nano descarga paquetes Termux y sus dependencias mediante su instalador nativo. No necesita ejecutar el proceso HTTPS de APT.',
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _names,
                enabled: !_busy,
                autofocus: true,
                autocorrect: false,
                enableSuggestions: false,
                decoration: const InputDecoration(
                  labelText: 'Nombres de paquetes',
                  hintText: 'Por ejemplo: git',
                ),
              ),
              if (_busy)
                const Padding(
                  padding: EdgeInsets.only(top: 16),
                  child: LinearProgressIndicator(),
                ),
              if (_busy)
                const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Text(
                    'Descargando e instalando. Espera a que termine.',
                  ),
                ),
              if (_result != null)
                Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: SelectableText(_result!),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.pop(context),
          child: const Text('Cerrar'),
        ),
        FilledButton(
          onPressed: _busy ? null : _install,
          child: const Text('Instalar'),
        ),
      ],
    ),
  );
}
