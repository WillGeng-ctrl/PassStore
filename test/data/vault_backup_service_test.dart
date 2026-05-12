import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:passstore/core/services/vault_crypto.dart';
import 'package:passstore/data/vault_backup_service.dart';
import 'package:path/path.dart' as p;

void main() {
  test('exports and imports an encrypted vault payload file', () async {
    final tempDir = await Directory.systemTemp.createTemp('passstore-backup-');
    addTearDown(() => tempDir.delete(recursive: true));

    final payload = await VaultCrypto().encryptString(
      plaintext: '{"ok":true}',
      masterPassword: 'master-password',
    );
    final backupPath = p.join(tempDir.path, 'backup.vault');
    final service = const VaultBackupService();

    await service.exportEncryptedPayload(payload, backupPath);
    final restored = await service.importEncryptedPayload(backupPath);

    expect(restored.version, payload.version);
    expect(restored.ciphertext, payload.ciphertext);
    expect(restored.toJson(), isNot(contains('algorithm')));
    expect(restored.toJson(), isNot(contains('kdf')));
    expect(restored.toJson(), isNot(contains('kdfParams')));
  });
}
