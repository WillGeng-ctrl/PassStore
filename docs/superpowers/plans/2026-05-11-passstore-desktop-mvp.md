# PassStore Desktop MVP Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a first usable Windows/macOS Flutter Desktop MVP for PassStore with encrypted local vaults, simple categories, recycle bin, settings, and entry-level sync merge foundations.

**Architecture:** Use Flutter Desktop with a small layered structure: pure Dart core services under `lib/core`, persistence/sync adapters under `lib/data`, and desktop UI screens under `lib/features`. Core behavior is tested with Dart unit tests before implementation; generated Flutter scaffolding is treated as setup, not product behavior.

**Tech Stack:** Flutter Desktop, Dart, `flutter_test`, `cryptography`, `file`, `path`, `path_provider`, `shared_preferences`, `flutter_secure_storage`, `http`.

---

## File Structure

- Create: `.gitignore` - exclude Flutter build output and local tool downloads.
- Create: `pubspec.yaml` - Flutter package metadata and dependencies.
- Create: `lib/main.dart` - app entrypoint and state composition.
- Create: `lib/core/models/vault_entry.dart` - password entry and field timestamp model.
- Create: `lib/core/models/category.dart` - built-in and custom category model.
- Create: `lib/core/models/vault.dart` - encrypted payload model and helpers.
- Create: `lib/core/services/vault_service.dart` - create, edit, delete, restore, category behavior.
- Create: `lib/core/services/vault_crypto.dart` - master password KDF and authenticated vault encryption.
- Create: `lib/core/services/vault_merge.dart` - entry-level and field-level merge logic.
- Create: `lib/data/local_vault_repository.dart` - read/write local encrypted vault file.
- Create: `lib/data/webdav_settings.dart` - WebDAV settings model.
- Create: `lib/data/webdav_sync_service.dart` - WebDAV metadata, upload, download skeleton.
- Create: `lib/features/app_shell.dart` - desktop shell with top bar, category tree, list pane.
- Create: `lib/features/screens/create_vault_screen.dart` - first-run vault creation.
- Create: `lib/features/screens/unlock_screen.dart` - vault unlock.
- Create: `lib/features/screens/main_vault_screen.dart` - simplified tree/list main interface.
- Create: `lib/features/screens/edit_entry_dialog.dart` - add/edit/detail dialog.
- Create: `lib/features/screens/category_manager_screen.dart` - category management.
- Create: `lib/features/screens/recycle_bin_screen.dart` - deleted entry restore/delete.
- Create: `lib/features/screens/settings_screen.dart` - sync, security, backup/about settings.
- Create: `lib/features/screens/change_master_password_dialog.dart` - change master password flow.
- Create: `lib/features/screens/sync_conflict_dialog.dart` - field conflict resolution.
- Create: `test/core/vault_service_test.dart` - category and entry behavior tests.
- Create: `test/core/vault_crypto_test.dart` - encryption/decryption tests.
- Create: `test/core/vault_merge_test.dart` - entry-level merge tests.

## Task 1: Prepare Project and Toolchain

**Files:**
- Create: `.gitignore`
- Create: `pubspec.yaml`
- Create: `lib/main.dart`
- Create: `test/core/smoke_test.dart`

- [ ] **Step 1: Add ignore rules**

Create `.gitignore`:

```gitignore
.dart_tool/
.flutter-plugins
.flutter-plugins-dependencies
.packages
.pub-cache/
.pub/
.tools/
build/
coverage/
ios/Flutter/.last_build_id
macos/Flutter/ephemeral/
windows/flutter/ephemeral/
```

- [ ] **Step 2: Install Flutter locally if missing**

Run:

```powershell
if (-not (Get-Command flutter -ErrorAction SilentlyContinue)) {
  New-Item -ItemType Directory -Force -Path .tools | Out-Null
  if (-not (Test-Path .tools/flutter/bin/flutter.bat)) {
    git clone --depth 1 -b stable https://github.com/flutter/flutter.git .tools/flutter
  }
  $env:Path = (Resolve-Path .tools/flutter/bin).Path + ';' + $env:Path
}
flutter --version
```

Expected: Flutter version prints successfully.

- [ ] **Step 3: Create Flutter desktop project**

Run:

```powershell
flutter create . --project-name passstore --org app.passstore --platforms windows,macos
```

Expected: `lib/main.dart`, `test/widget_test.dart`, `windows/`, and `macos/` exist.

- [ ] **Step 4: Replace package dependencies**

Create `pubspec.yaml` with:

```yaml
name: passstore
description: A simple personal password vault for desktop.
publish_to: "none"
version: 0.1.0+1

environment:
  sdk: ">=3.4.0 <4.0.0"

dependencies:
  flutter:
    sdk: flutter
  cryptography: ^2.7.0
  file: ^7.0.1
  flutter_secure_storage: ^9.2.4
  http: ^1.2.2
  path: ^1.9.0
  path_provider: ^2.1.5
  shared_preferences: ^2.3.3

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^5.0.0

flutter:
  uses-material-design: true
```

