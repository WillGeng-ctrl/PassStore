import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

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
    final dir = await getApplicationDocumentsDirectory();
    return File(p.join(dir.path, 'PassStore', fileName));
  }
}
