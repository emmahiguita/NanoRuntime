import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nanoai/features/automation/application/automation_coordinator_provider.dart';
import 'package:nanoai/features/automation/domain/messaging_platform.dart';
import 'package:nanoai/features/automation/engine/messaging/conversation_agent.dart';
import 'package:nanoai/features/automation/engine/messaging/conversation_hub_providers.dart';
import 'package:nanoai/features/automation/personal_agent/application/conversation_ownership_policy.dart';
import 'package:nanoai/features/automation/personal_agent/domain/conversation_owner.dart';
import 'package:nanoai/features/automation/presentation/messaging_center/conversation_hub_action_controller.dart';
import 'package:nanoai/features/automation/presentation/messaging_center/messaging_center_providers.dart';
import 'package:nanoai/features/automation/presentation/messaging_center/messaging_dedup_merger.dart';
import 'package:nanoai/features/automation/presentation/widgets/conversation_media_bubble.dart';
import 'package:nanoai/features/automation/presentation/widgets/link_metadata_service.dart';
import 'package:nanoai/features/automation/presentation/widgets/floating_video_overlay.dart';
import 'package:nanoai/features/automation/engine/scheduling/rule_registry.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('com.nanoai/automation_store'),
          (MethodCall call) async {
            if (call.method == 'put') return true;
            if (call.method == 'loadAll') return <String, String>{};
            return null;
          },
        );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('com.nanoai/notifications'),
          (MethodCall call) async {
            if (call.method == 'status') {
              return {'listenerConnected': true, 'permissionGranted': true};
            }
            if (call.method == 'getActiveNotifications') return <dynamic>[];
            return null;
          },
        );
  });
  group('Messaging Center Domain & Platform Mapping', () {
    test('Identifica WhatsApp correctamente por packageName', () {
      expect(
        MessagingPlatform.fromPackageName('com.whatsapp'),
        equals(MessagingPlatform.whatsapp),
      );
      expect(
        MessagingPlatform.fromPackageName('com.whatsapp.w4b'),
        equals(MessagingPlatform.whatsappBusiness),
      );
    });

    test('Identifica Telegram correctamente', () {
      expect(
        MessagingPlatform.fromPackageName('org.telegram.messenger'),
        equals(MessagingPlatform.telegram),
      );
      expect(
        MessagingPlatform.fromPackageName('org.telegram.plus'),
        equals(MessagingPlatform.telegram),
      );
    });

    test('Identifica Gmail, Slack, Instagram, Facebook, X, LinkedIn', () {
      expect(
        MessagingPlatform.fromPackageName('com.google.android.gm'),
        equals(MessagingPlatform.gmail),
      );
      expect(
        MessagingPlatform.fromPackageName('com.Slack'),
        equals(MessagingPlatform.slack),
      );
      expect(
        MessagingPlatform.fromPackageName('com.instagram.android'),
        equals(MessagingPlatform.instagram),
      );
      expect(
        MessagingPlatform.fromPackageName('com.facebook.katana'),
        equals(MessagingPlatform.facebook),
      );
      expect(
        MessagingPlatform.fromPackageName('com.facebook.orca'),
        equals(MessagingPlatform.facebook),
      );
      expect(
        MessagingPlatform.fromPackageName('com.twitter.android'),
        equals(MessagingPlatform.x),
      );
      expect(
        MessagingPlatform.fromPackageName('com.linkedin.android'),
        equals(MessagingPlatform.linkedin),
      );
    });

    test('Fallback a other para paquetes desconocidos', () {
      expect(
        MessagingPlatform.fromPackageName('com.unknown.randomapp'),
        equals(MessagingPlatform.other),
      );
    });
  });

  group('Messaging Center Providers State', () {
    test('Estado inicial de filtros y búsqueda', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(container.read(selectedPlatformFilterProvider), isNull);
      expect(
        container.read(selectedCategoryTabProvider),
        equals(MessagingCategoryFilter.all),
      );
      expect(container.read(messagingSearchQueryProvider), isEmpty);
    });
  });

  group('MessagingDedupMerger (Deduplicación e Integridad Factual)', () {
    test('Filtra paquetes del sistema operativo Android y acepta solo mensajería', () {
      expect(MessagingDedupMerger.isSupportedMessagingApp('android'), isFalse);
      expect(MessagingDedupMerger.isSupportedMessagingApp('com.android.systemui'), isFalse);
      expect(MessagingDedupMerger.isSupportedMessagingApp('com.coloros.phonemanager'), isFalse);
      expect(MessagingDedupMerger.isSupportedMessagingApp('com.google.android.googlequicksearchbox'), isFalse);
      expect(MessagingDedupMerger.isSupportedMessagingApp('com.whatsapp'), isTrue);
      expect(MessagingDedupMerger.isSupportedMessagingApp('com.whatsapp.w4b'), isTrue);
      expect(MessagingDedupMerger.isSupportedMessagingApp('org.telegram.messenger'), isTrue);
    });

    test('Fusiona notificación viva con conversación previa de SQLite sin duplicar', () {
      const existing = ConversationSummaryItem(
        conversationId: 'whatsapp/com.whatsapp/-/Emm',
        displayName: 'Emm',
        packageName: 'com.whatsapp',
        lastMessage: 'Hola, ¿cómo estás?',
        lastAtMs: 1000,
        agentId: ConversationAgentId.personal,
      );

      const incomingLive = ConversationSummaryItem(
        conversationId: 'live:com.whatsapp:Emm',
        displayName: 'Emm',
        packageName: 'com.whatsapp',
        lastMessage: 'Todo bien por acá',
        lastAtMs: 2000,
        hasPendingReply: true,
        notificationKey: 'notif_key_123',
        agentId: ConversationAgentId.personal,
      );

      final merged = MessagingDedupMerger.deduplicateAndSort([existing, incomingLive]);
      expect(merged.length, equals(1));
      expect(merged.first.displayName, equals('Emm'));
      expect(merged.first.lastMessage, equals('Todo bien por acá'));
      expect(merged.first.lastAtMs, equals(2000));
      expect(merged.first.hasPendingReply, isTrue);
      expect(merged.first.notificationKey, equals('notif_key_123'));
    });

    test('No fusiona dos historiales persistidos sólo porque comparten nombre', () {
      const first = ConversationSummaryItem(
        conversationId: 'whatsapp/com.whatsapp/-/person:juan-1',
        displayName: 'Juan',
        packageName: 'com.whatsapp',
        lastMessage: 'Hola',
        lastAtMs: 1000,
        agentId: ConversationAgentId.personal,
      );
      const second = ConversationSummaryItem(
        conversationId: 'whatsapp/com.whatsapp/-/person:juan-2',
        displayName: 'Juan',
        packageName: 'com.whatsapp',
        lastMessage: 'Buenas',
        lastAtMs: 2000,
        agentId: ConversationAgentId.personal,
      );

      expect(
        MessagingDedupMerger.deduplicateAndSort([first, second]),
        hasLength(2),
      );
    });

    test('Deduplica contactos por dígitos de teléfono iguales', () {
      const item1 = ConversationSummaryItem(
        conversationId: '573001234567@s.whatsapp.net',
        displayName: 'Emmanuel Higuita',
        packageName: 'com.whatsapp',
        lastMessage: '573001234567',
        lastAtMs: 1000,
        agentId: ConversationAgentId.personal,
      );

      const item2 = ConversationSummaryItem(
        conversationId: 'whatsapp/com.whatsapp/-/573001234567',
        displayName: 'Emmanuel Higuita',
        packageName: 'com.whatsapp',
        lastMessage: 'Listo amigo',
        lastAtMs: 3000,
        agentId: ConversationAgentId.personal,
      );

      final merged = MessagingDedupMerger.deduplicateAndSort([item1, item2]);
      expect(merged.length, equals(1));
      expect(merged.first.lastMessage, equals('Listo amigo'));
      expect(merged.first.lastAtMs, equals(3000));
    });

    test('Preserva metadatos de grupos de WhatsApp (isGroup, groupTitle, lastSender)', () {
      const groupExisting = ConversationSummaryItem(
        conversationId: '120363024888888888@g.us',
        displayName: 'Equipo de Ventas',
        packageName: 'com.whatsapp',
        lastMessage: 'Carlos: Buenos días equipo',
        lastAtMs: 1500,
        agentId: ConversationAgentId.personal,
        isGroup: true,
        groupTitle: 'Equipo de Ventas',
        lastSender: 'Carlos',
      );

      const groupLive = ConversationSummaryItem(
        conversationId: 'live:com.whatsapp:120363024888888888@g.us',
        displayName: 'Equipo de Ventas',
        packageName: 'com.whatsapp',
        lastMessage: 'Mariana: Revisen el reporte adjunto',
        lastAtMs: 2500,
        hasPendingReply: true,
        agentId: ConversationAgentId.personal,
        isGroup: true,
        groupTitle: 'Equipo de Ventas',
        lastSender: 'Mariana',
      );

      final merged = MessagingDedupMerger.deduplicateAndSort([groupExisting, groupLive]);
      expect(merged.length, equals(1));
      final item = merged.first;
      expect(item.isGroup, isTrue);
      expect(item.groupTitle, equals('Equipo de Ventas'));
      expect(item.lastSender, equals('Mariana'));
      expect(item.lastMessage, equals('Mariana: Revisen el reporte adjunto'));
      expect(item.lastAtMs, equals(2500));
      expect(item.hasPendingReply, isTrue);
    });
  });

  group('MessagingCategoryFilter Groups Tab', () {
    test('Contiene categoría groups y filtra correctamente', () {
      expect(MessagingCategoryFilter.groups.id, equals('groups'));
      expect(MessagingCategoryFilter.groups.label, equals('Grupos'));

      const directChat = ConversationSummaryItem(
        conversationId: '573001234567@s.whatsapp.net',
        displayName: 'Juan Pérez',
        packageName: 'com.whatsapp',
        lastMessage: 'Hola',
        lastAtMs: 1000,
        agentId: ConversationAgentId.personal,
        isGroup: false,
      );

      const groupChat = ConversationSummaryItem(
        conversationId: '120363024888888888@g.us',
        displayName: 'Grupo Familia',
        packageName: 'com.whatsapp',
        lastMessage: 'Mamá: Feliz día',
        lastAtMs: 2000,
        agentId: ConversationAgentId.personal,
        isGroup: true,
      );

      final list = [directChat, groupChat];
      final groupsOnly = list.where((c) => c.isGroup).toList();
      expect(groupsOnly.length, equals(1));
      expect(groupsOnly.first.displayName, equals('Grupo Familia'));
    });
  });

  group('ParsedMediaMessage Multimedia Detection', () {
    test('Detecta enlaces de YouTube y extrae videoId', () {
      final parsed = ParsedMediaMessage.parse('Mira este video https://www.youtube.com/watch?v=dQw4w9WgXcQ');
      expect(parsed.hasMedia, isTrue);
      expect(parsed.youTubeIds, contains('dQw4w9WgXcQ'));
      expect(parsed.videos, contains('https://www.youtube.com/watch?v=dQw4w9WgXcQ'));
    });

    test('Detecta enlaces web generales (http/https)', () {
      final parsed = ParsedMediaMessage.parse('Visita https://flutter.dev para más información');
      expect(parsed.hasMedia, isTrue);
      expect(parsed.links, contains('https://flutter.dev'));
    });

    test('Detecta enlaces cortos de youtu.be', () {
      final parsed = ParsedMediaMessage.parse('https://youtu.be/dQw4w9WgXcQ');
      expect(parsed.hasMedia, isTrue);
      expect(parsed.youTubeIds, contains('dQw4w9WgXcQ'));
    });

    test('Detecta archivos de video directos (.mp4)', () {
      final parsed = ParsedMediaMessage.parse('Descarga el clip en https://ejemplo.com/media/demo.mp4');
      expect(parsed.hasMedia, isTrue);
      expect(parsed.videos, contains('https://ejemplo.com/media/demo.mp4'));
    });

    test('Detecta archivos PDF (.pdf)', () {
      final parsed = ParsedMediaMessage.parse('Aquí está la cotización https://dominio.com/docs/propuesta.pdf');
      expect(parsed.hasMedia, isTrue);
      expect(parsed.pdfs, contains('https://dominio.com/docs/propuesta.pdf'));
    });

    test('Detecta notificaciones de foto y video de WhatsApp', () {
      final photoNotif = ParsedMediaMessage.parse('📷 Foto');
      expect(photoNotif.isPhotoNotification, isTrue);
      expect(photoNotif.hasMedia, isTrue);

      final videoNotif = ParsedMediaMessage.parse('🎥 Video');
      expect(videoNotif.isVideoNotification, isTrue);
      expect(videoNotif.hasMedia, isTrue);
    });

    test('Detecta imágenes con query params y tags explícitos [Imagen: ...]', () {
      final parsedQuery = ParsedMediaMessage.parse('Foto https://images.unsplash.com/photo-sample?auto=format&fit=crop&w=800');
      expect(parsedQuery.hasMedia, isTrue);
      expect(parsedQuery.images.length, equals(1));

      final parsedTag = ParsedMediaMessage.parse('Mira esto\n[Imagen: /data/user/0/dev.nanoai.mobile/cache/img_123.jpg]');
      expect(parsedTag.hasMedia, isTrue);
      expect(parsedTag.images, contains('/data/user/0/dev.nanoai.mobile/cache/img_123.jpg'));
    });

    test('Detecta archivos locales aunque la ruta tenga espacios', () {
      final image = ParsedMediaMessage.parse(
        '/storage/emulated/0/Download/Foto familiar.JPG',
      );
      final video = ParsedMediaMessage.parse(
        '/storage/emulated/0/Download/Video vacaciones.MP4',
      );
      final pdf = ParsedMediaMessage.parse(
        '/storage/emulated/0/Download/Estado de cuenta.PDF',
      );

      expect(image.images, hasLength(1));
      expect(video.videos, hasLength(1));
      expect(pdf.pdfs, hasLength(1));
    });

    test('Ignora puntuación posterior al clasificar enlaces multimedia', () {
      final parsed = ParsedMediaMessage.parse(
        'Abre el informe (https://dominio.com/docs/informe.pdf).',
      );

      expect(parsed.pdfs, ['https://dominio.com/docs/informe.pdf']);
      expect(parsed.links, isEmpty);
    });
  });

  group('LinkMetadataService OpenGraph Parser', () {
    test('Extrae og:title, og:description, og:image y og:site_name', () {
      const mockHtml = '''
        <!DOCTYPE html>
        <html>
        <head>
          <meta property="og:title" content="Flutter - Build apps for any screen" />
          <meta property="og:description" content="Flutter transforms the development process." />
          <meta property="og:image" content="https://storage.googleapis.com/cms-storage-bucket/flutter-logo.png" />
          <meta property="og:site_name" content="Flutter Dev" />
        </head>
        <body></body>
        </html>
      ''';

      final meta = LinkMetadataService.parseHtml('https://flutter.dev', mockHtml);
      expect(meta.title, equals('Flutter - Build apps for any screen'));
      expect(meta.description, equals('Flutter transforms the development process.'));
      expect(meta.imageUrl, equals('https://storage.googleapis.com/cms-storage-bucket/flutter-logo.png'));
      expect(meta.siteName, equals('Flutter Dev'));
      expect(meta.hasContent, isTrue);
    });

    test('Resuelve rutas relativas en og:image y fallback a <title>', () {
      const mockHtml = '''
        <!DOCTYPE html>
        <html>
        <head>
          <title>Mi Sitio Web Oficial</title>
          <meta name="description" content="Descripción básica del sitio" />
          <meta property="og:image" content="/assets/cover.jpg" />
        </head>
        <body></body>
        </html>
      ''';

      final meta = LinkMetadataService.parseHtml('https://ejemplo.com/pagina', mockHtml);
      expect(meta.title, equals('Mi Sitio Web Oficial'));
      expect(meta.description, equals('Descripción básica del sitio'));
      expect(meta.imageUrl, equals('https://ejemplo.com/assets/cover.jpg'));
    });
  });

  group('ConversationHubActionController Ownership Toggle', () {
    test('setOwnership actualiza el ownership store para todas las claves del chat', () async {
      final container = ProviderContainer(
        overrides: [
          liveNotificationsProvider.overrideWith(_MockLiveNotificationsNotifier.new),
        ],
      );
      final ctrl = container.read(conversationHubActionControllerProvider);
      final store = container.read(conversationOwnershipStoreProvider);

      const item = ConversationSummaryItem(
        conversationId: 'whatsapp/+573001234567',
        displayName: 'Juan Perez',
        lastMessage: 'Hola',
        lastAtMs: 1700000000000,
        packageName: 'com.whatsapp',
        agentId: ConversationAgentId.personal,
        hasPendingReply: false,
        isGroup: false,
        conversationAliases: ['+573001234567@s.whatsapp.net'],
      );

      // 1. Pausar (humano toma el control)
      await ctrl.setOwnership(item, ConversationOwner.human);
      final ownershipAfterPause = store.ownershipFor('whatsapp/+573001234567');
      expect(ownershipAfterPause?.owner, equals(ConversationOwner.human));
      expect(ownershipAfterPause?.humanOwns, isTrue);

      final isHumanOwned = ConversationOwnershipPolicy.humanOwns(
        targetContactsMode: 'all',
        ownership: ownershipAfterPause,
      );
      expect(isHumanOwned, isTrue); // Bot pausado

      // 2. Reanudar (devolver a IA / bot)
      await ctrl.setOwnership(item, ConversationOwner.bot);
      final ownershipAfterResume = store.ownershipFor('whatsapp/+573001234567');
      expect(ownershipAfterResume?.owner, equals(ConversationOwner.bot));
      expect(ownershipAfterResume?.humanOwns, isFalse);

      final isBotActive = !ConversationOwnershipPolicy.humanOwns(
        targetContactsMode: 'all',
        ownership: ownershipAfterResume,
      );
      expect(isBotActive, isTrue); // Bot activo
    });
  });

  group('RuleRegistry Multi-Channel Support', () {
    test('Identifica y enruta reglas de WhatsApp, Telegram e Instagram', () {
      expect(
        RuleRegistry.ruleIdForPackage('com.whatsapp'),
        equals(RuleRegistry.universalWhatsAppRuleId),
      );
      expect(
        RuleRegistry.ruleIdForPackage('com.whatsapp.w4b'),
        equals(RuleRegistry.universalWhatsAppBusinessRuleId),
      );
      expect(
        RuleRegistry.ruleIdForPackage('org.telegram.messenger'),
        equals('telegram_universal_conversation'),
      );
      expect(
        RuleRegistry.ruleIdForPackage('org.telegram.plus'),
        equals('telegram_universal_conversation'),
      );
      expect(
        RuleRegistry.ruleIdForPackage('com.instagram.android'),
        equals('instagram_universal_conversation'),
      );
    });
  });

  group('FloatingVideoController State Management', () {
    test('Ciclo de vida de FloatingVideoController (show / hide)', () {
      final controller = FloatingVideoController.instance;
      expect(controller.isPlaying, isFalse);
      expect(controller.currentUrl, isNull);

      controller.hide();
      expect(controller.isPlaying, isFalse);
    });
  });
}

class _MockLiveNotificationsNotifier
    extends AutoDisposeAsyncNotifier<List<ConversationSummaryItem>>
    implements LiveNotificationsNotifier {
  @override
  Future<List<ConversationSummaryItem>> build() async => const [];
}
