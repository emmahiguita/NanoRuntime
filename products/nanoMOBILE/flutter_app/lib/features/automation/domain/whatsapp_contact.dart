/// Entidad de contacto de WhatsApp obtenida de la agenda de Android vía ContactsContract.
library;

final class WhatsAppContact {
  final String id;
  final String name;
  final String number;
  final String jid;
  final bool isBusiness;
  final bool isGroup;
  final String packageName;
  final String accountType;
  final String verificationSource;
  // Distingue una cuenta enlazada a WhatsApp de un teléfono común de la agenda.
  final bool isWhatsAppVerified;

  const WhatsAppContact({
    required this.id,
    required this.name,
    required this.number,
    required this.jid,
    this.isBusiness = false,
    this.isGroup = false,
    this.packageName = '',
    this.accountType = '',
    this.verificationSource = 'unknown',
    this.isWhatsAppVerified = false,
  });

  factory WhatsAppContact.fromMap(Map<dynamic, dynamic> map) {
    return WhatsAppContact(
      id: map['id']?.toString() ?? '',
      name: map['name']?.toString() ?? 'Sin nombre',
      number: map['number']?.toString() ?? '',
      jid: map['jid']?.toString() ?? '',
      isBusiness: map['isBusiness'] == true,
      isGroup: map['isGroup'] == true,
      packageName: map['packageName']?.toString() ?? '',
      accountType: map['accountType']?.toString() ?? '',
      verificationSource: map['verificationSource']?.toString() ?? 'unknown',
      isWhatsAppVerified: map['isWhatsAppVerified'] == true,
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'number': number,
    'jid': jid,
    'isBusiness': isBusiness,
    'isGroup': isGroup,
    'packageName': packageName,
    'accountType': accountType,
    'verificationSource': verificationSource,
    'isWhatsAppVerified': isWhatsAppVerified,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WhatsAppContact &&
          runtimeType == other.runtimeType &&
          _identityKey == other._identityKey;

  @override
  int get hashCode => _identityKey.hashCode;

  // Los números de agenda no tienen JID verificado; el teléfono mantiene su identidad estable.
  String get _identityKey => jid.isNotEmpty ? jid : number;

  @override
  String toString() =>
      'WhatsAppContact(name: $name, jid: $jid, isBusiness: $isBusiness, '
      'isGroup: $isGroup, verified: $isWhatsAppVerified, source: $verificationSource)';
}
