/// Mapea paquetes Android a canales lógicos de mensajería.
///
/// Centralizar esta tabla impide fusionar WhatsApp personal y Business.
library;

import 'messaging_package.dart';

String channelForPackage(String packageName) => switch (packageName) {
  MessagingPackage.whatsapp => 'whatsapp',
  MessagingPackage.whatsappBusiness => 'whatsapp.business',
  MessagingPackage.telegram => 'telegram',
  MessagingPackage.telegramOrg => 'telegram',
  MessagingPackage.signal => 'signal',
  MessagingPackage.instagram => 'instagram',
  MessagingPackage.messenger => 'messenger',
  MessagingPackage.messengerLite => 'messenger',
  MessagingPackage.googleMessages => 'sms',
  MessagingPackage.androidMms => 'sms',
  MessagingPackage.samsungMessages => 'sms',
  MessagingPackage.discord => 'discord',
  MessagingPackage.slack => 'slack',
  MessagingPackage.gmail => 'email',
  MessagingPackage.outlook => 'email',
  MessagingPackage.twitter => 'twitter',
  _ => packageName,
};
