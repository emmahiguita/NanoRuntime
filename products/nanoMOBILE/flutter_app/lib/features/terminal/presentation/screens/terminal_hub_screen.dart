import 'package:flutter/material.dart';
import 'package:nanoai/core/theme/design_tokens.dart';
import 'package:nanoai/core/widgets/nano_screen_shell.dart';
import 'package:nanoai/core/widgets/navigation/nano_navigation_panel.dart'
    show kNanoBarScrollReserve;
import 'package:nanoai/features/automation/presentation/automation_visual_theme.dart';

import '../../domain/terminal_hub_card.dart';
import '../widgets/perspective_carousel_item.dart';
import '../widgets/perspective_hero_flight.dart';
import '../widgets/terminal_coverflow_card.dart';

part 'terminal_hub_cards.part.dart';
part 'terminal_hub_view.part.dart';

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

  void _selectPage(int index) {
    if (mounted) setState(() => _currentIndex = index);
  }

  @override
  Widget build(BuildContext context) => _buildHub(context);
}
