import 'dart:convert';

import '../core/models/vault.dart';
import '../core/services/vault_crypto.dart';
import '../core/services/vault_merge.dart';
import 'sync_metadata_store.dart';
import 'webdav_sync_service.dart';

enum VaultSyncStatus {
  unconfigured('未配置同步'),
  notSynced('未同步'),
  syncing('同步中'),
  synced('已同步'),
  failed('同步失败'),
  needsNewMasterPassword('需要新主密码'),
  conflict('有冲突');

  const VaultSyncStatus(this.label);

  final String label;
}

class SyncCredentials {
  const SyncCredentials({
    required this.url,
    required this.account,
    required this.appPassword,
  });

  final String url;
  final String account;
  final String appPassword;

  bool get isConfigured =>
      url.trim().isNotEmpty &&
      account.trim().isNotEmpty &&
      appPassword.trim().isNotEmpty;
}

class VaultSyncResult {
  const VaultSyncResult({
    required this.status,
    this.vault,
    this.payload,
    this.metadata,
    this.masterPassword,
    this.conflicts = const [],
    this.message,
  });

  final VaultSyncStatus status;
  final Vault? vault;
  final EncryptedVaultPayload? payload;
  final SyncMetadata? metadata;
  final String? masterPassword;
  final List<FieldConflict> conflicts;
  final String? message;
}

class VaultSyncCoordinator {
  const VaultSyncCoordinator({
    required VaultCrypto crypto,
    required VaultRemoteStore remote,
  }) : _crypto = crypto,
       _remote = remote;

  final VaultCrypto _crypto;
  final VaultRemoteStore _remote;

  Future<VaultSyncResult> sync({
    required Vault localVault,
    required String masterPassword,
    required SyncCredentials credentials,
    required SyncMetadata metadata,
    String? remoteMasterPassword,
    String? uploadMasterPassword,
  }) async {
    if (!credentials.isConfigured) {
      return const VaultSyncResult(status: VaultSyncStatus.unconfigured);
    }

    try {
      final remoteFile = await _remote.downloadVaultFile(
        url: credentials.url,
        account: credentials.account,
        appPassword: credentials.appPassword,
      );

      if (remoteFile == null) {
        return await _uploadSyncedVault(
          vault: localVault,
          masterPassword: masterPassword,
          credentials: credentials,
          remoteEtag: null,
          remoteLastModified: null,
          onlyIfMissing: true,
        );
      }

      final effectiveRemotePassword = remoteMasterPassword ?? masterPassword;
      final effectiveUploadPassword =
          uploadMasterPassword ?? remoteMasterPassword ?? masterPassword;
      final remoteVault = await _decodeRemoteVault(
        remoteFile.body,
        effectiveRemotePassword,
        remoteMasterPasswordProvided: remoteMasterPassword != null,
      );
      if (remoteVault == null) {
        return const VaultSyncResult(
          status: VaultSyncStatus.needsNewMasterPassword,
          message: '云端密码库需要新的主密码',
        );
      }

      final baseVault = await _decodeBaseVault(
        metadata.basePayload,
        masterPasswords: [effectiveRemotePassword, masterPassword],
      );
      final merge = VaultMerge.merge(
        base: baseVault ?? localVault,
        local: localVault,
        remote: remoteVault,
        hasBase: baseVault != null,
      );

      if (merge.conflicts.isNotEmpty) {
        return VaultSyncResult(
          status: VaultSyncStatus.conflict,
          vault: merge.vault,
          conflicts: merge.conflicts,
          message: '存在需要处理的同步冲突',
        );
      }

      return await _uploadSyncedVault(
        vault: merge.vault,
        masterPassword: effectiveUploadPassword,
        credentials: credentials,
        remoteEtag: remoteFile.etag,
        remoteLastModified: remoteFile.lastModified,
      );
    } catch (error) {
      return VaultSyncResult(
        status: VaultSyncStatus.failed,
        metadata: metadata.copyWith(
          hasUnsyncedChanges: true,
          lastError: error.toString(),
        ),
        message: error.toString(),
      );
    }
  }

  Future<Vault?> _decodeRemoteVault(
    String payloadJson,
    String masterPassword, {
    required bool remoteMasterPasswordProvided,
  }) async {
    try {
      return await _decodeVaultPayloadJson(payloadJson, masterPassword);
    } on VaultCryptoException {
      if (remoteMasterPasswordProvided) rethrow;
      return null;
    }
  }

  Future<Vault?> _decodeBaseVault(
    EncryptedVaultPayload? payload, {
    required Iterable<String> masterPasswords,
  }) async {
    if (payload == null) return null;
    final triedPasswords = <String>{};
    for (final masterPassword in masterPasswords) {
      if (!triedPasswords.add(masterPassword)) continue;
      try {
        final plaintext = await _crypto.decryptString(
          payload,
          masterPassword: masterPassword,
        );
        return Vault.fromJson(
          (jsonDecode(plaintext) as Map<String, Object?>)
              .cast<String, Object?>(),
        );
      } on VaultCryptoException {
        continue;
      }
    }
    return null;
  }

  Future<Vault> _decodeVaultPayloadJson(
    String payloadJson,
    String masterPassword,
  ) async {
    final payload = EncryptedVaultPayload.fromJson(
      (jsonDecode(payloadJson) as Map<String, Object?>).cast<String, Object?>(),
    );
    final plaintext = await _crypto.decryptString(
      payload,
      masterPassword: masterPassword,
    );
    return Vault.fromJson(
      (jsonDecode(plaintext) as Map<String, Object?>).cast<String, Object?>(),
    );
  }

  Future<VaultSyncResult> _uploadSyncedVault({
    required Vault vault,
    required String masterPassword,
    required SyncCredentials credentials,
    required String? remoteEtag,
    required String? remoteLastModified,
    bool onlyIfMissing = false,
  }) async {
    final payload = await _crypto.encryptString(
      plaintext: jsonEncode(vault.toJson()),
      masterPassword: masterPassword,
    );
    final body = jsonEncode(payload.toJson());
    await _remote.uploadVault(
      url: credentials.url,
      account: credentials.account,
      appPassword: credentials.appPassword,
      body: body,
      expectedEtag: remoteEtag,
      onlyIfMissing: onlyIfMissing,
    );
    return VaultSyncResult(
      status: VaultSyncStatus.synced,
      vault: vault,
      payload: payload,
      masterPassword: masterPassword,
      metadata: SyncMetadata(
        basePayload: payload,
        remoteEtag: remoteEtag,
        remoteLastModified: remoteLastModified,
        lastSyncedAt: DateTime.now().toUtc(),
        hasUnsyncedChanges: false,
      ),
    );
  }
}
