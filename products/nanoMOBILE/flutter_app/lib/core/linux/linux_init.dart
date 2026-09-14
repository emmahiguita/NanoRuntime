import 'linux_distribution_registry.dart';
import 'distributions/termux_distribution.dart';
import 'distributions/ubuntu_distribution.dart';
import 'distributions/kali_distribution.dart';
import '../services/kali_manager.dart';
import '../services/ubuntu_manager.dart';

/// Inicializa el registry de distribuciones Linux.
void initializeLinuxDistributions() {
  final registry = LinuxDistributionRegistry.instance;
  registry.register(TermuxDistribution());
  // Ubuntu y Kali se registrarán dinámicamente cuando se acceda a sus providers.
}

/// Registra KaliDistribution cuando KaliManager esté disponible.
void registerKaliDistribution(KaliManager kaliManager) {
  final registry = LinuxDistributionRegistry.instance;
  registry.register(KaliDistribution(kaliManager: kaliManager));
}

/// Registra UbuntuDistribution cuando UbuntuManager esté disponible.
void registerUbuntuDistribution(UbuntuManager ubuntuManager) {
  final registry = LinuxDistributionRegistry.instance;
  registry.register(UbuntuDistribution(ubuntuManager: ubuntuManager));
}