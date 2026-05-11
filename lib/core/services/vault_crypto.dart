import 'dart:convert';

import 'package:cryptography/cryptography.dart';

class VaultCrypto {
  VaultCrypto({
    Argon2id? kdf,
    AesGcm? cipher,
  })  : _kdf = kdf ??
            Argon2id(
              parallelism: 2,
              memory: 8192,
              iterations: 3,
              hashLength: 32,
            ),
        _cipher = cipher ?? AesGcm.with256bits();

  static const formatVersion = 1;
  static const algorithmName = 'AES-256-GCM';
  static const kdfName = 'Argon2id';

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
      algorithm: algorithmName,
      kdf: kdfName,
      kdfParams: {
        'parallelism': _kdf.parallelism,
        'memory': _kdf.memory,
        'iterations': _kdf.iterations,
        'hashLength': _kdf.hashLength,
      },
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
      final key = await _deriveKey(
        masterPassword: masterPassword,
        salt: salt,
        params: payload.kdfParams,
      );
      final box = SecretBox(
        base64Decode(payload.ciphertext),
        nonce: base64Decode(payload.nonce),
        mac: Mac(base64Decode(payload.mac)),
      );
      return await _cipher.decryptString(box, secretKey: key);
    } on SecretBoxAuthenticationError catch (_) {
      throw const VaultCryptoException('主密码不正确或密码库已损坏');
    } on FormatException catch (_) {
      throw const VaultCryptoException('密码库格式无效');
    }
  }

  Future<SecretKey> _deriveKey({
    required String masterPassword,
    required List<int> salt,
    Map<String, Object?>? params,
  }) {
    final effectiveKdf = params == null
        ? _kdf
        : Argon2id(
            parallelism: params['parallelism']! as int,
            memory: params['memory']! as int,
            iterations: params['iterations']! as int,
            hashLength: params['hashLength']! as int,
          );
    return effectiveKdf.deriveKey(
      secretKey: SecretKey(utf8.encode(masterPassword)),
      nonce: salt,
    );
  }
}

class EncryptedVaultPayload {
  const EncryptedVaultPayload({
    required this.version,
    required this.algorithm,
    required this.kdf,
    required this.kdfParams,
    required this.salt,
    required this.nonce,
    required this.mac,
    required this.ciphertext,
  });

  final int version;
  final String algorithm;
  final String kdf;
  final Map<String, Object?> kdfParams;
  final String salt;
  final String nonce;
  final String mac;
  final String ciphertext;

  Map<String, Object?> toJson() => {
        'version': version,
        'algorithm': algorithm,
        'kdf': kdf,
        'kdfParams': kdfParams,
        'salt': salt,
        'nonce': nonce,
        'mac': mac,
        'ciphertext': ciphertext,
      };

  factory EncryptedVaultPayload.fromJson(Map<String, Object?> json) {
    return EncryptedVaultPayload(
      version: json['version']! as int,
      algorithm: json['algorithm']! as String,
      kdf: json['kdf']! as String,
      kdfParams: (json['kdfParams']! as Map<String, Object?>),
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
