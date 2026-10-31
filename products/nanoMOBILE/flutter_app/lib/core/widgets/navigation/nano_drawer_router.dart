import '../../router/app_router.dart';
import 'nano_destination.dart';

/// Abre los destinos reales del drawer con el router global existente.
void navigateFromNanoDrawer(NanoDestination destination) {
  switch (destination) {
    case NanoDestination.automation:
      AppRouter.router.go('/dashboard');
    case NanoDestination.models:
      AppRouter.router.go('/models');
    case NanoDestination.terminal:
      AppRouter.router.go('/terminal');
    case NanoDestination.settings:
      AppRouter.router.go('/settings');
  }
}
