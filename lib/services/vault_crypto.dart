import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:uuid/uuid.dart';

import '../models/vault_record.dart';

/// ----------------------------
/// CRYPTO (PBKDF2 + AES-GCM)
/// ----------------------------

class VaultCrypto {
  static const int saltLen = 16;
  static const int nonceLen = 12;
  static const int kdfIterations = 150000;
  static const String kdfName = "PBKDF2-HMAC-SHA256";

  final _rng = Random.secure();
  // Random.secure() is backed by the OS CSPRNG.
  final _pbkdf2 = Pbkdf2(
    macAlgorithm: Hmac.sha256(),
    iterations: kdfIterations,
    bits: 256,
  );
  final _cipher = AesGcm.with256bits();

  Uint8List _randomBytes(int n) {
    final b = Uint8List(n);
    for (int i = 0; i < n; i++) {
      b[i] = _rng.nextInt(256);
    }
    return b;
  }

  Future<SecretKey> _deriveKey({required String pin, required Uint8List salt}) async {
    final pinBytes = utf8.encode(pin);
    return _pbkdf2.deriveKey(
      secretKey: SecretKey(pinBytes),
      nonce: salt,
    );
  }

  Future<VaultRecord> encryptToRecord({
    required String title,
    required String plaintext,
    required String pin,
    required int unmaskedLength,
    required String maskChar,
    String? id,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final recordId = id ?? Uuid().v4();

    final salt = _randomBytes(saltLen);
    final nonce = _randomBytes(nonceLen);
    final key = await _deriveKey(pin: pin, salt: salt);

    final aad = utf8.encode("title=$title;unmasked=$unmaskedLength;mask=$maskChar;id=$recordId");

    final secretBox = await _cipher.encrypt(
      utf8.encode(plaintext),
      secretKey: key,
      nonce: nonce,
      aad: aad,
    );

    final ciphertext = Uint8List.fromList([...secretBox.cipherText, ...secretBox.mac.bytes]);

    return VaultRecord(
      id: recordId,
      title: title,
      createdAtMs: now,
      updatedAtMs: now,
      unmaskedLength: unmaskedLength,
      maskChar: maskChar,
      kdf: kdfName,
      kdfIterations: kdfIterations,
      saltB64: base64Encode(salt),
      nonceB64: base64Encode(nonce),
      ciphertextB64: base64Encode(ciphertext),
    );
  }

  Future<String> decryptRecord({required VaultRecord record, required String pin}) async {
    final salt = base64Decode(record.saltB64);
    final nonce = base64Decode(record.nonceB64);
    final combined = base64Decode(record.ciphertextB64);

    if (combined.length < 16) throw const FormatException("Ciphertext too short.");

    final macBytes = combined.sublist(combined.length - 16);
    final cipherText = combined.sublist(0, combined.length - 16);

    final key = await _deriveKey(pin: pin, salt: Uint8List.fromList(salt));
    final aad = utf8.encode("title=${record.title};unmasked=${record.unmaskedLength};mask=${record.maskChar};id=${record.id}");

    final secretBox = SecretBox(
      cipherText,
      nonce: nonce,
      mac: Mac(macBytes),
    );

    final clear = await _cipher.decrypt(secretBox, secretKey: key, aad: aad);
    return utf8.decode(clear);
  }
}
