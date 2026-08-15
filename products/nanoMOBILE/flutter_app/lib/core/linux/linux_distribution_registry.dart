import 'linux_distribution.dart';

/// Registro centralizado de distribuciones Linux disponibles.
///
/// Responsabilidades:
/// - Registrar distribuciones disponibles
/// - Recuperar distribuciones por ID
/// - Listar distribuciones instaladas
/// - Listar distribuciones disponibles para instalación
///
/// Este registry es el punto único de verdad para qué distribuciones
/// existen en el sistema y cuáles están instaladas.
class LinuxDistributionRegistry {
  final Map<String, LinuxDistribution> _distributions = {};

  /// Instancia singleton del registry.
  static final LinuxDistributionRegistry instance =
      LinuxDistributionRegistry._internal();

  LinuxDistributionRegistry._internal();

  /// Registra una distribución en el registry.
  ///
  /// Si ya existe una distribución con el mismo ID, será reemplazada.
  void register(LinuxDistribution distribution) {
    _distributions[distribution.id] = distribution;
  }

  /// Obtiene una distribución por su ID.
  ///
  /// Retorna null si la distribución no está registrada.
  LinuxDistribution? getDistribution(String id) {
    return _distributions[id];
  }

  /// Lista todas las distribuciones registradas.
  List<LinuxDistribution> getAllDistributions() {
    return _distributions.values.toList();
  }

  /// Lista solo las distribuciones instaladas.
  ///
  /// Este método es asíncrono porque debe llamar isInstalled()
  /// para cada distribución.
  Future<List<LinuxDistribution>> getInstalledDistributions() async {
    final installed = <LinuxDistribution>[];
    for (final dist in _distributions.values) {
      if (await dist.isInstalled()) {
        installed.add(dist);
      }
    }
    return installed;
  }

  /// Lista las distribuciones disponibles para instalación.
  ///
  /// Incluye distribuciones no instaladas pero registradas.
  Future<List<LinuxDistribution>> getAvailableDistributions() async {
    final available = <LinuxDistribution>[];
    for (final dist in _distributions.values) {
      if (!await dist.isInstalled()) {
        available.add(dist);
      }
    }
    return available;
  }

  /// Verifica si una distribución está registrada.
  bool isRegistered(String id) {
    return _distributions.containsKey(id);
  }

  /// Elimina una distribución del registry.
  ///
  /// Precaución: esto solo elimina del registro, no desinstala
  /// la distribución del filesystem. Usar distribution.uninstall() para eso.
  void unregister(String id) {
    _distributions.remove(id);
  }

  /// Limpia el registry (útil para tests).
  void clear() {
    _distributions.clear();
  }
}
