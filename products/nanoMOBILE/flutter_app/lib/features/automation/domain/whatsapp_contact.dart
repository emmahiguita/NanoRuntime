/// Entidad de contacto de WhatsApp obtenida de la agenda de Android vía ContactsContract.
library;

final class WhatsAppContact {
  final String id;
  final String name;
  final String number;
  final String jid;
  final bool isBusiness;

  const WhatsAppContact({
    required this.id,
    required this.name,
    required this.number,
    required this.jid,
    this.isBusiness = false,
  });

  factory WhatsAppContact.fromMap(Map<dynamic, dynamic> map) {
    return WhatsAppContact(
      id: map['id']?.toString() ?? '',
      name: map['name']?.toString() ?? 'Sin nombre',
      number: map['number']?.toString() ?? '',
      jid: map['jid']?.toString() ?? '',
      isBusiness: map['isBusiness'] == true,
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'number': number,
    'jid': jid,
    'isBusiness': isBusiness,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WhatsAppContact &&
          runtimeType == other.runtimeType &&
          jid == other.jid;

  @override
  int get hashCode => jid.hashCode;

  @override
  String toString() => 'WhatsAppContact(name: $name, jid: $jid, isBusiness: $isBusiness)';
}
