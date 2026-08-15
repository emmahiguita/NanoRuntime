import 'linux_distribution_registry.dart';
import 'distributions/termux_distribution.dart';
import 'distributions/ubuntu_distribution.dart';
import 'distributions/kali_distribution.dart';
import '../services/kali_manager.dart';

/// Inicializa el registry de distribuciones Linux.
///
/// Registra las distribuciones disponibles (Termux, Ubuntu, Kali) en el
/// LinuxDistributionRegistry para que puedan ser usadas por la UI
/// y otros componentes del sistema.
///
/// Esta función debe llamarse durante el arranque de la app (main.dart)
/// para asegurar que las distribuciones estén disponibles desde el inicio.
void initializeLinuxDistributions() {
  final registry = LinuxDistributionRegistry.instance;

  // Registrar Termux
  registry.register(TermuxDistribution());

  // Registrar Ubuntu
  registry.register(UbuntuDistribution());

  // Kali se registrará dinámicamente cuando se acceda a kaliProvider
  // para evitar dependencias circulares y garantizar que use el
  // KaliManager real del runtime.
}

/// Registra KaliDistribution cuando KaliManager esté disponible.
///
/// Esta función debe llamarse desde un ConsumerWidget después de que
/// TerminalDependencies esté inicializado.
void registerKaliDistribution(KaliManager kaliManager) {
  final registry = LinuxDistributionRegistry.instance;
  registry.register(KaliDistribution(kaliManager: kaliManager));
}
