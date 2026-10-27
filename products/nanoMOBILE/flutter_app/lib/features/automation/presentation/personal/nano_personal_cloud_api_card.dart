import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/services/generative_inference_port.dart';

/// Solo el modo del agente: las claves se administran una vez en el Hub.
class NanoPersonalCloudApiCard extends StatefulWidget {
  const NanoPersonalCloudApiCard({super.key});
  @override
  State<NanoPersonalCloudApiCard> createState() =>
      _NanoPersonalCloudApiCardState();
}

class _NanoPersonalCloudApiCardState extends State<NanoPersonalCloudApiCard> {
  CloudSynergyMode _mode = CloudSynergyMode.hybridAssist;
  bool _loading = true, _saving = false;
  String? _error;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      await CloudGenerativeInferenceAdapter.ensureLoaded();
      if (mounted) {
        setState(() {
          _mode = CloudGenerativeInferenceAdapter.currentMode;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'No se pudo leer la configuración.';
        });
      }
    }
  }

  Future<void> _save(CloudSynergyMode? mode) async {
    if (mode == null || _saving) return;
    setState(() => _saving = true);
    try {
      await CloudGenerativeInferenceAdapter.saveMode(mode);
      if (mounted) {
        setState(() {
          _mode = mode;
          _error = null;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _error = 'No se pudo guardar el modo.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Motor de Nano Personal',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const Text(
            'Usa los proveedores y claves guardados en Modelos y conexiones del Hub.',
          ),
          if (_loading)
            const LinearProgressIndicator()
          else
            DropdownButtonFormField<CloudSynergyMode>(
              initialValue: _mode,
              isExpanded: true,
              items: const [
                DropdownMenuItem(
                  value: CloudSynergyMode.localOnly,
                  child: Text('Solo local'),
                ),
                DropdownMenuItem(
                  value: CloudSynergyMode.hybridAssist,
                  child: Text('Híbrido: local y apoyo cloud'),
                ),
                DropdownMenuItem(
                  value: CloudSynergyMode.cloudFirst,
                  child: Text('Cloud con respaldo local'),
                ),
              ],
              onChanged: _saving ? null : _save,
            ),
          TextButton.icon(
            onPressed: () => context.push('/automation/skills-mcp'),
            icon: const Icon(Icons.hub_outlined),
            label: const Text('Administrar modelos y conexiones'),
          ),
          if (_error != null) Text(_error!),
        ],
      ),
    ),
  );
}
