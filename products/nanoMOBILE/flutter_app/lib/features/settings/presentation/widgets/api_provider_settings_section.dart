import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nanoai/core/providers/api_provider_service_provider.dart';
import 'package:nanoai/core/services/api_provider_service.dart';
import 'package:nanoai/core/theme/design_tokens.dart';
import 'package:nanoai/core/theme/nano_type.dart';
import 'package:nanoai/features/automation/presentation/automation_visual_theme.dart';

class ApiProviderSettingsSection extends ConsumerStatefulWidget {
  const ApiProviderSettingsSection({super.key});

  @override
  ConsumerState<ApiProviderSettingsSection> createState() =>
      _ApiProviderSettingsSectionState();
}

class _ApiProviderSettingsSectionState
    extends ConsumerState<ApiProviderSettingsSection> {
  final _keyController = TextEditingController();
  final _modelController = TextEditingController();
  final _baseUrlController = TextEditingController();
  ApiProviderConfig _config = const ApiProviderConfig(
    provider: ApiProviderKind.local,
    model: '',
    baseUrl: '',
    hasApiKey: false,
  );
  bool _loading = true;
  bool _busy = false;
  bool _showKey = false;
  bool? _feedbackOk;
  String? _feedback;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _keyController.dispose();
    _modelController.dispose();
    _baseUrlController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final config = await ref.read(apiProviderSettingsStoreProvider).load();
      if (!mounted) return;
      setState(() {
        _config = config;
        _modelController.text = config.model;
        _baseUrlController.text = config.baseUrl;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _feedback = 'No se pudo leer la configuración segura del dispositivo.';
        _feedbackOk = false;
      });
    }
  }

  Future<void> _selectProvider(ApiProviderKind? provider) async {
    if (provider == null) return;
    try {
      final config = await ref
          .read(apiProviderSettingsStoreProvider)
          .loadForProvider(provider);
      if (!mounted) return;
      setState(() {
        _config = config;
        _modelController.text = config.model;
        _baseUrlController.text = config.baseUrl;
        _feedback = null;
        _feedbackOk = null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _config = ApiProviderConfig(
          provider: provider,
          model: provider.defaultModel,
          baseUrl: provider.defaultBaseUrl,
          hasApiKey: false,
        );
        _modelController.text = provider.defaultModel;
        _baseUrlController.text = provider.defaultBaseUrl;
        _feedback = 'No se pudo leer la configuración guardada.';
        _feedbackOk = false;
      });
    }
  }

  ApiProviderConfig _formConfig() => _config.copyWith(
    model: _modelController.text.trim(),
    baseUrl: _baseUrlController.text.trim(),
  );

  Future<bool> _saveForm({bool showFeedback = true}) async {
    if (_config.provider == ApiProviderKind.openAiCompatible &&
        _baseUrlController.text.trim().isEmpty) {
      _setFeedback('Escribe la URL base HTTPS del proveedor.', false);
      return false;
    }
    setState(() => _busy = true);
    try {
      final formConfig = _formConfig();
      await ref
          .read(apiProviderSettingsStoreProvider)
          .save(formConfig, apiKey: _keyController.text);
      final savedConfig = await ref
          .read(apiProviderSettingsStoreProvider)
          .loadForProvider(formConfig.provider);
      _keyController.clear();
      if (!mounted) return false;
      setState(() {
        _config = savedConfig;
        _busy = false;
        if (showFeedback) {
          _feedback = savedConfig.provider == ApiProviderKind.local
              ? 'Modo local guardado.'
              : savedConfig.hasApiKey
              ? 'Configuración guardada. La clave permanece protegida en este dispositivo.'
              : 'Proveedor guardado. Añade una clave para poder enviar mensajes a la API.';
          _feedbackOk = true;
        }
      });
      return true;
    } catch (_) {
      if (!mounted) return false;
      setState(() {
        _busy = false;
        _feedback = 'No se pudo guardar en el almacenamiento seguro.';
        _feedbackOk = false;
      });
      return false;
    }
  }

  Future<void> _testConnection() async {
    if (!await _saveForm(showFeedback: false)) return;
    if (!_config.hasApiKey) {
      _setFeedback('Guarda primero una clave para este proveedor.', false);
      return;
    }
    setState(() {
      _busy = true;
      _feedback = 'Probando conexión…';
      _feedbackOk = null;
    });
    try {
      await ref.read(apiProviderChatServiceProvider).testConnection();
      if (!mounted) return;
      setState(() {
        _busy = false;
        _feedback = 'Conexión API correcta para ${_config.provider.label}.';
        _feedbackOk = true;
      });
    } on ApiProviderException catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _feedback = error.message;
        _feedbackOk = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _feedback = 'No se pudo completar la prueba de conexión.';
        _feedbackOk = false;
      });
    }
  }

  Future<void> _clearKey() async {
    final approved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Borrar clave guardada'),
        content: Text(
          'Se quitará del dispositivo la clave de ${_config.provider.label}.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Borrar'),
          ),
        ],
      ),
    );
    if (approved != true) return;
    setState(() => _busy = true);
    try {
      await ref
          .read(apiProviderSettingsStoreProvider)
          .deleteApiKey(_config.provider);
      final config = await ref
          .read(apiProviderSettingsStoreProvider)
          .loadForProvider(_config.provider);
      if (!mounted) return;
      setState(() {
        _config = config;
        _busy = false;
        _keyController.clear();
        _feedback = 'Clave borrada del dispositivo.';
        _feedbackOk = true;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _feedback = 'No se pudo borrar la clave guardada.';
        _feedbackOk = false;
      });
    }
  }

  void _setFeedback(String text, bool success) {
    if (!mounted) return;
    setState(() {
      _feedback = text;
      _feedbackOk = success;
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = NanoThemeExtension.of(context).colors;
    final isLocal = _config.provider == ApiProviderKind.local;
    final hasKey = _config.hasApiKey;
    return Padding(
      padding: const EdgeInsets.only(bottom: NanoSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const AutomationSectionLabel('Proveedores de IA'),
          AutomationSurfaceCard(
            child: Padding(
              padding: const EdgeInsets.all(NanoSpacing.md),
              child: _loading
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(NanoSpacing.md),
                        child: CircularProgressIndicator(),
                      ),
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'Elige una API para el chat o conserva el modelo local. '
                          'Tus claves se guardan en el almacenamiento seguro del móvil.',
                          style: NanoType.caption(colors.onSurfaceVariant),
                        ),
                        const SizedBox(height: NanoSpacing.md),
                        DropdownButtonFormField<ApiProviderKind>(
                          initialValue: _config.provider,
                          decoration: const InputDecoration(
                            labelText: 'Servicio',
                            border: OutlineInputBorder(),
                          ),
                          items: [
                            for (final provider in ApiProviderKind.values)
                              DropdownMenuItem(
                                value: provider,
                                child: Text(provider.label),
                              ),
                          ],
                          onChanged: _busy ? null : _selectProvider,
                        ),
                        if (!isLocal) ...[
                          const SizedBox(height: NanoSpacing.md),
                          TextField(
                            controller: _modelController,
                            enabled: !_busy,
                            autocorrect: false,
                            decoration: const InputDecoration(
                              labelText: 'Modelo API',
                              hintText: 'ID del modelo del proveedor',
                              border: OutlineInputBorder(),
                            ),
                          ),
                          if (_config.provider ==
                              ApiProviderKind.openAiCompatible) ...[
                            const SizedBox(height: NanoSpacing.md),
                            TextField(
                              controller: _baseUrlController,
                              enabled: !_busy,
                              keyboardType: TextInputType.url,
                              autocorrect: false,
                              decoration: const InputDecoration(
                                labelText: 'URL base HTTPS',
                                hintText: 'https://api.ejemplo.com/v1',
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ],
                          const SizedBox(height: NanoSpacing.md),
                          TextField(
                            controller: _keyController,
                            enabled: !_busy,
                            obscureText: !_showKey,
                            autocorrect: false,
                            enableSuggestions: false,
                            keyboardType: TextInputType.visiblePassword,
                            decoration: InputDecoration(
                              labelText: 'Clave API',
                              hintText: hasKey
                                  ? 'Clave guardada; escribe otra para reemplazarla'
                                  : 'Pega aquí tu clave cuando la tengas',
                              border: const OutlineInputBorder(),
                              suffixIcon: IconButton(
                                tooltip: _showKey
                                    ? 'Ocultar clave'
                                    : 'Mostrar clave',
                                onPressed: () =>
                                    setState(() => _showKey = !_showKey),
                                icon: Icon(
                                  _showKey
                                      ? Icons.visibility_off
                                      : Icons.visibility,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: NanoSpacing.sm),
                          Text(
                            hasKey
                                ? 'Hay una clave guardada para este servicio. No se vuelve a mostrar.'
                                : 'No hay clave guardada. La API quedará inactiva hasta que la añadas.',
                            style: NanoType.caption(colors.onSurfaceVariant),
                          ),
                          const SizedBox(height: NanoSpacing.xs),
                          Text(
                            'Al usar este proveedor, el texto del chat y sus adjuntos de texto se enviarán a su servicio.',
                            style: NanoType.caption(colors.onSurfaceVariant),
                          ),
                        ] else ...[
                          const SizedBox(height: NanoSpacing.sm),
                          Text(
                            'El chat seguirá usando Nano Runtime en el dispositivo. No se enviarán mensajes a una API externa.',
                            style: NanoType.caption(colors.onSurfaceVariant),
                          ),
                        ],
                        if (_feedback != null) ...[
                          const SizedBox(height: NanoSpacing.md),
                          Text(
                            _feedback!,
                            style: NanoType.caption(
                              _feedbackOk == false
                                  ? colors.error
                                  : colors.onSurfaceVariant,
                            ),
                          ),
                        ],
                        const SizedBox(height: NanoSpacing.md),
                        Wrap(
                          spacing: NanoSpacing.sm,
                          runSpacing: NanoSpacing.xs,
                          children: [
                            FilledButton.icon(
                              onPressed: _busy ? null : _saveForm,
                              icon: const Icon(Icons.lock_outline_rounded),
                              label: const Text('Guardar'),
                            ),
                            if (!isLocal)
                              OutlinedButton.icon(
                                onPressed:
                                    _busy ||
                                        (!hasKey &&
                                            _keyController.text.trim().isEmpty)
                                    ? null
                                    : _testConnection,
                                icon: const Icon(Icons.wifi_tethering_rounded),
                                label: const Text('Probar API'),
                              ),
                            if (!isLocal && hasKey)
                              TextButton.icon(
                                onPressed: _busy ? null : _clearKey,
                                icon: const Icon(Icons.delete_outline_rounded),
                                label: const Text('Borrar clave'),
                              ),
                          ],
                        ),
                        if (_busy) ...[
                          const SizedBox(height: NanoSpacing.md),
                          const LinearProgressIndicator(),
                        ],
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
