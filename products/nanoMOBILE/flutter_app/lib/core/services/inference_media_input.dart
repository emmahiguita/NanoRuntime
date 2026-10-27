/// A real local media file sent to a runtime that declares support for it.
class InferenceMediaInput {
  final String type;
  final String path;

  const InferenceMediaInput({required this.type, required this.path});
}
