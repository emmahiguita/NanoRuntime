// nano_nav_mode_provider.dart — Inyección de estado para la navegación interactiva.
// QUÉ HACE: Gestiona si la interfaz presenta Barra Inferior, Drawer o Menú FAB.
// CÓMO FUNCIONA: Métodos explícitos para alternar drawer, barra y menú contextual FAB.
// POR QUÉ: Satisface DIP/SRP y preserva el estado global de navegación (< 130 líneas).
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Modo de presentación visual de la navegación principal.
enum NanoNavPresentationMode {
  /// Barra de navegación inferior cósmica (dock flotante).
  bottomBar,

  /// Navigation Drawer lateral o menú compacto de cabecera.
  drawer,
}

/// Estado inmutable de la presentación de navegación de Nano AI.
class NanoNavPresentationState {
  const NanoNavPresentationState({
    this.mode = NanoNavPresentationMode.bottomBar,
    this.isDrawerOpen = false,
    this.drawerOnRight = true,
    this.isFabMenuOpen = false,
  });

  final NanoNavPresentationMode mode;
  final bool isDrawerOpen;
  final bool drawerOnRight;
  final bool isFabMenuOpen;

  bool get isDrawerMode => mode == NanoNavPresentationMode.drawer;
  bool get isBottomBarMode => mode == NanoNavPresentationMode.bottomBar;

  NanoNavPresentationState copyWith({
    NanoNavPresentationMode? mode,
    bool? isDrawerOpen,
    bool? drawerOnRight,
    bool? isFabMenuOpen,
  }) {
    return NanoNavPresentationState(
      mode: mode ?? this.mode,
      isDrawerOpen: isDrawerOpen ?? this.isDrawerOpen,
      drawerOnRight: drawerOnRight ?? this.drawerOnRight,
      isFabMenuOpen: isFabMenuOpen ?? this.isFabMenuOpen,
    );
  }
}

/// Notificador de estado inyectado para la navegación adaptativa.
class NanoNavModeNotifier extends StateNotifier<NanoNavPresentationState> {
  NanoNavModeNotifier() : super(const NanoNavPresentationState());

  /// Convierte la navegación al modo Navigation Drawer y lo abre.
  void convertToDrawer({bool? right}) {
    state = state.copyWith(
      mode: NanoNavPresentationMode.drawer,
      isDrawerOpen: true,
      drawerOnRight: right ?? state.drawerOnRight,
      isFabMenuOpen: false,
    );
  }

  /// Convierte la navegación al modo Barra Inferior y oculta el drawer lateral.
  void convertToBottomBar() {
    state = state.copyWith(
      mode: NanoNavPresentationMode.bottomBar,
      isDrawerOpen: false,
    );
  }

  /// Alterna entre el modo Drawer y el modo Barra Inferior.
  void toggleMode() {
    if (state.mode == NanoNavPresentationMode.bottomBar) {
      convertToDrawer();
    } else {
      convertToBottomBar();
    }
  }

  /// Abre el menú drawer conservando el modo drawer activo.
  void openDrawer() {
    state = state.copyWith(isDrawerOpen: true, isFabMenuOpen: false);
  }

  /// Cierra el menú desplegable conservando el modo drawer activo.
  void closeDrawerMenu() {
    state = state.copyWith(isDrawerOpen: false);
  }

  /// Alterna el menú desplegable dentro del modo drawer.
  void toggleDrawerMenu() {
    state = state.copyWith(isDrawerOpen: !state.isDrawerOpen);
  }

  /// Cierra el drawer y restaura el modo barra inferior.
  void closeDrawer() {
    convertToBottomBar();
  }

  /// Alterna la visibilidad del menú expandible del Nano FAB.
  void toggleFabMenu() {
    state = state.copyWith(isFabMenuOpen: !state.isFabMenuOpen);
  }

  /// Despliega el menú expandible del Nano FAB.
  void openFabMenu() {
    state = state.copyWith(isFabMenuOpen: true);
  }

  /// Oculta el menú expandible del Nano FAB.
  void closeFabMenu() {
    if (state.isFabMenuOpen) {
      state = state.copyWith(isFabMenuOpen: false);
    }
  }
}

/// Provider inyectado para la gestión de presentación de navegación.
final nanoNavModeProvider =
    StateNotifierProvider<NanoNavModeNotifier, NanoNavPresentationState>(
      (ref) => NanoNavModeNotifier(),
    );
