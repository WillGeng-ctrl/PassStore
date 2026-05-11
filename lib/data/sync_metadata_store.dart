import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../core/services/vault_crypto.dart';

class SyncMetadata {
  const SyncMetadata({
    this.basePayload,
    this.remoteEtag,
    this.remoteLastModified,
    this.lastSyncedAt,
    this.hasUnsyncedChanges = false,
    this.lastError,
  });

  static const empty = SyncMetadata();

  final EncryptedVaultPayload? basePayload;
  final String? remoteEtag;
  final String? remoteLastModified;
  final DateTime? lastSyncedAt;
  final bool hasUnsyncedChanges;
  final String? lastError;

  SyncMetadata copyWith({
    Object? basePayload = _sentinel,
    Object? remoteEtag = _sentinel,
    Object? remoteLastModified = _sentinel,
    Object? lastSyncedAt = _sentinel,
    bool? hasUnsyncedChanges,
    Object? lastError = _sentinel,
  }) {
    return SyncMetadata(
      basePayload: identical(basePayload, _sentinel)
          ? this.basePayload
          : basePayload as EncryptedVaultPayload?,
      remoteEtag: identical(remoteEtag, _sentinel)
          ? this.remoteEtag
          : remoteEtag as String?,
      remoteLastModified: identical(remoteLastModified, _sentinel)
          ? this.remoteLastModified
          : remoteLastModified as String?,
      lastSyncedAt: identical(lastSyncedAt, _sentinel)
          ? this.lastSyncedAt
          : lastSyncedAt as DateTime?,
      hasUnsyncedChanges: hasUnsyncedChanges ?? this.hasUnsyncedChanges,
      lastError: identical(lastError, _sentinel)
          ? this.lastError
          : lastError as String?,
    );
  }

  Map<String, Object?> toJson() => {
    'basePayload': basePayload?.toJson(),
    'remoteEtag': remoteEtag,
    'remoteLastModified': remoteLastModified,
    'lastSyncedAt': lastSyncedAt?.toIso8601String(),
    'hasUnsyncedChanges': hasUnsyncedChanges,
    'lastError': lastError,
  };

  factory SyncMetadata.fromJson(Map<String, Object?> json) {
    final basePayloadJson = json['basePayload'];
    return SyncMetadata(
      basePayload: basePayloadJson == null
          ? null
          : EncryptedVaultPayload.fromJson(
              (basePayloadJson as Map<Object?, Object?>).cast(),
            ),
      remoteEtag: json['remoteEtag'] as String?,
      remoteLastModified: json['remoteLastModified'] as String?,
      lastSyncedAt: json['lastSyncedAt'] == null
          ? null
          : DateTime.parse(json['lastSyncedAt']! as String),
      hasUnsyncedChanges: json['hasUnsyncedChanges'] as bool? ?? false,
      lastError: json['lastError'] as String?,
    );
  }

  static const Object _sentinel = Object();
}

class SyncMetadataStore {
  const SyncMetadataStore({
    Directory? directory,
    this.fileName = 'sync_metadata.json',
  }) : _directory = directory;

  final Directory? _directory;
  final String fileName;

  Future<SyncMetadata> load() async {
    final file = await _file();
    if (!await file.exists()) return SyncMetadata.empty;
    final json = jsonDecode(await file.readAsString()) as Map<String, Object?>;
    return SyncMetadata.fromJson(json);
  }

  Future<void> save(SyncMetadata metadata) async {
    final file = await _file();
    await file.parent.create(recursive: true);
    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert(metadata.toJson()),
      flush: true,
    );
  }

  Future<File> _file() async {
    return File(p.join((_directory ?? _appDataDirectory()).path, fileName));
  }

  Directory _appDataDirectory() {
    if (Platform.isWindows) {
      final appData = Platform.environment['APPDATA'];
      if (appData != null && appData.isNotEmpty) {
        return Directory(p.join(appData, 'PassStore'));
      }
    }
    if (Platform.isMacOS) {
      final home = Platform.environment['HOME'];
      if (home != null && home.isNotEmpty) {
        return Directory(
          p.join(home, 'Library', 'Application Support', 'PassStore'),
        );
      }
    }
    return Directory(p.join(Directory.current.path, '.passstore'));
  }
}
