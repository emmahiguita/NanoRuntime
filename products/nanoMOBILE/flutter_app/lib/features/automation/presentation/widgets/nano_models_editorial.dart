import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../automation_visual_theme.dart';

/// Bloque editorial tipográfico suelto (sin contenedor ni tarjeta) sobre modelos on-device en Nano AI.
class NanoModelsEditorial extends StatefulWidget {
  const NanoModelsEditorial({super.key});

  @override
  State<NanoModelsEditorial> createState() => _NanoModelsEditorialState();
}

class _NanoModelsEditorialState extends State<NanoModelsEditorial>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animCtrl;
  late final Animation<double> _pulseScale;
  late final Animation<double> _pulseOpacity;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    );
    _pulseScale = Tween<double>(
      begin: 0.90,
      end: 1.15,
    ).animate(CurvedAnimation(parent: _animCtrl, curve: Curves.easeInOut));
    _pulseOpacity = Tween<double>(
      begin: 0.65,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _animCtrl, curve: Curves.easeInOut));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final canAnimate =
        !MediaQuery.disableAnimationsOf(context) && TickerMode.of(context);
    if (canAnimate && !_animCtrl.isAnimating) {
      _animCtrl.repeat(reverse: true);
    } else if (!canAnimate) {
      _animCtrl
        ..stop()
        ..value = 0.5;
    }
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final visual = AutomationVisual.of(context);

    return Padding(
      padding: const EdgeInsets.only(left: 2, right: 2, bottom: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Eyebrow / Metadato editorial ────────────────────────────────
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              ScaleTransition(
                scale: _pulseScale,
                child: FadeTransition(
                  opacity: _pulseOpacity,
                  child: Container(
                    width: 7.0,
                    height: 7.0,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: visual.accent,
                      boxShadow: [
                        BoxShadow(
                          color: visual.accent.withValues(alpha: 0.40),
                          blurRadius: 4,
                          spreadRadius: 0.5,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'INFERENCIA EN SILICIO LOCAL',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.1,
                  color: visual.textMuted.withValues(alpha: 0.88),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // ── Título editorial jerárquico ───────────────────────────────────
          Text(
            'Prueba Qwen y Gemma en tu dispositivo',
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 21,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.4,
              height: 1.25,
              color: visual.text,
            ),
          ),
          const SizedBox(height: 8),

          // ── Párrafo editorial sobrio (texto neutral de alto contraste) ────
          RichText(
            text: TextSpan(
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 13.5,
                height: 1.48,
                color: visual.textMuted.withValues(alpha: 0.90),
              ),
              children: [
                const TextSpan(
                  text:
                      'Descubre el poder de la IA integrada con aceleración local sin servidores externos. Ejecuta ',
                ),
                TextSpan(
                  text: 'Qwen',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: visual.text,
                  ),
                ),
                const TextSpan(text: ' y '),
                TextSpan(
                  text: 'Gemma',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: visual.text,
                  ),
                ),
                const TextSpan(
                  text:
                      ' en el Chat de IA, los Agentes Autónomos o en las herramientas de sistema.',
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // ── Enlace de acción principal unificado ──────────────────────────
          InkWell(
            onTap: () {
              HapticFeedback.lightImpact();
              context.push('/models');
            },
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Explorar catálogo y motores locales',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: visual.accent,
                    ),
                  ),
                  const SizedBox(width: 5),
                  Icon(
                    Icons.arrow_forward_rounded,
                    size: 14,
                    color: visual.accent,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
