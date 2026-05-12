import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:passstore/core/services/vault_crypto.dart';

void main() {
  test(
    'encrypts and decrypts payload with the correct master password',
    () async {
      final crypto = VaultCrypto();
      final encrypted = await crypto.encryptString(
        plaintext: jsonEncode({'title': 'GitHub', 'password': 'secret'}),
        masterPassword: 'correct horse battery staple',
      );

      final decrypted = await crypto.decryptString(
        encrypted,
        masterPassword: 'correct horse battery staple',
      );

      expect(jsonDecode(decrypted), {'title': 'GitHub', 'password': 'secret'});
      expect(encrypted.ciphertext, isNot(contains('secret')));
    },
  );

  test('wrong master password fails to decrypt', () async {
    final crypto = VaultCrypto();
    final encrypted = await crypto.encryptString(
      plaintext: 'private',
      masterPassword: 'right-password',
    );

    expect(
      () => crypto.decryptString(encrypted, masterPassword: 'wrong-password'),
      throwsA(isA<VaultCryptoException>()),
    );
  });

  test('new vault payloads keep crypto settings out of the file', () async {
    final crypto = VaultCrypto();
    final encrypted = await crypto.encryptString(
      plaintext: 'private',
      masterPassword: 'strong-password',
    );
    final json = encrypted.toJson();

    expect(json, isNot(contains('algorithm')));
    expect(json, isNot(contains('kdf')));
    expect(json, isNot(contains('kdfParams')));
  });

  test(
    'new vault payloads use stronger Argon2id parameters internally',
    () async {
      final crypto = VaultCrypto();
      final encrypted = await crypto.encryptString(
        plaintext: 'private',
        masterPassword: 'strong-password',
      );

      expect(encrypted.toJson(), {
        'version': 1,
        'salt': encrypted.salt,
        'nonce': encrypted.nonce,
        'mac': encrypted.mac,
        'ciphertext': encrypted.ciphertext,
      });
      expect(VaultCrypto.defaultKdfParams, {
        'parallelism': 1,
        'memory': 19456,
        'iterations': 2,
        'hashLength': 32,
      });
    },
  );
}
