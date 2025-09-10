/// Platform abstraction for saving bytes as a file.
///
/// * Web: triggers a browser download.
/// * Other platforms: throws [UnsupportedError] (callers should fall back to Share or a file path).
class FileSaver {
  static void saveBytes({required List<int> bytes, required String fileName, required String mimeType}) {
    throw UnsupportedError('File saving via browser download is only available on Web.');
  }
}
