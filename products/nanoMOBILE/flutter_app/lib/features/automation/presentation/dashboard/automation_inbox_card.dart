/// AUTOMATION-INBOX-CARD — Tarjeta 3D del Centro de Mensajería con luz teatral.
///
/// QUÉ HACE:
/// Proporciona el punto de entrada de alto impacto visual para el Centro de Mensajería
/// y Nano Negocio mediante la tarjeta tridimensional interactiva y reversible.
///
/// CÓMO FUNCIONA:
/// Aloja [SpotlightFlipAdCard] integrando [MessagingAdvertisement] (anverso) y
/// [BusinessAdvertisement] (reverso), adaptando la relación de aspecto según la orientación.
///
/// POR QUÉ:
/// Centraliza la experiencia publicitaria 3D respetando el límite estricto de menos
/// de 200 líneas y el desacoplamiento estricto de responsabilidades.
library;

import 'package:flutter/material.dart';
import '../widgets/business_advertisement.dart';
import '../widgets/messaging_advertisement.dart';
import '../widgets/spotlight_flip_ad_card.dart';

class AutomationInboxCard extends StatelessWidget {
  final VoidCallback onTap;

  const AutomationInboxCard({
    super.key,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;

    return SpotlightFlipAdCard(
      heroTag: 'nano_messaging_hero',
      aspectRatio: isLandscape ? 2.4 : (16 / 9),
      front: const MessagingAdvertisement(),
      back: const BusinessAdvertisement(),
      onOpen: onTap,
    );
  }
}
