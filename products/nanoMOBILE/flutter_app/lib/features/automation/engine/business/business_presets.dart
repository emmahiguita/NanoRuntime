/// WA-BUSINESS-PRESETS — plantillas de negocio sin simulación (FASE 11).
///
/// Clean Architecture: Presets inmutables y puros.
/// Configuran el tono comercial recomendado, enfoque de venta, extensión y emojis
/// para cada rubro. Los datos comerciales factuales (precios, cuentas de pago,
/// stock y direcciones) NO se inventan: deben ser ingresados explícitamente por el dueño.
library;

import 'package:flutter/material.dart' show IconData, Icons;
import '../messaging/tone_profile.dart';
import 'business_facts.dart';

final class BusinessPreset {
  final String id;
  final String title;
  final String description;
  final IconData icon;
  final ToneProfile tone;
  final BusinessFacts facts;

  const BusinessPreset({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
    required this.tone,
    this.facts = const BusinessFacts(),
  });
}

abstract final class BusinessPresetsCatalog {
  static const presets = <BusinessPreset>[
    BusinessPreset(
      id: 'retail',
      title: 'Tienda de Ropa / Comercio',
      description: 'Estrategia comercial persuasiva, respuestas ágiles con emojis y enfoque en catálogo.',
      icon: Icons.shopping_bag_outlined,
      tone: ToneProfile(
        enabled: true,
        sales: ToneSales.persuasivo,
        warmth: ToneWarmth.cercano,
        emojis: true,
        verbosity: ToneVerbosity.breve,
      ),
      facts: BusinessFacts(),
    ),
    BusinessPreset(
      id: 'restaurant',
      title: 'Restaurante / Cafetería',
      description: 'Atención cercana y persuasiva, agilidad en consultas de menú y domicilios.',
      icon: Icons.restaurant_outlined,
      tone: ToneProfile(
        enabled: true,
        sales: ToneSales.persuasivo,
        warmth: ToneWarmth.cercano,
        emojis: true,
        verbosity: ToneVerbosity.media,
      ),
      facts: BusinessFacts(),
    ),
    BusinessPreset(
      id: 'services',
      title: 'Servicios / Freelance',
      description: 'Enfoque claro e informativo sin presión, asesoría profesional y directa.',
      icon: Icons.work_outline_rounded,
      tone: ToneProfile(
        enabled: true,
        sales: ToneSales.natural,
        warmth: ToneWarmth.cercano,
        emojis: false,
        verbosity: ToneVerbosity.media,
      ),
      facts: BusinessFacts(),
    ),
    BusinessPreset(
      id: 'clinic',
      title: 'Consultorio / Salud',
      description: 'Trato formal y respetuoso de usted, sobrio sin emojis, enfocado en citas.',
      icon: Icons.local_hospital_outlined,
      tone: ToneProfile(
        enabled: true,
        sales: ToneSales.natural,
        warmth: ToneWarmth.formal,
        emojis: false,
        verbosity: ToneVerbosity.media,
      ),
      facts: BusinessFacts(),
    ),
    BusinessPreset(
      id: 'courses',
      title: 'Cursos / Academia',
      description: 'Tono cercano e inspirador con enfoque persuasivo en inscripciones y programas.',
      icon: Icons.school_outlined,
      tone: ToneProfile(
        enabled: true,
        sales: ToneSales.persuasivo,
        warmth: ToneWarmth.cercano,
        emojis: true,
        verbosity: ToneVerbosity.media,
      ),
      facts: BusinessFacts(),
    ),
  ];
}
