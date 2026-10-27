/// Fragmento original observado, antes de juntar una ráfaga o leer sus archivos.
/// Fecha y autor exactos evitan borrar otro mensaje igual de otra persona.
final class NotificationSourceFragment {
  const NotificationSourceFragment({
    required this.text,
    required this.atMs,
    required this.sender,
  });
  final String text, sender;
  final int atMs;
  bool matches(String body, int stamp, String author, {required bool group}) =>
      atMs > 0 &&
      atMs == stamp &&
      text.trim() == body.trim() &&
      (!group || sender == author);
}
