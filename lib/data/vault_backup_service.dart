import 'dart:convert';
import 'dart:io';

import '../core/services/vault_crypto.dart';

class VaultBackupService {
  const VaultBackupService();

  Future<void> exportEncryptedPayload(
    EncryptedVaultPayload payload,
    String path,
  ) async {
    final file = File(path);
    await file.parent.create(recursive: true);
    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert(payload.toJson()),
      flush: true,
    );
  }

  Future<EncryptedVaultPayload> importEncryptedPayload(String path) async {
    final json = jsonDecode(await File(path).readAsString());
    if (json is! Map<String, Object?>) {
      throw const FormatException('备份文件格式无效');
    }
    return EncryptedVaultPayload.fromJson(json);
  }
}
