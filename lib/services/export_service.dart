import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:share_plus/share_plus.dart';

import '../models/vault_record.dart';
import '../platform/file_saver.dart';

class ExportService {
  static const _mimeJson = 'application/json';

  static ({String fileName, Uint8List bytes}) buildRecordExport(VaultRecord record) {
    final exportObj = {
      'exportType': 'data_masking_vault_record',
      'exportedAtMs': DateTime.now().millisecondsSinceEpoch,
      'record': record.toJson(),
    };

    final jsonStr = jsonEncode(exportObj);
    final bytes = Uint8List.fromList(utf8.encode(jsonStr));

    final filenameSafe = record.title
        .replaceAll(RegExp(r'[^\w\s-]'), '')
        .trim()
        .replaceAll(RegExp(r'\s+'), '_');
    final fileName = 'vault_${filenameSafe.isEmpty ? record.id : filenameSafe}.json';

    return (fileName: fileName, bytes: bytes);
  }

  /// Best-effort export:
  /// - On mobile/desktop: share a JSON file using the platform share sheet.
  /// - On web: use the Web Share API if available; otherwise trigger a download.
  static Future<void> shareOrDownloadJson({required String fileName, required Uint8List bytes}) async {
    Object? lastError;
    StackTrace? lastStack;

    // Share first (works on most non-web platforms; on web may throw).
    try {
      final xfile = XFile.fromData(bytes, mimeType: _mimeJson, name: fileName);
      await Share.shareXFiles([xfile], subject: fileName);
      return;
    } catch (e, st) {
      lastError = e;
      lastStack = st;
      // fall through to download
    }

    // Web download fallback (throws UnsupportedError on non-web).
    if (kIsWeb) {
      FileSaver.saveBytes(bytes: bytes, fileName: fileName, mimeType: _mimeJson);
      return;
    }

    // Non-web and share failed: surface the original error.
    Error.throwWithStackTrace(
      lastError ?? Exception('Share failed.'),
      lastStack ?? StackTrace.current,
    );
  }
}
