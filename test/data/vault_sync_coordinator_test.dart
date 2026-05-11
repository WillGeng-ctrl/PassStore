import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:passstore/core/models/category.dart';
import 'package:passstore/core/models/vault.dart';
import 'package:passstore/core/models/vault_entry.dart';
import 'package:passstore/core/services/vault_crypto.dart';
import 'package:passstore/core/services/vault_service.dart';
import 'package:passstore/data/sync_metadata_store.dart';
import 'package:passstore/data/vault_sync_coordinator.dart';
import 'package:passstore/data/webdav_sync_service.dart';

void main() {
  final crypto = VaultCrypto();

  test('uploads local vault when remote vault is missing', () async {
    final remote = FakeRemoteStore();
    final coordinator = VaultSyncCoordinator(crypto: crypto, remote: remote);
    final localVault = _vaultWithEntry('local-only');

    final result = await coordinator.sync(
      localVault: localVault,
      masterPassword: 'password',
      credentials: _credentials,
      metadata: SyncMetadata.empty,
    );

    expect(result.status, VaultSyncStatus.synced);
    expect(remote.uploads, hasLength(1));
    final uploaded = await _decodeVault(
      crypto,
      remote.uploads.single,
      'password',
    );
    expect(uploaded.entries.single.title, 'local-only');
    expect(result.metadata?.hasUnsyncedChanges, isFalse);
    expect(result.metadata?.basePayload, isNotNull);
  });

  test('merges remote and local changes before uploading', () async {
    final base = VaultService.createEmptyVault(now: DateTime.utc(2026, 5, 12));
    final local = _upsert(base, 'local-only', DateTime.utc(2026, 5, 12, 1));
    final remoteVault = _upsert(
      base,
      'remote-only',
      DateTime.utc(2026, 5, 12, 2),
    );
    final basePayload = await _encodeVault(crypto, base, 'password');
    final remotePayload = await _encodeVault(crypto, remoteVault, 'password');
    final remote = FakeRemoteStore(
      nextDownload: RemoteVaultFile(
        body: jsonEncode(remotePayload.toJson()),
        etag: 'etag-remote',
      ),
    );
    final coordinator = VaultSyncCoordinator(crypto: crypto, remote: remote);

    final result = await coordinator.sync(
      localVault: local,
      masterPassword: 'password',
      credentials: _credentials,
      metadata: SyncMetadata(basePayload: basePayload),
    );

    expect(result.status, VaultSyncStatus.synced);
    final uploaded = await _decodeVault(
      crypto,
      remote.uploads.single,
      'password',
    );
    expect(
      uploaded.entries.map((entry) => entry.title),
      containsAll(['local-only', 'remote-only']),
    );
    expect(result.metadata?.remoteEtag, 'etag-remote');
  });

  test(
    'does not upload when remote vault needs a different master password',
    () async {
      final remoteVault = _vaultWithEntry('remote');
      final remotePayload = await _encodeVault(crypto, remoteVault, 'new');
      final remote = FakeRemoteStore(
        nextDownload: RemoteVaultFile(body: jsonEncode(remotePayload.toJson())),
      );
      final coordinator = VaultSyncCoordinator(crypto: crypto, remote: remote);

      final result = await coordinator.sync(
        localVault: _vaultWithEntry('local'),
        masterPassword: 'old',
        credentials: _credentials,
        metadata: SyncMetadata.empty,
      );

      expect(result.status, VaultSyncStatus.needsNewMasterPassword);
      expect(remote.uploads, isEmpty);
    },
  );

  test(
    'accepts the new remote master password and uploads merged vault with it',
    () async {
      final localVault = _vaultWithEntry('local');
      final remoteVault = _vaultWithEntry('remote');
      final remotePayload = await _encodeVault(crypto, remoteVault, 'new');
      final remote = FakeRemoteStore(
        nextDownload: RemoteVaultFile(body: jsonEncode(remotePayload.toJson())),
      );
      final coordinator = VaultSyncCoordinator(crypto: crypto, remote: remote);

      final result = await coordinator.sync(
        localVault: localVault,
        masterPassword: 'old',
        remoteMasterPassword: 'new',
        credentials: _credentials,
        metadata: SyncMetadata.empty,
      );

      expect(result.status, VaultSyncStatus.synced);
      expect(result.masterPassword, 'new');
      final uploaded = await _decodeVault(crypto, remote.uploads.single, 'new');
      expect(
        uploaded.entries.map((entry) => entry.title),
        containsAll(['local', 'remote']),
      );
      await expectLater(
        crypto.decryptString(
          EncryptedVaultPayload.fromJson(
            (jsonDecode(remote.uploads.single) as Map<String, Object?>),
          ),
          masterPassword: 'old',
        ),
        throwsA(isA<VaultCryptoException>()),
      );
    },
  );

  test(
    'uploads changed local master password after reading remote with old password',
    () async {
      final localVault = _vaultWithEntry('local-new-password');
      final remoteVault = _vaultWithEntry('remote-old-password');
      final remotePayload = await _encodeVault(crypto, remoteVault, 'old');
      final remote = FakeRemoteStore(
        nextDownload: RemoteVaultFile(body: jsonEncode(remotePayload.toJson())),
      );
      final coordinator = VaultSyncCoordinator(crypto: crypto, remote: remote);

      final result = await coordinator.sync(
        localVault: localVault,
        masterPassword: 'new',
        remoteMasterPassword: 'old',
        uploadMasterPassword: 'new',
        credentials: _credentials,
        metadata: SyncMetadata.empty,
      );

      expect(result.status, VaultSyncStatus.synced);
      expect(result.masterPassword, 'new');
      final uploaded = await _decodeVault(crypto, remote.uploads.single, 'new');
      expect(
        uploaded.entries.map((entry) => entry.title),
        containsAll(['local-new-password', 'remote-old-password']),
      );
      await expectLater(
        crypto.decryptString(
          EncryptedVaultPayload.fromJson(
            (jsonDecode(remote.uploads.single) as Map<String, Object?>),
          ),
          masterPassword: 'old',
        ),
        throwsA(isA<VaultCryptoException>()),
      );
    },
  );
}

