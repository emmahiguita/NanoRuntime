// remote_inference_dialog.dart — Configuración y prueba de inferencia remota / PC.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/services/llm_engine_client.dart';
import '../../../../core/services/remote_inference_config.dart';
import '../../../../core/services/runtime_engine.dart';
import '../../../../core/theme/design_tokens.dart';
import 'remote_server_form_fields.dart';
import 'package:nanoai/core/widgets/nano_glass_window.dart';

Future<void> showRemoteInferenceSheet(BuildContext context) =>
    showNanoGlassWindow<void>(context: context, builder: (_) => const _RemoteInferenceSheet());

class _RemoteInferenceSheet extends ConsumerStatefulWidget {
  const _RemoteInferenceSheet();

  @override
  ConsumerState<_RemoteInferenceSheet> createState() => _RemoteInferenceSheetState();
}

class _RemoteInferenceSheetState extends ConsumerState<_RemoteInferenceSheet> {
  late InferenceExecutionTarget _target;
  late final TextEditingController _urlCtrl;
  late final TextEditingController _keyCtrl;
  bool _obscureKey = true;
  bool _testing = false;
  String? _testResult;
  bool? _testSuccess;

  @override
  void initState() {
    super.initState();
    final cfg = ref.read(remoteInferenceConfigProvider);
    _target = cfg.target;
    _urlCtrl = TextEditingController(text: cfg.serverUrl);
    _keyCtrl = TextEditingController(text: cfg.apiKey);
  }

  @override
  void dispose() {
    _urlCtrl.dispose();
    _keyCtrl.dispose();
    super.dispose();
  }

  Future<void> _testConnection() async {
    final url = _urlCtrl.text.trim();
    if (url.isEmpty) return;
    setState(() {
      _testing = true;
      _testResult = null;
      _testSuccess = null;
    });

    final testClient = LLMEngineClient(
      baseUrl: url,
      apiKey: _keyCtrl.text.trim().isEmpty ? null : _keyCtrl.text.trim(),
    );
    try {
      final online = await testClient.isOnline(attempts: 2, requestTimeout: const Duration(seconds: 4));
      if (!online) {
        if (mounted) {
          setState(() {
            _testing = false;
            _testSuccess = false;
            _testResult = 'No se pudo conectar a $url. Verifica la red o el puerto.';
          });
        }
        return;
      }
      final hasModel = await testClient.hasModel();
      if (mounted) {
        setState(() {
          _testing = false;
          _testSuccess = true;
          _testResult = hasModel
              ? '¡Conectado! Servidor en línea con modelo listo para inferir.'
              : '¡Conectado! Servidor online (sin modelo cargado actualmente).';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _testing = false;
          _testSuccess = false;
          _testResult = 'Error de conexión: $e';
        });
      }
    } finally {
      testClient.dispose();
    }
  }

  Future<void> _save() async {
    await ref
        .read(remoteInferenceConfigProvider.notifier)
        .updateConfig(target: _target, serverUrl: _urlCtrl.text.trim(), apiKey: _keyCtrl.text.trim());
    ref.read(runtimeEngineProvider.notifier).refresh();
    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _target == InferenceExecutionTarget.remotePc
                ? 'Modo Servidor PC activado (${_urlCtrl.text.trim()}).'
                : 'Modo Inferencia On-Device activado.',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = NanoThemeExtension.of(context).colors;
    final isRemote = _target == InferenceExecutionTarget.remotePc;

    return Padding(
      padding: EdgeInsets.only(left: 20, right: 20, top: 20, bottom: MediaQuery.of(context).viewInsets.bottom + 24),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(Icons.hub_rounded, color: colors.accent, size: 26),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Destino de Inferencia Neural',
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            SegmentedButton<InferenceExecutionTarget>(
              segments: const [
                ButtonSegment(
                  value: InferenceExecutionTarget.onDevice,
                  icon: Icon(Icons.phone_android_rounded),
                  label: Text('Dispositivo (Local)'),
                ),
                ButtonSegment(
                  value: InferenceExecutionTarget.remotePc,
                  icon: Icon(Icons.desktop_windows_rounded),
                  label: Text('Servidor PC'),
                ),
              ],
              selected: {_target},
              onSelectionChanged: (set) => setState(() => _target = set.first),
            ),
            const SizedBox(height: 16),
            if (isRemote) ...[
              RemoteServerFormFields(
                urlCtrl: _urlCtrl,
                keyCtrl: _keyCtrl,
                obscureKey: _obscureKey,
                testing: _testing,
                testResult: _testResult,
                testSuccess: _testSuccess,
                onToggleObscure: () => setState(() => _obscureKey = !_obscureKey),
                onTestConnection: _testConnection,
              ),
              const SizedBox(height: 16),
            ],
            FilledButton.icon(
              onPressed: _save,
              icon: const Icon(Icons.check_rounded),
              label: const Text('Guardar y Aplicar'),
            ),
          ],
        ),
      ),
    );
  }
}
