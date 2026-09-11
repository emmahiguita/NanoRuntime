import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nanoai/core/theme/app_theme.dart';
import 'package:nanoai/features/automation/engine/business/business_facts.dart';
import 'package:nanoai/features/automation/engine/business/business_facts_providers.dart';
import 'package:nanoai/features/automation/presentation/screens/business_studio_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<void> pumpBusinessStudio(
    WidgetTester tester, {
    Size size = const Size(390, 844),
    BusinessFacts initialFacts = const BusinessFacts(),
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          businessFactsStoreProvider.overrideWithValue(
            _MemoryBusinessFactsStore(initialFacts),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.dark,
          home: const BusinessStudioScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('renders BusinessStudioScreen with all 5 sections and empty state', (
    tester,
  ) async {
    await pumpBusinessStudio(tester);

    expect(find.text('WhatsApp Negocio'), findsOneWidget);
    expect(find.text('Control total de ventas, catálogo, pagos y atención'), findsOneWidget);
    expect(find.text('MODO DE ATENCIÓN Y SUPERVISIÓN'), findsOneWidget);
    expect(find.text('ESTRATEGIA Y TONO DE VENTA'), findsOneWidget);
    expect(find.text('CATÁLOGO COMERCIAL'), findsOneWidget);
    expect(find.text('PAGOS, UBICACIÓN Y POLÍTICAS'), findsOneWidget);
    expect(find.text('PLANTILLAS RÁPIDAS'), findsOneWidget);
    expect(find.text('Sin productos configurados'), findsOneWidget);
    expect(find.text('Métodos de pago y transferencias'), findsOneWidget);
    expect(find.text('Ubicación o dirección'), findsOneWidget);
    expect(find.text('Horario de atención'), findsOneWidget);
    expect(find.text('Envíos y domicilios'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('renders products, payments and location properly when facts are populated', (
    tester,
  ) async {
    const facts = BusinessFacts(
      hours: 'Lun a Vie 8am - 6pm',
      delivery: 'Envíos a todo el país',
      payments: 'Nequi al 3001234567 o Bancolombia',
      location: 'Calle 10 # 40-20, Medellín',
      products: [
        BusinessProduct(
          id: 'p1',
          name: 'Hamburguesa Artesanal',
          details: 'Doble carne con queso',
          price: 25000,
          stock: 10,
        ),
        BusinessProduct(
          id: 'p2',
          name: 'Cerveza Club Colombia',
          details: '330ml',
          price: 6000,
          stock: 50,
        ),
      ],
    );

    await pumpBusinessStudio(tester, initialFacts: facts);

    expect(find.text('Hamburguesa Artesanal'), findsOneWidget);
    expect(find.text('Cerveza Club Colombia'), findsOneWidget);
    expect(find.text('Lun a Vie 8am - 6pm'), findsOneWidget);
    expect(find.text('Envíos a todo el país'), findsOneWidget);
    expect(find.text('Nequi al 3001234567 o Bancolombia'), findsOneWidget);
    expect(find.text('Calle 10 # 40-20, Medellín'), findsOneWidget);
    expect(find.text('Sin productos configurados'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('renders cleanly on compact screen (320px width)', (
    tester,
  ) async {
    await pumpBusinessStudio(tester, size: const Size(320, 568));

    expect(find.text('WhatsApp Negocio'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

class _MemoryBusinessFactsStore extends BusinessFactsStore {
  _MemoryBusinessFactsStore(this.facts);
  BusinessFacts facts;

  @override
  Future<BusinessFacts> load() async => facts;

  @override
  Future<bool> save(BusinessFacts next) async {
    facts = next;
    return true;
  }
}