const _credentials = SyncCredentials(
  url: 'https://dav.jianguoyun.com/dav/',
  account: 'user@example.com',
  appPassword: 'app-password',
);

class FakeRemoteStore implements VaultRemoteStore {
  FakeRemoteStore({this.nextDownload});

  RemoteVaultFile? nextDownload;
  final uploads = <String>[];

  @override
  Future<RemoteVaultFile?> downloadVaultFile({
    required String url,
    required String account,
    required String appPassword,
  }) async {
    return nextDownload;
  }

  @override
  Future<void> uploadVault({
    required String url,
    required String account,
    required String appPassword,
    required String body,
  }) async {
    uploads.add(body);
  }
}

Vault _vaultWithEntry(String title) {
  final base = VaultService.createEmptyVault(now: DateTime.utc(2026, 5, 12));
  return _upsert(base, title, DateTime.utc(2026, 5, 12, title.length));
}

Vault _upsert(Vault vault, String title, DateTime now) {
  return VaultService.upsertEntry(
    vault,
    VaultEntry.create(
      title: title,
      account: '$title@example.com',
      password: 'secret',
      url: 'https://example.com/$title',
      notes: '',
      categoryId: Category.websiteId,
      now: now,
    ),
    now: now,
  );
}

Future<EncryptedVaultPayload> _encodeVault(
  VaultCrypto crypto,
  Vault vault,
  String masterPassword,
) {
  return crypto.encryptString(
    plaintext: jsonEncode(vault.toJson()),
    masterPassword: masterPassword,
  );
}

Future<Vault> _decodeVault(
  VaultCrypto crypto,
  String payloadJson,
  String masterPassword,
) async {
  final payload = EncryptedVaultPayload.fromJson(
    (jsonDecode(payloadJson) as Map<String, Object?>),
  );
  final plaintext = await crypto.decryptString(
    payload,
    masterPassword: masterPassword,
  );
  return Vault.fromJson(
    (jsonDecode(plaintext) as Map<String, Object?>).cast<String, Object?>(),
  );
}
