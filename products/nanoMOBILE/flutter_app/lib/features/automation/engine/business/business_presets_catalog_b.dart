part of 'business_presets.dart';

// Plantillas 6-10: salud administrativa, inmuebles, e-commerce, soporte y libre.
const clinicPreset = BusinessPreset(
  id: 'clinic',
  title: 'Consultorio',
  description: 'Agenda administrativa, horario y ubicación; sin diagnóstico.',
  icon: Icons.local_hospital_outlined,
  tone: ToneProfile(enabled: true, warmth: ToneWarmth.formal),
  profile: BusinessProfile(
    templateId: 'clinic-appointments.es.v1',
    sector: 'CLINIC',
    intents: [
      'BOOK_APPOINTMENT',
      'RESCHEDULE',
      'CANCEL_APPOINTMENT',
      'OPENING_HOURS',
      'LOCATION',
    ],
    blockedAutomation: ['DIAGNOSIS', 'PRESCRIPTION', 'SENSITIVE_MEDICAL_DATA'],
    tools: ['calendar.availability', 'calendar.book'],
    dialogues: [
      BusinessDialogue(
        id: 'appointment',
        intent: 'BOOK_APPOINTMENT',
        requiredSlots: ['service', 'date', 'time'],
        steps: [
          'collect_service',
          'collect_date',
          'check_availability',
          'collect_time',
          'confirm',
        ],
      ),
    ],
    rules: [
      BusinessRule(
        id: 'clinical-handoff',
        condition: 'MEDICAL_ADVICE',
        action: 'HANDOFF',
        priority: 'HIGH',
      ),
    ],
  ),
);

const realEstatePreset = BusinessPreset(
  id: 'realestate',
  title: 'Inmobiliaria',
  description: 'Búsqueda de inmuebles, filtros y programación de visitas.',
  icon: Icons.apartment_rounded,
  tone: ToneProfile(
    enabled: true,
    sales: ToneSales.persuasivo,
    warmth: ToneWarmth.formal,
  ),
  profile: BusinessProfile(
    templateId: 'realestate.es.v1',
    sector: 'REAL_ESTATE',
    intents: [
      'PROPERTY_SEARCH',
      'BOOK_VIEWING',
      'PROPERTY_DETAILS',
      'HUMAN_SUPPORT',
    ],
    tools: ['properties.search', 'viewings.availability', 'viewings.book'],
    dialogues: [
      BusinessDialogue(
        id: 'property_search',
        intent: 'PROPERTY_SEARCH',
        requiredSlots: ['operation', 'city', 'zone', 'budget', 'bedrooms'],
        steps: [
          'collect_filters',
          'search_properties',
          'present_options',
          'offer_viewing',
        ],
      ),
    ],
  ),
);

const ecommercePreset = BusinessPreset(
  id: 'ecommerce',
  title: 'E-commerce',
  description: 'Productos, carrito, checkout, entrega, devolución y reembolso.',
  icon: Icons.shopping_cart_checkout_rounded,
  tone: ToneProfile(
    enabled: true,
    sales: ToneSales.persuasivo,
    warmth: ToneWarmth.cercano,
    emojis: true,
  ),
  profile: BusinessProfile(
    templateId: 'ecommerce.es.v1',
    sector: 'ECOMMERCE',
    intents: [
      'PRODUCT_SEARCH',
      'CART',
      'CHECKOUT',
      'SHIPPING_STATUS',
      'RETURN',
      'REFUND',
    ],
    tools: ['catalog.search', 'cart.add', 'orders.create', 'shipping.track'],
    dialogues: [
      BusinessDialogue(
        id: 'checkout',
        intent: 'CHECKOUT',
        requiredSlots: ['items', 'deliveryAddress', 'paymentMethod'],
        steps: [
          'review_cart',
          'collect_delivery',
          'collect_payment',
          'confirm',
        ],
      ),
    ],
  ),
);

const supportPreset = BusinessPreset(
  id: 'support',
  title: 'Soporte',
  description: 'Base de conocimiento, diagnóstico guiado y tickets.',
  icon: Icons.support_agent_rounded,
  tone: ToneProfile(enabled: true, warmth: ToneWarmth.formal),
  profile: BusinessProfile(
    templateId: 'support.es.v1',
    sector: 'CUSTOMER_SUPPORT',
    intents: [
      'HOW_TO',
      'INCIDENT',
      'BUG',
      'BILLING',
      'CANCELLATION',
      'HUMAN_SUPPORT',
    ],
    tools: ['kb.search', 'tickets.create', 'tickets.status'],
    dialogues: [
      BusinessDialogue(
        id: 'incident',
        intent: 'INCIDENT',
        requiredSlots: ['summary', 'impact'],
        steps: [
          'collect_issue',
          'search_kb',
          'offer_solution',
          'create_ticket_if_unresolved',
        ],
      ),
    ],
    rules: [
      BusinessRule(
        id: 'billing-priority',
        condition: 'BILLING',
        action: 'HANDOFF',
        priority: 'MEDIUM',
      ),
      BusinessRule(
        id: 'cancellation-priority',
        condition: 'CANCELLATION',
        action: 'HANDOFF',
        priority: 'HIGH',
      ),
    ],
  ),
);

const customPreset = BusinessPreset(
  id: 'custom',
  title: 'Personalizado',
  description: 'Contrato vacío y editable para cualquier negocio.',
  icon: Icons.tune_rounded,
  tone: ToneProfile(enabled: true, warmth: ToneWarmth.cercano),
  profile: BusinessProfile(templateId: 'custom.v1', sector: 'CUSTOM'),
);
