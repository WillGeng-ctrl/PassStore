import '../models/category.dart';
import '../models/vault.dart';
import '../models/vault_entry.dart';

class VaultMerge {
  const VaultMerge._();

  static const _mergeFields = [
    'title',
    'account',
    'password',
    'url',
    'notes',
    'categoryId',
    'deletedAt',
  ];

  static VaultMergeResult merge({
    required Vault base,
    required Vault local,
    required Vault remote,
  }) {
    final baseEntries = {for (final entry in base.entries) entry.id: entry};
    final localEntries = {for (final entry in local.entries) entry.id: entry};
    final remoteEntries = {for (final entry in remote.entries) entry.id: entry};
    final entryIds = <String>{
      ...baseEntries.keys,
      ...localEntries.keys,
      ...remoteEntries.keys,
    };

    final conflicts = <FieldConflict>[];
    final mergedEntries = <VaultEntry>[];

    for (final id in entryIds) {
      final baseEntry = baseEntries[id];
      final localEntry = localEntries[id];
      final remoteEntry = remoteEntries[id];

      if (baseEntry == null) {
        if (localEntry != null && remoteEntry != null) {
          mergedEntries.add(_newerEntry(localEntry, remoteEntry));
        } else {
          mergedEntries.add((localEntry ?? remoteEntry)!);
        }
        continue;
      }

      if (localEntry == null && remoteEntry == null) continue;
      if (localEntry == null) {
        mergedEntries.add(remoteEntry!);
        continue;
      }
      if (remoteEntry == null) {
        mergedEntries.add(localEntry);
        continue;
      }

      var merged = _newerEntry(localEntry, remoteEntry);
      final fieldValues = <String, Object?>{};
      for (final field in _mergeFields) {
        final baseValue = _valueFor(baseEntry, field);
        final localValue = _valueFor(localEntry, field);
        final remoteValue = _valueFor(remoteEntry, field);
        final localChanged = localValue != baseValue;
        final remoteChanged = remoteValue != baseValue;

        if (localChanged && remoteChanged && localValue != remoteValue) {
          conflicts.add(
            FieldConflict(
              entryId: id,
              fieldName: field,
              localValue: localValue,
              remoteValue: remoteValue,
            ),
          );
          fieldValues[field] = localValue;
        } else if (localChanged) {
          fieldValues[field] = localValue;
        } else if (remoteChanged) {
          fieldValues[field] = remoteValue;
        } else {
          fieldValues[field] = baseValue;
        }
      }
      merged = _copyEntryWithFieldValues(merged, fieldValues);
      mergedEntries.add(merged);
    }

    final mergedVault = local.copyWith(
      revision: local.revision > remote.revision ? local.revision + 1 : remote.revision + 1,
      updatedAt: _maxDate(local.updatedAt, remote.updatedAt),
      categories: _mergeCategories(local.categories, remote.categories),
      entries: mergedEntries..sort((a, b) => b.updatedAt.compareTo(a.updatedAt)),
    );
    return VaultMergeResult(vault: mergedVault, conflicts: conflicts);
  }

  static VaultEntry _newerEntry(VaultEntry left, VaultEntry right) {
    if (left.updatedAt.isAfter(right.updatedAt)) return left;
    return right;
  }

  static DateTime _maxDate(DateTime left, DateTime right) {
    if (left.isAfter(right)) return left;
    return right;
  }

  static Object? _valueFor(VaultEntry entry, String field) {
    return switch (field) {
      'title' => entry.title,
      'account' => entry.account,
      'password' => entry.password,
      'url' => entry.url,
      'notes' => entry.notes,
      'categoryId' => entry.categoryId,
      'deletedAt' => entry.deletedAt?.toIso8601String(),
      _ => throw ArgumentError('Unknown entry field: $field'),
    };
  }

  static VaultEntry _copyEntryWithFieldValues(
    VaultEntry entry,
    Map<String, Object?> fields,
  ) {
    return entry.copyWith(
      title: fields['title'] as String? ?? entry.title,
      account: fields['account'] as String? ?? entry.account,
      password: fields['password'] as String? ?? entry.password,
      url: fields['url'] as String? ?? entry.url,
      notes: fields['notes'] as String? ?? entry.notes,
      categoryId: fields['categoryId'] as String? ?? entry.categoryId,
      deletedAt: fields.containsKey('deletedAt') && fields['deletedAt'] != null
          ? DateTime.parse(fields['deletedAt']! as String)
          : entry.deletedAt,
    );
  }

  static List<Category> _mergeCategories(
    List<Category> local,
    List<Category> remote,
  ) {
    final merged = <String, Category>{};
    for (final category in [...local, ...remote]) {
      final existing = merged[category.id];
      if (existing == null || category.updatedAt.isAfter(existing.updatedAt)) {
        merged[category.id] = category;
      }
    }
    final result = merged.values.toList()
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    return result;
  }
}

class VaultMergeResult {
  const VaultMergeResult({
    required this.vault,
    required this.conflicts,
  });

  final Vault vault;
  final List<FieldConflict> conflicts;
}

class FieldConflict {
  const FieldConflict({
    required this.entryId,
    required this.fieldName,
    required this.localValue,
    required this.remoteValue,
  });

  final String entryId;
  final String fieldName;
  final Object? localValue;
  final Object? remoteValue;
}
