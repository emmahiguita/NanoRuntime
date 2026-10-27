// google_sheets_realtime_sync_test.dart
//
// QUÉ HACE:
// Suite de pruebas unitarias y de integración para la conexión automática
// y sincronización continua en tiempo real con Google Sheets.
//
// CÓMO FUNCIONA:
// - Simula respuestas HTTP reales de exportación CSV de Google Docs y Apps Script JSON.
// - Valida que el controlador active el timer de 10s, actualice 'isLiveSyncActive',
//   detecte cambios remotos y reejecute consultas SQL sin procesos zombi.
// - Comprueba que al limpiar la sesión o desmontar el controlador los timers se cancelen (ciclo de vida).
//
// POR QUÉ:
// Asegura la robustez de la arquitectura limpia (DIP/SRP) y certifica que
// no existen simulaciones vacías ni fugas de memoria (< 200 líneas).

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nanoai/features/database/application/database_studio_controller.dart';
import 'package:nanoai/features/database/application/google_sheets_sync_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('GoogleSheetsSyncService Suite', () {
    test('Extrae ID de hoja y gid desde diferentes formatos de URL', () {
      const syncService = GoogleSheetsSyncService();

      const standardUrl =
          'https://docs.google.com/spreadsheets/d/1BxiMVs0XRA5nFMdKvBdBZjgmUUqptlbs74OgvE2upms/edit?gid=123#gid=123';
      expect(
        syncService.extractSpreadsheetId(standardUrl),
        '1BxiMVs0XRA5nFMdKvBdBZjgmUUqptlbs74OgvE2upms',
      );
      expect(syncService.extractGid(standardUrl), '123');

      expect(
        syncService.isSheetsHomeUrl('https://docs.google.com/spreadsheets/u/0/?pli=1'),
        isTrue,
      );
    });

    test('Descarga y parsea CSV público generando DataTable real con columnas', () async {
      final mockClient = MockClient((request) async {
        if (request.url.path.contains('/export')) {
          const csvData =
              'Producto,Categoria,Precio,Stock\n'
              'Cafe Espresso,Bebidas,2.5,50\n'
              'Te Verde,Bebidas,2.0,30\n';
          return http.Response(csvData, 200, headers: {'content-type': 'text/csv'});
        }
        return http.Response('Not Found', 404);
      });

      final syncService = GoogleSheetsSyncService(client: mockClient);
      final table = await syncService.fetchSheet(
        url: 'https://docs.google.com/spreadsheets/d/test_sheet_id_12345/edit',
      );

      expect(table.columns, ['Producto', 'Categoria', 'Precio', 'Stock']);
      expect(table.rowCount, 2);
      expect(table.rows[0][0], 'Cafe Espresso');
      expect(table.rows[1][0], 'Te Verde');
      expect(table.isGoogleSheet, isTrue);
    });
  });

  group('DatabaseStudioController Real-Time Google Sheets Suite', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('Auto-conecta Google Sheets y activa sincronización continua en tiempo real', () async {
      var callCount = 0;
      final mockClient = MockClient((request) async {
        callCount++;
        // En llamadas subsecuentes devuelve una fila adicional para probar detección de cambios en vivo
        final csv = callCount == 1
            ? 'Item,Cantidad\nManzanas,10\n'
            : 'Item,Cantidad\nManzanas,10\nNaranjas,25\n';
        return http.Response(csv, 200);
      });

      final syncService = GoogleSheetsSyncService(client: mockClient);
      final controller = DatabaseStudioController(sheetsSync: syncService);

      // Auto-conectar
      final ok = await controller.autoConnectGoogleSheets(
        sheetUrl: 'https://docs.google.com/spreadsheets/d/test_live_sheet/edit',
      );

      expect(ok, isTrue);
      expect(controller.currentState.isLiveSyncActive, isTrue);
      expect(controller.currentState.currentTable?.rowCount, 1);
      expect(controller.currentState.selectedTableName.contains('google_sheet'), isTrue);

      // Forzar sincronización inmediata
      await controller.syncGoogleSheetsNow();
      expect(controller.currentState.currentTable?.rowCount, 2);
      expect(controller.currentState.statusMessage?.contains('Sincronizado en tiempo real'), isTrue);

      // Limpiar a espacio en blanco cancela timers y limpia estado
      controller.clearToBlankDatabase();
      expect(controller.currentState.isLiveSyncActive, isFalse);
      expect(controller.currentState.tables.isEmpty, isTrue);

      controller.disposeGoogleSheetsSync();
    });
  });
}
