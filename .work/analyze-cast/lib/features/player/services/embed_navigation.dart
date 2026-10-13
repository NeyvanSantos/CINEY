import 'embed_document.dart';

/// The top-level page stays in the local iframe host. Provider pages and their
/// media may navigate inside frames, without replacing the whole app view.
bool allowsEmbedNavigation(
  String sourceUrl,
  String url, {
  bool mainFrame = true,
}) {
  final source = Uri.tryParse(sourceUrl);
  final target = Uri.tryParse(url);
  if (source == null ||
      target == null ||
      target.host.isEmpty ||
      !['http', 'https'].contains(target.scheme)) {
    return false;
  }
  if (!mainFrame) return true;
  return target == Uri.parse(embedDocumentBaseUrl);
}
