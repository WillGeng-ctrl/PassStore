import 'package:flutter_test/flutter_test.dart';
import 'package:passstore/core/models/category.dart';
import 'package:passstore/core/models/vault_entry.dart';
import 'package:passstore/core/services/vault_merge.dart';
import 'package:passstore/core/services/vault_service.dart';

void main() {
  test('merges different entries changed on different devices', () {
    final now = DateTime.utc(2026, 5, 11);
    final base = VaultService.createEmptyVault(now: now);
    final site = base.categories.singleWhere((c) => c.name == '网站');
    final local = VaultService.upsertEntry(
      base,
      VaultEntry.create(
        title: 'GitHub',
        account: 'user@example.com',
        password: 'local',
        url: 'https://github.com',
        notes: '',
        categoryId: site.id,
        now: now,
      ),
      now: now,
    );
    final remote = VaultService.upsertEntry(
      base,
      VaultEntry.create(
        title: 'Steam',
        account: 'steamuser',
        password: 'remote',
        url: 'https://store.steampowered.com',
        notes: '',
        categoryId: site.id,
        now: now,
      ),
      now: now,
    );

    final result = VaultMerge.merge(base: base, local: local, remote: remote);

    expect(result.conflicts, isEmpty);
    expect(result.vault.entries.map((e) => e.title).toSet(), {
      'GitHub',
      'Steam',
    });
  });

  test('keeps newer field value when same field changes on both sides', () {
    final now = DateTime.utc(2026, 5, 11);
    var base = VaultService.createEmptyVault(now: now);
    final site = base.categories.singleWhere((c) => c.name == '网站');
    final entry = VaultEntry.create(
      title: 'GitHub',
      account: 'user@example.com',
      password: 'secret',
      url: 'https://github.com',
      notes: '',
      categoryId: site.id,
      now: now,
    );
    base = VaultService.upsertEntry(base, entry, now: now);
    final local = VaultService.upsertEntry(
      base,
      entry.copyWith(password: 'local-secret'),
      now: now.add(const Duration(minutes: 1)),
    );
    final remote = VaultService.upsertEntry(
      base,
      entry.copyWith(password: 'remote-secret'),
      now: now.add(const Duration(minutes: 2)),
    );

    final result = VaultMerge.merge(base: base, local: local, remote: remote);

    expect(result.conflicts, isEmpty);
    expect(result.vault.entries.single.password, 'remote-secret');
  });

  test('merges categories added on different devices', () {
    final now = DateTime.utc(2026, 5, 12);
    final base = VaultService.createEmptyVault(now: now);
    final local = VaultService.addCategory(
      base,
      name: '工作',
      now: now.add(const Duration(minutes: 1)),
    );
    final remote = VaultService.addCategory(
      base,
      name: '金融',
      now: now.add(const Duration(minutes: 2)),
    );

    final result = VaultMerge.merge(base: base, local: local, remote: remote);

    expect(result.vault.categories.map((c) => c.name), contains('工作'));
    expect(result.vault.categories.map((c) => c.name), contains('金融'));
  });

  test('keeps newer custom category rename', () {
    final now = DateTime.utc(2026, 5, 12);
    var base = VaultService.createEmptyVault(now: now);
    base = VaultService.addCategory(
      base,
      name: '工作',
      now: now.add(const Duration(minutes: 1)),
    );
    final work = base.categories.singleWhere((c) => c.name == '工作');
    final local = VaultService.renameCategory(
      base,
      categoryId: work.id,
      name: '工作资料',
      now: now.add(const Duration(minutes: 2)),
    );
    final remote = VaultService.renameCategory(
      base,
      categoryId: work.id,
      name: '办公',
      now: now.add(const Duration(minutes: 3)),
    );

    final result = VaultMerge.merge(base: base, local: local, remote: remote);

    expect(
      result.vault.categories.singleWhere((c) => c.id == work.id).name,
      '办公',
    );
  });

  test('does not resurrect a custom category deleted on one side', () {
    final now = DateTime.utc(2026, 5, 12);
    var base = VaultService.createEmptyVault(now: now);
    base = VaultService.addCategory(
      base,
      name: '工作',
      now: now.add(const Duration(minutes: 1)),
    );
    final work = base.categories.singleWhere((c) => c.name == '工作');
    final local = VaultService.deleteCategory(
      base,
      categoryId: work.id,
      now: now.add(const Duration(minutes: 2)),
    );
    final remote = base;

    final result = VaultMerge.merge(base: base, local: local, remote: remote);

    expect(result.vault.categories.any((c) => c.id == work.id), isFalse);
  });

  test('moves merged entries out of a category deleted on one side', () {
    final now = DateTime.utc(2026, 5, 12);
    var base = VaultService.createEmptyVault(now: now);
    base = VaultService.addCategory(
      base,
      name: '工作',
      now: now.add(const Duration(minutes: 1)),
    );
    final work = base.categories.singleWhere((c) => c.name == '工作');
    final local = VaultService.deleteCategory(
      base,
      categoryId: work.id,
      now: now.add(const Duration(minutes: 2)),
    );
    final remote = VaultService.upsertEntry(
      base,
      VaultEntry.create(
        title: 'Remote item',
        account: 'remote@example.com',
        password: 'remote',
        url: 'https://example.com',
        notes: '',
        categoryId: work.id,
        now: now.add(const Duration(minutes: 3)),
      ),
      now: now.add(const Duration(minutes: 3)),
    );

    final result = VaultMerge.merge(base: base, local: local, remote: remote);
    final mergedEntry = result.vault.entries.singleWhere(
      (entry) => entry.title == 'Remote item',
    );

    expect(result.vault.categories.any((c) => c.id == work.id), isFalse);
    expect(mergedEntry.categoryId, Category.otherId);
  });

  test('keeps local additions when there is no sync base yet', () {
    final now = DateTime.utc(2026, 5, 12);
    var local = VaultService.createEmptyVault(now: now);
    local = VaultService.addCategory(
      local,
      name: '工作',
      now: now.add(const Duration(minutes: 1)),
    );
    final work = local.categories.singleWhere((c) => c.name == '工作');
    local = VaultService.upsertEntry(
      local,
      VaultEntry.create(
        title: 'Local item',
        account: 'local@example.com',
        password: 'local',
        url: 'https://example.com',
        notes: '',
        categoryId: work.id,
        now: now.add(const Duration(minutes: 2)),
      ),
      now: now.add(const Duration(minutes: 2)),
    );
    final remote = VaultService.createEmptyVault(now: now);

    final result = VaultMerge.merge(
      base: local,
      local: local,
      remote: remote,
      hasBase: false,
    );

    expect(result.vault.categories.map((c) => c.name), contains('工作'));
    expect(result.vault.entries.map((e) => e.title), contains('Local item'));
  });

  test('does not resurrect a permanently deleted entry', () {
    final now = DateTime.utc(2026, 5, 12);
    var base = VaultService.createEmptyVault(now: now);
    base = VaultService.upsertEntry(
      base,
      VaultEntry.create(
        title: 'Old item',
        account: 'old@example.com',
        password: 'old',
        url: 'https://example.com',
        notes: '',
        categoryId: Category.websiteId,
        now: now.add(const Duration(minutes: 1)),
      ),
      now: now.add(const Duration(minutes: 1)),
    );
    final entry = base.entries.single;
    final local = VaultService.permanentlyDeleteEntry(
      base,
      entryId: entry.id,
      now: now.add(const Duration(minutes: 2)),
    );
    final remote = base;

    final result = VaultMerge.merge(base: base, local: local, remote: remote);

    expect(result.vault.entries.any((e) => e.id == entry.id), isFalse);
  });

  test('keeps restore while merging another side entry edit', () {
    final now = DateTime.utc(2026, 5, 12);
    var base = VaultService.createEmptyVault(now: now);
    base = VaultService.upsertEntry(
      base,
      VaultEntry.create(
        title: 'Deleted item',
        account: 'deleted@example.com',
        password: 'secret',
        url: 'https://example.com',
        notes: '',
        categoryId: Category.websiteId,
        now: now.add(const Duration(minutes: 1)),
      ),
      now: now.add(const Duration(minutes: 1)),
    );
    final entry = base.entries.single;
    base = VaultService.deleteEntry(
      base,
      entryId: entry.id,
      now: now.add(const Duration(minutes: 2)),
    );
    final deletedEntry = base.entries.single;
    final local = VaultService.restoreEntry(
      base,
      entryId: deletedEntry.id,
      now: now.add(const Duration(minutes: 3)),
    );
    final remote = VaultService.upsertEntry(
      base,
      deletedEntry.copyWith(title: 'Renamed while deleted'),
      now: now.add(const Duration(minutes: 4)),
    );

    final result = VaultMerge.merge(base: base, local: local, remote: remote);
    final mergedEntry = result.vault.entries.singleWhere(
      (item) => item.id == entry.id,
    );

    expect(mergedEntry.title, 'Renamed while deleted');
    expect(mergedEntry.deletedAt, isNull);
  });
}
