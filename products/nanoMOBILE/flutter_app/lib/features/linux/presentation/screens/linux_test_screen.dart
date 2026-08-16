import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/linux/linux_distribution_registry.dart';
import '../../../../core/linux/linux_init.dart';
import '../../../../core/providers/kali_provider.dart';

/// Pantalla de prueba para verificar el sistema multi-distro.
///
/// Esta pantalla es SOLO para desarrollo y pruebas.
/// Muestra el estado real de las distribuciones registradas.
class LinuxTestScreen extends ConsumerStatefulWidget {
  const LinuxTestScreen({super.key});

  @override
  ConsumerState<LinuxTestScreen> createState() => _LinuxTestScreenState();
}

class _LinuxTestScreenState extends ConsumerState<LinuxTestScreen> {
  final LinuxDistributionRegistry _registry = LinuxDistributionRegistry.instance;
  bool _kaliRegistered = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _registerKaliIfNeeded();
    });
  }

  void _registerKaliIfNeeded() {
    if (_kaliRegistered) return;

    final kaliManager = ref.read(kaliProvider);
    if (kaliManager != null) {
      registerKaliDistribution(kaliManager);
      _kaliRegistered = true;
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_kaliRegistered) {
      _registerKaliIfNeeded();
    }

    final distributions = _registry.getAllDistributions();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Linux Multi-Distro Test'),
        backgroundColor: Colors.blue,
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: distributions.length,
        itemBuilder: (context, index) {
          final dist = distributions[index];
          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: ExpansionTile(
              title: Text(dist.name),
              subtitle: Text('${dist.id} • ${dist.architecture}'),
              children: [
                FutureBuilder<bool>(
                  future: dist.isInstalled(),
                  builder: (context, snapshot) {
                    final isInstalled = snapshot.data ?? false;
                    return Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Instalado: $isInstalled'),
                          Text('Package Backend: ${dist.packageBackend}'),
                          Text('Default Shell: ${dist.defaultShell}'),
                          const SizedBox(height: 8),
                          ElevatedButton(
                            onPressed: () async {
                              final info = await dist.getInfo();
                              if (!context.mounted) return;
                              showDialog(
                                context: context,
                                  builder: (context) => AlertDialog(
                                    title: const Text('Info'),
                                    content: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text('ID: ${info.id}'),
                                        Text('Name: ${info.name}'),
                                        Text('Version: ${info.version}'),
                                        Text('Pretty Name: ${info.prettyName}'),
                                      ],
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.pop(context),
                                        child: const Text('OK'),
                                      ),
                                    ],
                                  ),
                              );
                            },
                            child: const Text('Get Info'),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
