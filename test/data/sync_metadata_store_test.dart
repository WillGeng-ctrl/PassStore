import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:passstore/core/services/vault_crypto.dart';
import 'package:passstore/data/sync_metadata_store.dart';

void main() {
  test('saves and loads encrypted sync baseline metadata', () async {
    final tempDir = await Directory.systemTemp.createTemp(
      'passstore-sync-meta-',
    );
    addTearDown(() => tempDir.delete(recursive: true));
    final store = SyncMetadataStore(directory: tempDir);
    const payload = EncryptedVaultPayload(
      version: 1,
      salt: 'salt',
      nonce: 'nonce',
      mac: 'mac',
      ciphertext: 'ciphertext',
    );
    final metadata = SyncMetadata(
      basePayload: payload,
      remoteEtag: 'etag-1',
      remoteLastModified: 'Tue, 12 May 2026 10:00:00 GMT',
      lastSyncedAt: DateTime.utc(2026, 5, 12, 10),
      hasUnsyncedChanges: true,
      lastError: 'network',
    );

    await store.save(metadata);
    final loaded = await store.load();

    expect(loaded.basePayload?.ciphertext, 'ciphertext');
    expect(loaded.remoteEtag, 'etag-1');
    expect(loaded.remoteLastModified, 'Tue, 12 May 2026 10:00:00 GMT');
    expect(loaded.hasUnsyncedChanges, isTrue);
    expect(loaded.lastError, 'network');
  });

  test('loads empty metadata when no metadata file exists', () async {
    final tempDir = await Directory.systemTemp.createTemp(
      'passstore-sync-meta-',
    );
    addTearDown(() => tempDir.delete(recursive: true));
    final store = SyncMetadataStore(directory: tempDir);

    final metadata = await store.load();

    expect(metadata.basePayload, isNull);
    expect(metadata.hasUnsyncedChanges, isFalse);
  });
}
