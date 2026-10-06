// QUÉ: contrato público del contenedor de navegación.
// CÓMO: mantiene las opciones existentes y delega estado en la misma biblioteca.
// POR QUÉ: separa configuración de ciclo de vida sin duplicar controladores.
part of 'nano_navigation_panel.dart';

class NanoFloatingNavigationFrame extends ConsumerStatefulWidget {
  const NanoFloatingNavigationFrame({
    super.key,
    required this.child,
    required this.selectedIndex,
    required this.onDestinationSelected,
    this.slotId,
    this.onSearch,
    this.onVoice,
    this.searchHint = NanoUniversalInputConfig.defaultHint,
    this.fullBleed = false,
    this.floatOverContent = false,
    this.transparentDock = false,
    this.protectTop = false,
    this.initialDockMode = NanoNavDockMode.bottom,
    this.allowSideDock = true,
  });
  final Widget child;
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final String? slotId;
  final ValueChanged<String>? onSearch;
  final VoidCallback? onVoice;
  final String searchHint;
  final NanoNavDockMode initialDockMode;
  final bool allowSideDock, fullBleed, floatOverContent;
  final bool transparentDock, protectTop;
  @override
  ConsumerState<NanoFloatingNavigationFrame> createState() =>
      _NanoFloatingNavigationFrameState();
}
