part of 'business_presets.dart';

// Plantillas 4-5: taller y hotel.
const workshopPreset = BusinessPreset(
  id: 'workshop',
  title: 'Taller',
  description: 'Servicio, inspección, presupuesto y estado de orden.',
  icon: Icons.car_repair_rounded,
  tone: ToneProfile(enabled: true, warmth: ToneWarmth.formal),
  profile: BusinessProfile(
    templateId: 'workshop.es.v1',
    sector: 'VEHICLE_SERVICE',
    intents: [
      'SERVICE_QUERY',
      'BOOK_INSPECTION',
      'QUOTE_REQUEST',
      'ORDER_STATUS',
    ],
    tools: [
      'workorders.create',
      'calendar.availability',
      'calendar.book',
      'workorders.status',
    ],
    dialogues: [
      BusinessDialogue(
        id: 'inspection',
        intent: 'BOOK_INSPECTION',
        requiredSlots: ['vehicle', 'issue', 'date'],
        steps: [
          'collect_vehicle',
          'collect_issue',
          'collect_date',
          'check_availability',
          'confirm',
        ],
      ),
    ],
    rules: [
      BusinessRule(
        id: 'high-quote',
        condition: 'quoteAmountGreaterThan:500000',
        action: 'REQUIRE_HUMAN_APPROVAL',
        priority: 'HIGH',
      ),
    ],
  ),
);

const hotelPreset = BusinessPreset(
  id: 'hotel',
  title: 'Hotel',
  description: 'Disponibilidad, tarifas, reservas y modificaciones.',
  icon: Icons.hotel_outlined,
  tone: ToneProfile(enabled: true, warmth: ToneWarmth.formal),
  profile: BusinessProfile(
    templateId: 'hotel.es.v1',
    sector: 'HOTEL',
    intents: [
      'ROOM_AVAILABILITY',
      'RATE_QUERY',
      'BOOKING',
      'MODIFY_BOOKING',
      'CANCEL_BOOKING',
    ],
    tools: ['rooms.availability', 'reservations.quote', 'reservations.create'],
    dialogues: [
      BusinessDialogue(
        id: 'booking',
        intent: 'BOOKING',
        requiredSlots: ['checkIn', 'checkOut', 'guests', 'roomType'],
        steps: [
          'collect_dates',
          'collect_guests',
          'check_availability',
          'quote',
          'confirm',
        ],
      ),
    ],
  ),
);
