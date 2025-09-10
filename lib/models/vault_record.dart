import 'dart:convert';

import 'package:flutter/foundation.dart';

/// ----------------------------
/// DATA MODEL (JSON serializable)
/// ----------------------------

class VaultRecord {
  final String id;
  final String title;
  final int createdAtMs;
  final int updatedAtMs;

  final int unmaskedLength;
  final String maskChar;

  final String kdf;
  final int kdfIterations;
  final String saltB64;
  final String nonceB64;
  final String ciphertextB64;

  VaultRecord({
    required this.id,
    required this.title,
    required this.createdAtMs,
    required this.updatedAtMs,
    required this.unmaskedLength,
    required this.maskChar,
    required this.kdf,
    required this.kdfIterations,
    required this.saltB64,
    required this.nonceB64,
    required this.ciphertextB64,
  });

  Map<String, dynamic> toJson() => {
    "schema": 1,
    "id": id,
    "title": title,
    "createdAtMs": createdAtMs,
    "updatedAtMs": updatedAtMs,
    "unmaskedLength": unmaskedLength,
    "maskChar": maskChar,
    "crypto": {
      "kdf": kdf,
      "kdfIterations": kdfIterations,
      "saltB64": saltB64,
      "nonceB64": nonceB64,
      "ciphertextB64": ciphertextB64,
    }
  };

  static VaultRecord fromJson(Map<String, dynamic> j) {
    final crypto = (j["crypto"] as Map).cast<String, dynamic>();
    return VaultRecord(
      id: j["id"] as String,
      title: j["title"] as String,
      createdAtMs: j["createdAtMs"] as int,
      updatedAtMs: j["updatedAtMs"] as int,
      unmaskedLength: j["unmaskedLength"] as int,
      maskChar: j["maskChar"] as String,
      kdf: crypto["kdf"] as String,
      kdfIterations: crypto["kdfIterations"] as int,
      saltB64: crypto["saltB64"] as String,
      nonceB64: crypto["nonceB64"] as String,
      ciphertextB64: crypto["ciphertextB64"] as String,
    );
  }
}
