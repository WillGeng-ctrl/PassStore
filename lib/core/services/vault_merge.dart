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
    bool hasBase = true,
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
        if (hasBase) continue;
        mergedEntries.add(remoteEntry!);
        continue;
      }
      if (remoteEntry == null) {
        if (hasBase) continue;
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
          fieldValues[field] = _newerFieldValue(
            field: field,
            localEntry: localEntry,
            remoteEntry: remoteEntry,
            localValue: localValue,
            remoteValue: remoteValue,
          );
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

    final mergedCategories = _mergeCategories(
      base: base.categories,
      local: local.categories,
      remote: remote.categories,
      hasBase: hasBase,
    );
    final validCategoryIds = mergedCategories
        .map((category) => category.id)
        .toSet();
    final normalizedEntries = mergedEntries.map((entry) {
      if (validCategoryIds.contains(entry.categoryId)) return entry;
      return entry.copyWith(categoryId: Category.otherId);
    }).toList();

    final mergedVault = local.copyWith(
      revision: local.revision > remote.revision
          ? local.revision + 1
          : remote.revision + 1,
      updatedAt: _maxDate(local.updatedAt, remote.updatedAt),
      categories: mergedCategories,
      entries: normalizedEntries
        ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt)),
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

  static Object? _newerFieldValue({
    required String field,
    required VaultEntry localEntry,
    required VaultEntry remoteEntry,
    required Object? localValue,
    required Object? remoteValue,
  }) {
    final localUpdatedAt =
        localEntry.fieldUpdatedAt[field] ?? localEntry.updatedAt;
    final remoteUpdatedAt =
        remoteEntry.fieldUpdatedAt[field] ?? remoteEntry.updatedAt;
    if (remoteUpdatedAt.isAfter(localUpdatedAt)) return remoteValue;
    return localValue;
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
    final deletedAt = fields.containsKey('deletedAt')
        ? fields['deletedAt'] == null
              ? null
              : DateTime.parse(fields['deletedAt']! as String)
        : entry.deletedAt;

    return entry.copyWith(
      title: fields['title'] as String? ?? entry.title,
      account: fields['account'] as String? ?? entry.account,
      password: fields['password'] as String? ?? entry.password,
      url: fields['url'] as String? ?? entry.url,
      notes: fields['notes'] as String? ?? entry.notes,
      categoryId: fields['categoryId'] as String? ?? entry.categoryId,
      deletedAt: deletedAt,
    );
  }

  static List<Category> _mergeCategories({
    required List<Category> base,
    required List<Category> local,
    required List<Category> remote,
    required bool hasBase,
  }) {
    final baseById = {for (final category in base) category.id: category};
    final localById = {for (final category in local) category.id: category};
    final remoteById = {for (final category in remote) category.id: category};
    final ids = <String>{
      ...baseById.keys,
      ...localById.keys,
      ...remoteById.keys,
    };

    final merged = <Category>[];
    for (final id in ids) {
      final baseCategory = baseById[id];
      final localCategory = localById[id];
      final remoteCategory = remoteById[id];

      if (baseCategory?.isBuiltIn ?? false) {
        final fallback = baseCategory!;
        merged.add(
          _newerCategory(localCategory ?? fallback, remoteCategory ?? fallback),
        );
        continue;
      }

      if (hasBase &&
          baseCategory != null &&
          (localCategory == null || remoteCategory == null)) {
        continue;
      }

      final category = switch ((localCategory, remoteCategory)) {
        (final Category left, final Category right) => _newerCategory(
          left,
          right,
        ),
        (final Category only, null) => only,
        (null, final Category only) => only,
        (null, null) => null,
      };
      if (category != null) merged.add(category);
    }
    return merged..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
  }

  static Category _newerCategory(Category left, Category right) {
    if (left.updatedAt.isAfter(right.updatedAt)) return left;
    return right;
  }
}

class VaultMergeResult {
  const VaultMergeResult({required this.vault, required this.conflicts});

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
