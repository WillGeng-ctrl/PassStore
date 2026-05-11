import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../core/services/vault_crypto.dart';

class LocalVaultRepository {
  const LocalVaultRepository({this.fileName = 'passstore.vault'});

  final String fileName;

  Future<bool> exists() async => (await _vaultFile()).exists();

  Future<EncryptedVaultPayload?> readEncrypted() async {
    final file = await _vaultFile();
    if (!await file.exists()) return null;
    final json = jsonDecode(await file.readAsString()) as Map<String, Object?>;
    return EncryptedVaultPayload.fromJson(json);
  }

  Future<void> writeEncrypted(EncryptedVaultPayload payload) async {
    final file = await _vaultFile();
    await file.parent.create(recursive: true);
    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert(payload.toJson()),
      flush: true,
    );
  }

  Future<File> _vaultFile() async {
    return File(p.join(_appDataDirectory().path, fileName));
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
        return Directory(p.join(home, 'Library', 'Application Support', 'PassStore'));
      }
    }
    return Directory(p.join(Directory.current.path, '.passstore'));
  }
}
