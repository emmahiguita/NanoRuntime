import 'package:flutter/material.dart';
import 'package:nanoai/core/theme/design_tokens.dart';
import 'package:nanoai/core/widgets/nano_screen_shell.dart';
import 'package:nanoai/features/automation/presentation/automation_visual_theme.dart';

import '../../domain/terminal_hub_card.dart';
import '../widgets/perspective_carousel_item.dart';
import '../widgets/perspective_hero_flight.dart';
import '../widgets/terminal_coverflow_card.dart';

/// Centro único de acceso a las herramientas de sistema.
///
/// Implementa un Carrusel Cover Flow 3D con perspectiva física,
/// Morph de tarjetas compartido con Hero y un Perspective Hinge
/// durante el vuelo de apertura hacia la Ficha 3D Turntable (SOLID).
class TerminalHubScreen extends StatefulWidget {
  const TerminalHubScreen({super.key});

  @override
  State<TerminalHubScreen> createState() => _TerminalHubScreenState();
}

class _TerminalHubScreenState extends State<TerminalHubScreen> {
  late final PageController _pageController;
  int _currentIndex = 1;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(
      initialPage: _currentIndex,
      viewportFraction: 0.50,
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  List<TerminalHubCard> _buildCards(NanoColors colors) {
    return [
      TerminalHubCard(
        id: 'terminal',
        title: 'Terminal',
        eyebrow: 'CONSOLA PTY',
        description:
            'Sesiones interactivas persistentes para Bash, Python, Node, SSH y utilidades nativas.',
        icon: Icons.hub_rounded,
        accent: colors.accent,
        imageAsset: 'assets/promo/ad1.jpg',
        route: '/system_logs',
        highlights: const [
          'Sin rastreo de telemetría de terceros ni analíticas externas',
          'Aislamiento de hardware local para máxima seguridad en el borde',
          'Integración nativa con la red neuronal mediante JNI ultrarrápido',
        ],
        actionLabel: 'Ver Registros de Sistema',
      ),
      TerminalHubCard(
        id: 'shell_linux',
        title: 'SHELL LINUX',
        eyebrow: 'ENTORNOS',
        description:
            'Entorno Alpine Linux con gestor de paquetes APK. Ideal para tareas avanzadas de scripting.',
        icon: Icons.terminal_rounded,
        accent: colors.terminalGreen,
        imageAsset: 'assets/promo/ad2.jpg',
        route: '/terminal_session',
        highlights: const [
          'Emulador de terminal VT100 completo con soporte de colores',
          'Aislamiento seguro de procesos sin necesidad de root',
          'Integración nativa con Nano Runtime y sockets locales',
        ],
        actionLabel: 'Administrar Entornos',
      ),
      TerminalHubCard(
        id: 'visor_linux',
        title: 'Visor Linux',
        eyebrow: 'ESCRITORIO',
        description:
            'Prepara el escritorio gráfico X11 y abre el visor remoto VNC con aceleración.',
        icon: Icons.desktop_windows_rounded,
        accent: colors.tertiary,
        imageAsset: 'assets/promo/ad3.jpg',
        route: '/desktop',
        highlights: const [
          'Streaming de escritorio gráfico con latencia ultrabaja',
          'Soporte de gestos táctiles y teclado físico Bluetooth',
          'Resolución adaptable y escalado de pantalla nítido',
        ],
        actionLabel: 'Iniciar Visor Gráfico',
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final colors = NanoThemeExtension.of(context).colors;
    final cards = _buildCards(colors);

    final Widget shell = NanoScreenShell(
      title: 'Terminal',
      body: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final isDeviceLandscape =
              MediaQuery.orientationOf(context) == Orientation.landscape;
          final compactLandscape =
              isDeviceLandscape &&
              width > constraints.maxHeight &&
              constraints.maxHeight < 520;

          final double carouselHeight = compactLandscape
              ? (constraints.maxHeight - 80).clamp(190.0, 240.0)
              : (width < 600 ? 330.0 : 390.0);

          return CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              // Cabecera descriptiva con jerarquía clara
              SliverPadding(
                padding: EdgeInsets.fromLTRB(
                  width < 600 ? 16 : 24,
                  compactLandscape ? 4 : 14,
                  width < 600 ? 16 : 24,
                  compactLandscape ? 6 : 18,
                ),
                sliver: SliverList.list(
                  children: [
                    Text(
                      'Sistemas locales',
                      style: TextStyle(
                        color: colors.textPrimary,
                        fontFamily: 'Inter',
                        fontSize: compactLandscape
                            ? 19
                            : (width < 600 ? 24 : 30),
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.8,
                      ),
                    ),
                    SizedBox(height: compactLandscape ? 2 : 4),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 680),
                      child: Text(
                        'Terminal, entornos Nano Linux y escritorio gráfico organizados en un solo lugar.',
                        style: TextStyle(
                          color: colors.textSecondary,
                          fontFamily: 'Inter',
                          fontSize: compactLandscape ? 11 : 13.5,
                          height: compactLandscape ? 1.2 : 1.4,
                        ),
                        maxLines: compactLandscape ? 1 : null,
                        overflow: compactLandscape
                            ? TextOverflow.ellipsis
                            : TextOverflow.clip,
                      ),
                    ),
                  ],
                ),
              ),

              // Carrusel Cover Flow 3D con captura de tap externa para máxima reactividad
              SliverToBoxAdapter(
                child: SizedBox(
                  height: carouselHeight,
                  child: AnimatedBuilder(
                    animation: _pageController,
                    builder: (context, _) {
                      return PageView.builder(
                        controller: _pageController,
                        clipBehavior: Clip.none,
                        physics: const BouncingScrollPhysics(),
                        itemCount: cards.length,
                        onPageChanged: (index) {
                          setState(() {
                            _currentIndex = index;
                          });
                        },
                        itemBuilder: (context, index) {
                          double page = _currentIndex.toDouble();
                          if (_pageController.hasClients &&
                              _pageController.position.haveDimensions) {
                            page = _pageController.page ?? _currentIndex.toDouble();
                          }
                          final double delta = page - index;
                          final card = cards[index];

                          return GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () {
                              TerminalHubDetailScreen.show(context, card);
                            },
                            child: PerspectiveCarouselItem(
                              delta: delta,
                              child: Hero(
                                tag: 'terminal-card-${card.id}',
                                createRectTween: (begin, end) {
                                  return MaterialRectCenterArcTween(
                                    begin: begin,
                                    end: end,
                                  );
                                },
                                flightShuttleBuilder: perspectiveHeroFlight,
                                child: Material(
                                  color: Colors.transparent,
                                  child: TerminalHubSmallCard(
                                    card: card,
                                    compact: compactLandscape || width < 380,
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
              ),

              // Indicadores de navegación y ayuda táctil
              SliverPadding(
                padding: EdgeInsets.only(
                  top: compactLandscape ? 6 : 14,
                  bottom: compactLandscape ? 8 : 24,
                ),
                sliver: SliverToBoxAdapter(
                  child: Column(
                    children: [
                      // Dots de estado
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(cards.length, (i) {
                          final bool isSelected = i == _currentIndex;
                          return AnimatedContainer(
                            duration: const Duration(milliseconds: 260),
                            curve: Curves.easeOutCubic,
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            width: isSelected ? 22 : 6,
                            height: 6,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(3),
                              color: isSelected
                                  ? cards[_currentIndex].accent
                                  : colors.textSecondary.withValues(alpha: 0.25),
                            ),
                          );
                        }),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Toca para abrir visor 3D • Desliza en carrusel',
                        style: TextStyle(
                          color: colors.textSecondary.withValues(alpha: 0.65),
                          fontSize: compactLandscape ? 9.5 : 11.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );

    return Stack(
      fit: StackFit.expand,
      children: [
        const AutomationBackdrop(),
        shell,
      ],
    );
  }
}
