// ignore_for_file: avoid_web_libraries_in_flutter
import 'dart:typed_data';

import 'package:universal_html/html.dart' as html;

class FileSaver {
  static void saveBytes({required List<int> bytes, required String fileName, required String mimeType}) {
    final blob = html.Blob([Uint8List.fromList(bytes)], mimeType);
    final url = html.Url.createObjectUrlFromBlob(blob);
    final anchor = html.AnchorElement(href: url)
      ..download = fileName
      ..style.display = 'none';
    html.document.body?.children.add(anchor);
    anchor.click();
    anchor.remove();
    html.Url.revokeObjectUrl(url);
  }
}
