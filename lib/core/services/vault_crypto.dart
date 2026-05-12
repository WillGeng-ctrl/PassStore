import 'dart:convert';

import 'package:cryptography/cryptography.dart';

class VaultCrypto {
  VaultCrypto({Argon2id? kdf, AesGcm? cipher})
    : _kdf =
          kdf ??
          Argon2id(
            parallelism: defaultKdfParams['parallelism']!,
            memory: defaultKdfParams['memory']!,
            iterations: defaultKdfParams['iterations']!,
            hashLength: defaultKdfParams['hashLength']!,
          ),
      _cipher = cipher ?? AesGcm.with256bits();

  static const formatVersion = 1;
  static const defaultKdfParams = {
    'parallelism': 1,
    'memory': 19456,
    'iterations': 2,
    'hashLength': 32,
  };

  final Argon2id _kdf;
  final AesGcm _cipher;

  Future<EncryptedVaultPayload> encryptString({
    required String plaintext,
    required String masterPassword,
  }) async {
    final salt = SecretKeyData.random(length: 16).bytes;
    final key = await _deriveKey(masterPassword: masterPassword, salt: salt);
    final box = await _cipher.encryptString(plaintext, secretKey: key);
    return EncryptedVaultPayload(
      version: formatVersion,
      salt: base64Encode(salt),
      nonce: base64Encode(box.nonce),
      mac: base64Encode(box.mac.bytes),
      ciphertext: base64Encode(box.cipherText),
    );
  }

  Future<String> decryptString(
    EncryptedVaultPayload payload, {
    required String masterPassword,
  }) async {
    try {
      final salt = base64Decode(payload.salt);
      final key = await _deriveKey(masterPassword: masterPassword, salt: salt);
      final box = SecretBox(
        base64Decode(payload.ciphertext),
        nonce: base64Decode(payload.nonce),
        mac: Mac(base64Decode(payload.mac)),
      );
      return await _cipher.decryptString(box, secretKey: key);
    } on SecretBoxAuthenticationError catch (_) {
      throw const VaultCryptoException("涓诲瘑鐮佷笉姝ｇ‘鎴栧瘑鐮佸簱宸叉崯鍧?");
    } on FormatException catch (_) {
      throw const VaultCryptoException("瀵嗙爜搴撴牸寮忔棤鏁?");
    } on TypeError catch (_) {
      throw const VaultCryptoException("瀵嗙爜搴撴牸寮忔棤鏁?");
    }
  }

  Future<SecretKey> _deriveKey({
    required String masterPassword,
    required List<int> salt,
  }) {
    return _kdf.deriveKey(
      secretKey: SecretKey(utf8.encode(masterPassword)),
      nonce: salt,
    );
  }
}

class EncryptedVaultPayload {
  const EncryptedVaultPayload({
    required this.version,
    required this.salt,
    required this.nonce,
    required this.mac,
    required this.ciphertext,
  });

  final int version;
  final String salt;
  final String nonce;
  final String mac;
  final String ciphertext;

  Map<String, Object?> toJson() => {
    'version': version,
    'salt': salt,
    'nonce': nonce,
    'mac': mac,
    'ciphertext': ciphertext,
  };

  factory EncryptedVaultPayload.fromJson(Map<String, Object?> json) {
    return EncryptedVaultPayload(
      version: json['version']! as int,
      salt: json['salt']! as String,
      nonce: json['nonce']! as String,
      mac: json['mac']! as String,
      ciphertext: json['ciphertext']! as String,
    );
  }
}

class VaultCryptoException implements Exception {
  const VaultCryptoException(this.message);

  final String message;

  @override
  String toString() => message;
}
