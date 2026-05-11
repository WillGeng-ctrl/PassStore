import 'package:flutter_test/flutter_test.dart';
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
    expect(result.vault.entries.map((e) => e.title).toSet(), {'GitHub', 'Steam'});
  });

  test('reports field conflict when same field changes on both sides', () {
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

    expect(result.conflicts.single.fieldName, 'password');
    expect(result.conflicts.single.localValue, 'local-secret');
    expect(result.conflicts.single.remoteValue, 'remote-secret');
  });
}