- [ ] **Step 5: Add minimal smoke test**

Create `test/core/smoke_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('test harness runs', () {
    expect(1 + 1, 2);
  });
}
```

- [ ] **Step 6: Verify baseline**

Run:

```powershell
flutter pub get
flutter test test/core/smoke_test.dart
```

Expected: one test passes.

- [ ] **Step 7: Commit setup**

Run:

```powershell
git add .gitignore pubspec.yaml lib test windows macos
git commit -m "chore: scaffold Flutter desktop app"
```

## Task 2: Core Vault Models and Entry Behavior

**Files:**
- Create: `lib/core/models/category.dart`
- Create: `lib/core/models/vault_entry.dart`
- Create: `lib/core/models/vault.dart`
- Create: `lib/core/services/vault_service.dart`
- Test: `test/core/vault_service_test.dart`

- [ ] **Step 1: Write failing model and service tests**

Create `test/core/vault_service_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:passstore/core/models/category.dart';
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
```

- [ ] **Step 2: Run tests to verify RED**

Run:

```powershell
flutter test test/core/vault_service_test.dart
```

Expected: fails because models and service do not exist.

- [ ] **Step 3: Implement models and service**

Create the files listed above with immutable Dart classes, JSON serialization methods, `copyWith`, default category creation, category deletion movement to `其他`, entry delete/restore, and revision updates.

- [ ] **Step 4: Run tests to verify GREEN**

Run:

```powershell
flutter test test/core/vault_service_test.dart
```

Expected: all tests pass.

- [ ] **Step 5: Commit core models**

Run:

```powershell
git add lib/core test/core/vault_service_test.dart
git commit -m "feat: add vault models and entry behavior"
```

## Task 3: Vault Encryption

**Files:**
- Create: `lib/core/services/vault_crypto.dart`
- Test: `test/core/vault_crypto_test.dart`

- [ ] **Step 1: Write failing crypto tests**

Create `test/core/vault_crypto_test.dart`:

```dart
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:passstore/core/services/vault_crypto.dart';

void main() {
  test('encrypts and decrypts payload with the correct master password', () async {
    final crypto = VaultCrypto();
    final encrypted = await crypto.encryptString(
      plaintext: jsonEncode({'title': 'GitHub', 'password': 'secret'}),
      masterPassword: 'correct horse battery staple',
    );

    final decrypted = await crypto.decryptString(
      encrypted,
      masterPassword: 'correct horse battery staple',
    );

    expect(jsonDecode(decrypted), {'title': 'GitHub', 'password': 'secret'});
    expect(encrypted.ciphertext, isNot(contains('secret')));
  });

  test('wrong master password fails to decrypt', () async {
    final crypto = VaultCrypto();
    final encrypted = await crypto.encryptString(
      plaintext: 'private',
      masterPassword: 'right-password',
    );

    expect(
      () => crypto.decryptString(encrypted, masterPassword: 'wrong-password'),
      throwsA(isA<VaultCryptoException>()),
    );
  });
}
```

- [ ] **Step 2: Run tests to verify RED**

Run:

```powershell
flutter test test/core/vault_crypto_test.dart
```

Expected: fails because `VaultCrypto` does not exist.

- [ ] **Step 3: Implement encryption service**

Use `cryptography` with `Argon2id` when available in the package; if unavailable, use `Pbkdf2` with SHA-256 and at least 210,000 iterations plus `AesGcm.with256bits()`. Store envelope fields: format version, algorithm, KDF, KDF parameters, salt, nonce, and base64 ciphertext.

- [ ] **Step 4: Run tests to verify GREEN**

Run:

```powershell
flutter test test/core/vault_crypto_test.dart
```

Expected: both tests pass.

- [ ] **Step 5: Commit crypto**

Run:

```powershell
git add lib/core/services/vault_crypto.dart test/core/vault_crypto_test.dart
git commit -m "feat: encrypt vault payloads"
```

## Task 4: Entry-Level Merge

**Files:**
- Create: `lib/core/services/vault_merge.dart`
- Test: `test/core/vault_merge_test.dart`

- [ ] **Step 1: Write failing merge tests**

Create `test/core/vault_merge_test.dart`:

```dart
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
```

- [ ] **Step 2: Run tests to verify RED**

Run:

```powershell
flutter test test/core/vault_merge_test.dart
```

Expected: fails because merge service does not exist.

- [ ] **Step 3: Implement merge service**

Implement `VaultMerge.merge` to compare entries by ID, carry forward local-only and remote-only changes, auto-merge non-overlapping changes, and return `FieldConflict` objects for same-field conflicts.

- [ ] **Step 4: Run tests to verify GREEN**

