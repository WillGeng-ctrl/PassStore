import '../models/category.dart';
import '../models/vault.dart';
import '../models/vault_entry.dart';
import '../models/vault_webdav_credentials.dart';

class VaultService {
  const VaultService._();

  static Vault createEmptyVault({
    required DateTime now,
    String deviceId = 'local',
  }) {
    return Vault(
      id: 'vault-${now.microsecondsSinceEpoch}',
      revision: 1,
      createdAt: now,
      updatedAt: now,
      lastModifiedDeviceId: deviceId,
      categories: Category.builtIns(now),
      entries: const [],
    );
  }

  static Vault addCategory(
    Vault vault, {
    required String name,
    required DateTime now,
    String deviceId = 'local',
  }) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      throw const VaultValidationException('分类名称不能为空');
    }
    if (vault.categories.any((category) => category.name == trimmed)) {
      throw const VaultValidationException('分类名称已存在');
    }
    final category = Category(
      id: 'category-${now.microsecondsSinceEpoch}-${trimmed.hashCode.abs()}',
      name: trimmed,
      sortOrder: vault.categories.length,
      isBuiltIn: false,
      createdAt: now,
      updatedAt: now,
    );
    return _touchVault(
      vault.copyWith(categories: [...vault.categories, category]),
      now: now,
      deviceId: deviceId,
    );
  }

  static Vault renameCategory(
    Vault vault, {
    required String categoryId,
    required String name,
    required DateTime now,
    String deviceId = 'local',
  }) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      throw const VaultValidationException('分类名称不能为空');
    }
    final categories = vault.categories.map((category) {
      if (category.id != categoryId) return category;
      if (category.isBuiltIn) {
        throw const VaultValidationException('默认分类无法重命名');
      }
      return category.copyWith(name: trimmed, updatedAt: now);
    }).toList();
    return _touchVault(
      vault.copyWith(categories: categories),
      now: now,
      deviceId: deviceId,
    );
  }

  static Vault deleteCategory(
    Vault vault, {
    required String categoryId,
    required DateTime now,
    String deviceId = 'local',
  }) {
    final target = vault.categories.singleWhere(
      (category) => category.id == categoryId,
      orElse: () => throw const VaultValidationException('分类不存在'),
    );
    if (target.isBuiltIn) {
      throw const VaultValidationException('默认分类无法删除');
    }
    final other = vault.categories.singleWhere(
      (category) => category.id == Category.otherId,
    );
    final categories = vault.categories
        .where((category) => category.id != categoryId)
        .toList(growable: false);
    final entries = vault.entries.map((entry) {
      if (entry.categoryId != categoryId) return entry;
      return entry
          .copyWith(categoryId: other.id)
          .touch(now: now, fields: const ['categoryId'], deviceId: deviceId);
    }).toList();
    return _touchVault(
      vault.copyWith(categories: categories, entries: entries),
      now: now,
      deviceId: deviceId,
    );
  }

  static Vault upsertEntry(
    Vault vault,
    VaultEntry entry, {
    required DateTime now,
    String deviceId = 'local',
  }) {
    if (!vault.categories.any((category) => category.id == entry.categoryId)) {
      throw const VaultValidationException('条目分类不存在');
    }
    final existingIndex = vault.entries.indexWhere(
      (item) => item.id == entry.id,
    );
    final entries = [...vault.entries];
    if (existingIndex == -1) {
      entries.add(
        entry.copyWith(updatedAt: now, lastModifiedDeviceId: deviceId),
      );
    } else {
      final existing = entries[existingIndex];
      final changedFields = <String>{};
      if (existing.title != entry.title) changedFields.add('title');
      if (existing.account != entry.account) changedFields.add('account');
      if (existing.password != entry.password) changedFields.add('password');
      if (existing.url != entry.url) changedFields.add('url');
      if (existing.notes != entry.notes) changedFields.add('notes');
      if (existing.categoryId != entry.categoryId) {
        changedFields.add('categoryId');
      }
      if (existing.deletedAt != entry.deletedAt) changedFields.add('deletedAt');
      entries[existingIndex] = entry
          .copyWith(revision: existing.revision)
          .touch(now: now, fields: changedFields, deviceId: deviceId);
    }
    return _touchVault(
      vault.copyWith(entries: entries),
      now: now,
      deviceId: deviceId,
    );
  }

  static Vault deleteEntry(
    Vault vault, {
    required String entryId,
    required DateTime now,
    String deviceId = 'local',
  }) {
    final entries = vault.entries.map((entry) {
      if (entry.id != entryId) return entry;
      return entry
          .copyWith(deletedAt: now)
          .touch(now: now, fields: const ['deletedAt'], deviceId: deviceId);
    }).toList();
    return _touchVault(
      vault.copyWith(entries: entries),
      now: now,
      deviceId: deviceId,
    );
  }

  static Vault restoreEntry(
    Vault vault, {
    required String entryId,
    required DateTime now,
    String deviceId = 'local',
  }) {
    final entries = vault.entries.map((entry) {
      if (entry.id != entryId) return entry;
      return entry
          .copyWith(deletedAt: null)
          .touch(now: now, fields: const ['deletedAt'], deviceId: deviceId);
    }).toList();
    return _touchVault(
      vault.copyWith(entries: entries),
      now: now,
      deviceId: deviceId,
    );
  }

  static Vault permanentlyDeleteEntry(
    Vault vault, {
    required String entryId,
    required DateTime now,
    String deviceId = 'local',
  }) {
    return _touchVault(
      vault.copyWith(
        entries: vault.entries
            .where((entry) => entry.id != entryId)
            .toList(growable: false),
      ),
      now: now,
      deviceId: deviceId,
    );
  }

  static Vault saveWebDavCredentials(
    Vault vault, {
    required String url,
    required String account,
    required String appPassword,
    required DateTime now,
    String deviceId = 'local',
  }) {
    final trimmedPassword = appPassword.trim();
    final nextPassword = trimmedPassword.isNotEmpty
        ? trimmedPassword
        : vault.webDavCredentials?.appPassword ?? '';
    final credentials = VaultWebDavCredentials(
      url: url.trim(),
      account: account.trim(),
      appPassword: nextPassword,
    );
    return _touchVault(
      vault.copyWith(webDavCredentials: credentials),
      now: now,
      deviceId: deviceId,
    );
  }

  static Vault _touchVault(
    Vault vault, {
    required DateTime now,
    required String deviceId,
  }) {
    return vault.copyWith(
      revision: vault.revision + 1,
      updatedAt: now,
      lastModifiedDeviceId: deviceId,
    );
  }
}

class VaultValidationException implements Exception {
  const VaultValidationException(this.message);

  final String message;

  @override
  String toString() => message;
}
