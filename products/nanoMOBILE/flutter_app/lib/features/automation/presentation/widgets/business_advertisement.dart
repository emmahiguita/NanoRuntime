/// BUSINESS-ADVERTISEMENT — Publicidad posterior de la card 3D (Nano Negocio).
///
/// QUÉ HACE:
/// Muestra la nueva publicidad del reverso en formato 16:9 sin cortes:
/// "Tu Negocio en Piloto Automático con NanoRuntime" (Agentes, Cero Latencia, Control Total).
///
/// CÓMO FUNCIONA:
/// Aloja `card_business_runtime.jpg` (1024x572, 16:9) alineado perfectamente
/// con la geometría de la tarjeta 3D, e integra badges reactivos de estado comercial.
///
/// POR QUÉ:
/// Ofrece una experiencia de publicidad simétrica entre anverso y reverso eliminando
/// desbordes laterales y respetando la regla estricta de < 200 líneas de código.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../engine/business/business_facts_providers.dart';

class BusinessAdvertisement extends ConsumerWidget {
  const BusinessAdvertisement({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final businessFacts = ref.watch(businessFactsNotifierProvider);
    final count = businessFacts.products.length;

    return Stack(
      fit: StackFit.expand,
      children: [
        // 1. Imagen publicitaria oficial de NanoRuntime en 16:9
        Image.asset(
          'assets/promo/card_business_runtime.jpg',
          fit: BoxFit.cover,
          alignment: Alignment.center,
        ),
        // 2. Badge superior derecho: Indicador de Negocio Autónomo / Catálogo
        Positioned(
          top: 8,
          right: 10,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
            decoration: BoxDecoration(
              color: const Color(0xFF00FF88),
              borderRadius: BorderRadius.circular(10),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF00FF88).withValues(alpha: 0.40),
                  blurRadius: 6,
                ),
              ],
            ),
            child: Text(
              count > 0 ? '$count PRODUCTOS' : 'NANORUNTIME',
              style: const TextStyle(
                color: Colors.black,
                fontSize: 9,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.2,
              ),
            ),
          ),
        ),
        // 3. Etiqueta reverso
        Positioned(
          bottom: 8,
          left: 10,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.55),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: const Color(0xFF00FF88).withValues(alpha: 0.35),
                width: 0.8,
              ),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.terminal_rounded, size: 9, color: Color(0xFF00FF88)),
                SizedBox(width: 3),
                Text(
                  'REVERSO • NEGOCIO',
                  style: TextStyle(
                    color: Color(0xFF00FF88),
                    fontSize: 8,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
