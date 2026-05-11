import 'package:flutter_test/flutter_test.dart';
import 'package:passstore/core/models/vault_entry.dart';
import 'package:passstore/core/services/vault_service.dart';

void main() {
  test('creates vault with the four default categories', () {
    final vault = VaultService.createEmptyVault(now: DateTime.utc(2026, 5, 11));

    expect(vault.categories.map((c) => c.name), ['网站', '应用', '游戏', '其他']);
    expect(vault.categories.every((c) => c.isBuiltIn), isTrue);
  });

  test('moves entries to other when deleting a custom category', () {
    final now = DateTime.utc(2026, 5, 11);
    var vault = VaultService.createEmptyVault(now: now);
    vault = VaultService.addCategory(vault, name: '工作', now: now);
    final work = vault.categories.singleWhere((c) => c.name == '工作');
    vault = VaultService.upsertEntry(
      vault,
      VaultEntry.create(
        title: 'Slack 工作区',
        account: 'work@example.com',
        password: 'secret',
        url: 'https://company.slack.com',
        notes: '公司内部通讯',
        categoryId: work.id,
        now: now,
      ),
      now: now,
    );

    vault = VaultService.deleteCategory(vault, categoryId: work.id, now: now);

    final other = vault.categories.singleWhere((c) => c.name == '其他');
    expect(vault.entries.single.categoryId, other.id);
    expect(vault.categories.any((c) => c.id == work.id), isFalse);
  });

  test('delete moves entry to recycle bin and restore clears deleted timestamp', () {
    final now = DateTime.utc(2026, 5, 11);
    var vault = VaultService.createEmptyVault(now: now);
    final site = vault.categories.singleWhere((c) => c.name == '网站');
    final entry = VaultEntry.create(
      title: 'GitHub',
      account: 'user@example.com',
      password: 'secret',
      url: 'https://github.com',
      notes: '',
      categoryId: site.id,
      now: now,
    );
    vault = VaultService.upsertEntry(vault, entry, now: now);

    vault = VaultService.deleteEntry(vault, entryId: entry.id, now: now);
    expect(vault.entries.single.deletedAt, isNotNull);

    vault = VaultService.restoreEntry(vault, entryId: entry.id, now: now);
    expect(vault.entries.single.deletedAt, isNull);
  });
}
