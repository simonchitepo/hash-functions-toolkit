import 'dart:convert';

import 'package:hive/hive.dart';

import '../models/vault_record.dart';

/// ----------------------------
/// STORAGE
/// ----------------------------

class VaultStore {
  static const boxName = "vault_records_v1";
  static const prefsBoxName = "app_prefs";
  final Box<String> _box = Hive.box<String>(boxName);

  List<VaultRecord> getAll() {
    final out = <VaultRecord>[];
    for (final key in _box.keys) {
      final raw = _box.get(key);
      if (raw == null) continue;
      try {
        out.add(VaultRecord.fromJson(jsonDecode(raw)));
      } catch (_) {}
    }
    out.sort((a, b) => b.updatedAtMs.compareTo(a.updatedAtMs));
    return out;
  }

  Future<void> put(VaultRecord record) async {
    await _box.put(record.id, jsonEncode(record.toJson()));
  }

  Future<void> delete(String id) async {
    await _box.delete(id);
  }

  Future<int> importMany(List<VaultRecord> records) async {
    int count = 0;
    for (final r in records) {
      await put(r);
      count++;
    }
    return count;
  }
}
