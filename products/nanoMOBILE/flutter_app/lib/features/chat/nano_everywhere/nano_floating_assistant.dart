// Flotante dentro de Nano: posee editor, posicion, acople y apertura del panel.
// Comparte el controlador de acciones; no crea otro motor de automatizacion.
library;

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'nano_3d_flip_transition.dart';
import 'nano_ai_controller.dart';
import 'nano_assistant_panel.dart';
import 'nano_floating_orb.dart';
import 'nano_animation_policy.dart';
import 'nano_floating_system.dart';
part 'nano_floating_assistant_policy.dart';
part 'nano_floating_assistant_view.dart';

class NanoFloatingAssistant extends StatefulWidget {
  const NanoFloatingAssistant({
    super.key,
    required this.controller,
    required this.audioLevel,
    this.onVoice,
    this.onSpeak,
    this.onStopVoice,
    this.initiallyExpanded = false,
    this.inputController,
  });

  final NanoAiController controller;
  final ValueListenable<double> audioLevel;
  final VoidCallback? onVoice;
  final VoidCallback? onStopVoice;
  final ValueChanged<String>? onSpeak;
  final bool initiallyExpanded;
  final TextEditingController? inputController;

  @override
  State<NanoFloatingAssistant> createState() => _NanoFloatingAssistantState();
}

class _NanoFloatingAssistantState extends State<NanoFloatingAssistant>
    with SingleTickerProviderStateMixin, NanoAnimationPolicy {
  late final TextEditingController input;
  late bool expanded;
  bool isVisible = false;
  bool _dragging = false;
  Offset position = const Offset(12, 300);

  // Animador magnético iOS (snap-to-edge)
  late final AnimationController _snapController;
  Animation<Offset>? _snapAnimation;
  Offset? _snapDestination;

  // Atenuación sutil tras inactividad (iOS AssistiveTouch idle dimming)
  Timer? _idleTimer;
  double _opacity = 1.0;

  Orientation? _lastOrientation;

  /// Owns input, controller subscription and the original 320 ms snap clock.
  @override
  void initState() {
    super.initState();
    expanded = widget.initiallyExpanded;
    isVisible = widget.controller.isVisible;
    input = widget.inputController ?? TextEditingController();
    widget.controller.addListener(_sync);

    _snapController =
        AnimationController(
            vsync: this,
            duration: const Duration(milliseconds: 320),
          )
          ..addListener(() {
            if (_snapAnimation != null) {
              setState(() {
                position = _snapAnimation!.value;
              });
            }
          })
          ..addStatusListener((status) {
            if (status == AnimationStatus.completed && _snapAnimation != null) {
              setState(() => _snapAnimation = null);
            }
          });

    _startIdleTimer();
  }

  /// Stops hidden/reduced motion and restarts idle timing only when allowed.
  @override
  void onMotionPolicyChanged() {
    if (!motionEnabled) {
      _settleSnap();
      _idleTimer?.cancel();
      _opacity = 1;
    } else {
      _startIdleTimer();
    }
  }

  /// Repositions only on orientation changes and cancels the old snap target.
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final ori = MediaQuery.orientationOf(context);
    if (_lastOrientation != null && _lastOrientation != ori) {
      _snapController.stop();
      _snapAnimation = null;
      final size = MediaQuery.sizeOf(context);
      setState(() {
        position = Offset(10, size.height * 0.35);
      });
    }
    _lastOrientation = ori;
  }

  /// Rebinds the external assistant without retaining the replaced listener.
  @override
  void didUpdateWidget(covariant NanoFloatingAssistant oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller == widget.controller) return;
    oldWidget.controller.removeListener(_sync);
    widget.controller.addListener(_sync);
    _sync();
  }

  /// Applies external visibility and pending input, then cancels hidden clocks.
  void _sync() {
    if (!mounted) return;
    if (widget.controller.checkAndClearExpandRequest()) {
      expanded = true;
      isVisible = true;
      _wakeUp();
    }
    if (widget.controller.isVisible != isVisible) {
      isVisible = widget.controller.isVisible;
      _wakeUp();
    }
    final pending = widget.controller.takePendingPrompt(
      currentText: input.text,
    );
    if (pending != null) {
      input.text = pending;
      input.selection = TextSelection.collapsed(offset: pending.length);
      expanded = true;
      isVisible = true;
      _wakeUp();
    }
    // Un retorno restaura el orbe compacto, no un panel que quedó abierto.
    if (!isVisible) {
      expanded = false;
      _settleSnap();
    }
    setState(() {});
  }

  @override
  void dispose() {
    _idleTimer?.cancel();
    _snapController.dispose();
    widget.controller.removeListener(_sync);
    if (widget.inputController == null) input.dispose();
    super.dispose();
  }

  /// La X cierra ambos accesos de la sesión y su voz. Minimizar sigue siendo
  /// otra acción: conserva el acceso externo y el borrador compartido.
  void _dismissAssistant() {
    widget.onStopVoice?.call();
    final owner = widget.controller;
    unawaited(
      const NanoFloatingSystem().hide().catchError((Object error) {
        if (error is! MissingPluginException && !owner.isDisposed) {
          owner.reportStatus('No se confirmó el cierre del acceso externo.');
        }
      }),
    );
    HapticFeedback.lightImpact();
    setState(() {
      expanded = false;
      isVisible = false;
    });
    widget.controller.hide();
  }

  /// Delegates layout while retaining this State as the sole clock owner.
  @override
  Widget build(BuildContext context) => buildView(context);
}
