part of 'terminal_hub_screen.dart';

/// Conserva la navegación y el carrusel, adaptados al espacio disponible.
extension _TerminalHubView on _TerminalHubScreenState {
  Widget _buildHub(BuildContext context) {
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
              ? (constraints.maxHeight - 127).clamp(140.0, 180.0)
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
                          _selectPage(index);
                        },
                        itemBuilder: (context, index) {
                          double page = _currentIndex.toDouble();
                          if (_pageController.hasClients &&
                              _pageController.position.haveDimensions) {
                            page =
                                _pageController.page ??
                                _currentIndex.toDouble();
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
                                    compact: compactLandscape,
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
                  bottom: compactLandscape ? 84.0 : kNanoBarScrollReserve,
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
                                  : colors.textSecondary.withValues(
                                      alpha: 0.25,
                                    ),
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
      children: [const AutomationBackdrop(), shell],
    );
  }
}
