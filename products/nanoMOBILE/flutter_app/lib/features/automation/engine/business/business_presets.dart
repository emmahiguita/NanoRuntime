/// WA-BUSINESS-PRESETS — plantillas de negocio sin simulación (FASE 11).
///
/// Clean Architecture: Presets inmutables y puros.
/// Configuran el tono comercial recomendado, enfoque de venta, extensión y emojis
/// para cada rubro. Los datos comerciales factuales (precios, cuentas de pago,
/// stock y direcciones) NO se inventan: deben ser ingresados explícitamente por el dueño.
library;

import 'package:flutter/material.dart' show IconData, Icons;
import '../messaging/tone_profile.dart';
import 'business_dialogue.dart';
import 'business_profile.dart';
import 'business_rule.dart';

part 'business_presets_catalog_a.dart';
part 'business_presets_catalog_b.dart';
part 'business_presets_catalog_c.dart';

final class BusinessPreset {
  final String id;
  final String title;
  final String description;
  final IconData icon;
  final ToneProfile tone;
  final BusinessProfile profile;

  const BusinessPreset({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
    required this.tone,
    required this.profile,
  });
}

abstract final class BusinessPresetsCatalog {
  static const presets = <BusinessPreset>[
    barberPreset,
    retailPreset,
    restaurantPreset,
    workshopPreset,
    hotelPreset,
    clinicPreset,
    realEstatePreset,
    ecommercePreset,
    supportPreset,
    customPreset,
  ];
}