Run:

```powershell
flutter test test/core/vault_merge_test.dart
```

Expected: all merge tests pass.

- [ ] **Step 5: Commit merge**

Run:

```powershell
git add lib/core/services/vault_merge.dart test/core/vault_merge_test.dart
git commit -m "feat: merge vault entries by field"
```

## Task 5: Local Repository and UI Shell

**Files:**
- Create: `lib/data/local_vault_repository.dart`
- Create: `lib/features/app_shell.dart`
- Create: `lib/features/screens/create_vault_screen.dart`
- Create: `lib/features/screens/unlock_screen.dart`
- Create: `lib/features/screens/main_vault_screen.dart`
- Modify: `lib/main.dart`

- [ ] **Step 1: Implement local repository**

Create `LocalVaultRepository` with methods `exists`, `readEncrypted`, `writeEncrypted`, `deleteLocalVault`, and app document directory resolution through `path_provider`.

- [ ] **Step 2: Implement create and unlock flow**

Wire `CreateVaultScreen` and `UnlockScreen` to create encrypted vault files and unlock existing vaults.

- [ ] **Step 3: Implement simplified main interface**

Build a desktop UI with a top bar, sync badge, settings and lock buttons, left category tree, search field, new entry button, and right-side entry list only. Do not include a permanent detail panel.

- [ ] **Step 4: Run analyzer**

Run:

```powershell
flutter analyze
```

Expected: no errors.

- [ ] **Step 5: Commit UI shell**

Run:

```powershell
git add lib/data lib/features lib/main.dart
git commit -m "feat: add desktop vault shell"
```

## Task 6: Entry Dialogs, Categories, Recycle Bin, and Settings

**Files:**
- Create: `lib/features/screens/edit_entry_dialog.dart`
- Create: `lib/features/screens/category_manager_screen.dart`
- Create: `lib/features/screens/recycle_bin_screen.dart`
- Create: `lib/features/screens/settings_screen.dart`
- Create: `lib/features/screens/change_master_password_dialog.dart`
- Create: `lib/features/screens/sync_conflict_dialog.dart`
- Create: `lib/data/webdav_settings.dart`
- Create: `lib/data/webdav_sync_service.dart`

- [ ] **Step 1: Implement entry dialog**

Add create/edit/detail dialog with title, category, account, password, URL, notes, show/hide password, copy actions, save, and cancel.

- [ ] **Step 2: Implement category manager**

Add default categories as read-only rows and custom category create/rename/delete behavior. Deleting a custom category moves entries to `其他`.

- [ ] **Step 3: Implement recycle bin**

Add list of deleted entries with restore and permanent delete actions.

- [ ] **Step 4: Implement settings**

Add settings groups for sync settings, security settings, backup/recovery, and about. Include WebDAV URL/account/app password fields, test connection, save settings, auto-lock time, clipboard clear time, and change master password.

- [ ] **Step 5: Implement change master password**

Verify current master password, decrypt current vault, re-encrypt with the new master password, and write the encrypted vault file back.

- [ ] **Step 6: Implement sync service skeleton**

Implement WebDAV settings storage and HTTP methods for `PROPFIND`, download, and upload with clear error results. Keep automatic sync conservative; manual sync can call the service.

- [ ] **Step 7: Run tests and analyzer**

Run:

```powershell
flutter test
flutter analyze
```

Expected: all tests pass and analyzer has no errors.

- [ ] **Step 8: Commit feature screens**

Run:

```powershell
git add lib test
git commit -m "feat: add vault dialogs and settings"
```

## Task 7: Final Verification

**Files:**
- Modify as needed based on verification.

- [ ] **Step 1: Run full tests**

Run:

```powershell
flutter test
```

Expected: all tests pass.

- [ ] **Step 2: Run analyzer**

Run:

```powershell
flutter analyze
```

Expected: no errors.

- [ ] **Step 3: Build Windows desktop app**

Run on Windows:

```powershell
flutter build windows
```

Expected: build exits successfully and creates `build/windows/x64/runner/Release/passstore.exe`.

- [ ] **Step 4: Commit verification fixes if any**

If files changed during verification:

```powershell
git add lib test pubspec.yaml
git commit -m "fix: address desktop verification issues"
```

Expected: commit is created only when verification fixes changed files.

## Self-Review

- Spec coverage: The plan covers desktop-only scope, default categories, custom categories, recycle bin, local encryption, unlock/create flow, change master password, WebDAV settings, entry-level merge, and simplified main UI.
- Deferred detail: Full production-grade automatic WebDAV sync scheduling is limited to a conservative service skeleton in the MVP; the first usable version should still support settings and manual sync hooks.
- Placeholder scan: The plan avoids TBD/TODO wording and gives concrete files, commands, and expected results.
- Type consistency: Model/service names are consistent across tasks.
