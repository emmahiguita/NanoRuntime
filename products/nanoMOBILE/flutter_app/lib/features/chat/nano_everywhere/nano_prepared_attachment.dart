/// Referencia a un archivo elegido y copiado al catálogo privado existente.
/// No representa un permiso de envío ni acredita comprensión de su contenido.
class NanoPreparedAttachment {
  const NanoPreparedAttachment({required this.name, required this.path});
  final String name, path;
}
