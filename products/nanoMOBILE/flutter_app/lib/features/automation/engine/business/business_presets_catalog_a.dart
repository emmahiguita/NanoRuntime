part of 'business_presets.dart';

// Plantillas 1-3: servicios presenciales, comercio y restaurante.
const barberPreset = BusinessPreset(
  id: 'barbershop',
  title: 'Barbería',
  description: 'Servicios, precios, reservas, cancelaciones y agenda.',
  icon: Icons.content_cut_rounded,
  tone: ToneProfile(enabled: true, warmth: ToneWarmth.cercano),
  profile: BusinessProfile(
    templateId: 'barbershop.es-co.v1',
    sector: 'BARBERSHOP',
    intents: [
      'PRICE_QUERY',
      'SERVICE_QUERY',
      'BOOK_APPOINTMENT',
      'CANCEL_APPOINTMENT',
    ],
    tools: ['calendar.availability', 'calendar.book', 'calendar.cancel'],
    dialogues: [
      BusinessDialogue(
        id: 'book_appointment',
        intent: 'BOOK_APPOINTMENT',
        requiredSlots: ['serviceId', 'date', 'time'],
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
        id: 'complaint-handoff',
        condition: 'COMPLAINT',
        action: 'HANDOFF',
        priority: 'HIGH',
      ),
    ],
  ),
);

const retailPreset = BusinessPreset(
  id: 'retail',
  title: 'Tienda / Comercio',
  description: 'Catálogo, stock, precios, pedidos, estado y devoluciones.',
  icon: Icons.storefront_outlined,
  tone: ToneProfile(
    enabled: true,
    sales: ToneSales.persuasivo,
    warmth: ToneWarmth.cercano,
    emojis: true,
    verbosity: ToneVerbosity.breve,
  ),
  profile: BusinessProfile(
    templateId: 'retail.es.v1',
    sector: 'RETAIL',
    intents: [
      'PRODUCT_SEARCH',
      'PRICE_QUERY',
      'STOCK_QUERY',
      'CREATE_ORDER',
      'ORDER_STATUS',
      'RETURN',
      'HUMAN_SUPPORT',
    ],
    tools: [
      'catalog.search',
      'inventory.get_stock',
      'orders.create',
      'orders.status',
    ],
    dialogues: [
      BusinessDialogue(
        id: 'order',
        intent: 'CREATE_ORDER',
        requiredSlots: ['productId', 'quantity', 'contact'],
        steps: [
          'collect_product',
          'check_stock',
          'collect_quantity',
          'confirm',
        ],
      ),
    ],
  ),
);

const restaurantPreset = BusinessPreset(
  id: 'restaurant',
  title: 'Restaurante',
  description: 'Menú, reservas, domicilios, horarios y alérgenos.',
  icon: Icons.restaurant_outlined,
  tone: ToneProfile(
    enabled: true,
    sales: ToneSales.persuasivo,
    warmth: ToneWarmth.cercano,
    emojis: true,
  ),
  profile: BusinessProfile(
    templateId: 'restaurant.es.v1',
    sector: 'RESTAURANT',
    intents: [
      'MENU',
      'RESERVATION',
      'DELIVERY_ORDER',
      'OPENING_HOURS',
      'ALLERGEN_QUERY',
    ],
    tools: [
      'menu.search',
      'tables.availability',
      'reservations.create',
      'orders.create',
    ],
    dialogues: [
      BusinessDialogue(
        id: 'reservation',
        intent: 'RESERVATION',
        requiredSlots: ['partySize', 'date', 'time', 'name'],
        steps: [
          'collect_party',
          'collect_date',
          'collect_time',
          'check_availability',
          'confirm',
        ],
      ),
    ],
  ),
);
