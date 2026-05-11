import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:passstore/core/services/vault_crypto.dart';

void main() {
  test('encrypts and decrypts payload with the correct master password', () async {
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
  });

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
}
