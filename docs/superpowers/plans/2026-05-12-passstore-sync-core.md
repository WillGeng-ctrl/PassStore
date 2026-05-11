# PassStore Sync Core Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the first real WebDAV sync loop: download remote vault, decrypt, merge, upload, track status, and prevent old-master-password clients from overwriting a remote vault encrypted with a new master password.

**Architecture:** Keep sync rules in data/core services, not widgets. `WebDavSyncService` handles remote file transport, `SyncMetadataStore` persists the last successful sync baseline, and `VaultSyncCoordinator` owns the safe sync algorithm. The app shell only displays status and asks for a new remote master password when the coordinator says it is required.

**Tech Stack:** Flutter Desktop, Dart, `http`, existing `VaultCrypto`, existing `VaultMerge`, existing local JSON file persistence.

---

### File Structure

- Modify: `lib/data/webdav_sync_service.dart` - treat WebDAV setting as a directory, read/write `PassStore/passstore.vault`, create `PassStore` remote directory, expose nullable remote download.
- Create: `lib/data/sync_metadata_store.dart` - persist encrypted baseline payload and sync metadata in local app data.
- Create: `lib/data/vault_sync_coordinator.dart` - pure sync workflow and status/result types.
- Modify: `lib/main.dart` - load/save sync metadata, run manual sync, mark local changes as unsynced, schedule delayed sync, handle master password change.
- Modify: `lib/features/app_shell.dart` - pass sync status to UI and request new remote master password when needed.
- Modify: `lib/features/screens/main_vault_screen.dart` - make sync badge clickable and able to display real status.
- Test: `test/data/webdav_sync_service_test.dart` - remote path and missing-file behavior.
- Test: `test/data/sync_metadata_store_test.dart` - metadata persistence.
- Test: `test/data/vault_sync_coordinator_test.dart` - safe merge/upload algorithm, including changed master password.
- Test: `test/features/sync_ui_test.dart` - sync button/status behavior without touching the existing dirty `test/widget_test.dart`.

### Task 1: WebDAV Remote Vault File

**Files:**
- Modify: `lib/data/webdav_sync_service.dart`
- Modify: `test/data/webdav_sync_service_test.dart`

- [ ] **Step 1: Write failing WebDAV remote file tests**

Add tests that verify:

```dart
test('downloads the fixed PassStore vault file from the configured WebDAV directory', () async {
  late http.Request captured;
  final service = WebDavSyncService(
    client: MockClient((request) async {
      captured = request;
      return http.Response('{"version":1}', 200, headers: {'etag': 'abc'});
    }),
  );

  final file = await service.downloadVaultFile(
    url: 'https://dav.jianguoyun.com/dav/',
    account: 'user@example.com',
    appPassword: 'app-password',
  );

  expect(file?.body, '{"version":1}');
  expect(file?.etag, 'abc');
  expect(captured.method, 'GET');
  expect(captured.url.toString(), 'https://dav.jianguoyun.com/dav/PassStore/passstore.vault');
});

test('returns null when the remote vault file does not exist', () async {
  final service = WebDavSyncService(
    client: MockClient((_) async => http.Response('', 404)),
  );

  final file = await service.downloadVaultFile(
    url: 'https://dav.jianguoyun.com/dav/',
    account: 'user@example.com',
    appPassword: 'app-password',
  );

  expect(file, isNull);
});

test('creates the PassStore directory before uploading the vault file', () async {
  final methods = <String>[];
  final urls = <String>[];
  final service = WebDavSyncService(
    client: MockClient((request) async {
      methods.add(request.method);
      urls.add(request.url.toString());
      if (request.method == 'MKCOL') return http.Response('', 201);
      return http.Response('', 201);
    }),
  );

  await service.uploadVault(
    url: 'https://dav.jianguoyun.com/dav/',
    account: 'user@example.com',
    appPassword: 'app-password',
    body: '{"version":1}',
  );

  expect(methods, ['MKCOL', 'PUT']);
  expect(urls[0], 'https://dav.jianguoyun.com/dav/PassStore/');
  expect(urls[1], 'https://dav.jianguoyun.com/dav/PassStore/passstore.vault');
});
```

- [ ] **Step 2: Run WebDAV tests and verify RED**

Run: `.\.tools\flutter\bin\flutter.bat test test\data\webdav_sync_service_test.dart`

Expected: fails because `downloadVaultFile` does not exist and upload still writes to the raw URL.

- [ ] **Step 3: Implement WebDAV remote file methods**

Add `RemoteVaultFile`, `downloadVaultFile`, `_vaultUri`, `_vaultDirectoryUri`, and directory creation before upload. Preserve `testConnection` behavior.

- [ ] **Step 4: Run WebDAV tests and verify GREEN**

Run: `.\.tools\flutter\bin\flutter.bat test test\data\webdav_sync_service_test.dart`

Expected: all WebDAV sync service tests pass.

### Task 2: Sync Metadata Store

**Files:**
- Create: `lib/data/sync_metadata_store.dart`
- Create: `test/data/sync_metadata_store_test.dart`

- [ ] **Step 1: Write failing metadata tests**

Create tests for round-tripping:

```dart
test('saves and loads encrypted sync baseline metadata', () async {
  final tempDir = await Directory.systemTemp.createTemp('passstore-sync-meta-');
  addTearDown(() => tempDir.delete(recursive: true));
  final store = SyncMetadataStore(directory: tempDir);
  const payload = EncryptedVaultPayload(
    version: 1,
    algorithm: 'AES-256-GCM',
    kdf: 'Argon2id',
    kdfParams: {'parallelism': 2, 'memory': 8192, 'iterations': 3, 'hashLength': 32},
    salt: 'salt',
    nonce: 'nonce',
    mac: 'mac',
    ciphertext: 'ciphertext',
  );
  final metadata = SyncMetadata(
    basePayload: payload,
    remoteEtag: 'etag-1',
    lastSyncedAt: DateTime.utc(2026, 5, 12, 10),
    hasUnsyncedChanges: true,
    lastError: 'network',
  );

  await store.save(metadata);
  final loaded = await store.load();

  expect(loaded.basePayload?.ciphertext, 'ciphertext');
  expect(loaded.remoteEtag, 'etag-1');
  expect(loaded.hasUnsyncedChanges, isTrue);
  expect(loaded.lastError, 'network');
});
```

- [ ] **Step 2: Run metadata tests and verify RED**

Run: `.\.tools\flutter\bin\flutter.bat test test\data\sync_metadata_store_test.dart`

Expected: fails because the store does not exist.

- [ ] **Step 3: Implement metadata model and store**

Implement `SyncMetadata`, `SyncMetadataStore.load`, and `SyncMetadataStore.save`. Store only encrypted `EncryptedVaultPayload`, never plaintext vault JSON.

- [ ] **Step 4: Run metadata tests and verify GREEN**

Run: `.\.tools\flutter\bin\flutter.bat test test\data\sync_metadata_store_test.dart`

Expected: metadata tests pass.

### Task 3: Vault Sync Coordinator

**Files:**
- Create: `lib/data/vault_sync_coordinator.dart`
- Create: `test/data/vault_sync_coordinator_test.dart`

- [ ] **Step 1: Write failing coordinator tests**

Cover these behaviors with a fake remote store that records upload bodies and a real `VaultCrypto`:

- `uploads local vault when remote vault is missing`: fake remote returns `null`; coordinator returns `VaultSyncStatus.synced`; fake remote records exactly one upload; decrypted upload equals the local vault.
- `merges remote and local changes before uploading`: fake remote returns a remote encrypted payload; metadata contains a base encrypted payload; local and remote each add a different entry; coordinator uploads a vault containing both entries.
- `does not upload when remote vault needs a different master password`: fake remote returns a payload encrypted with `new-password`; coordinator is called with `masterPassword: old-password`; coordinator returns `VaultSyncStatus.needsNewMasterPassword`; fake remote records no upload.
- `accepts the new remote master password and uploads merged vault with it`: same setup as the previous case, but coordinator is called with `remoteMasterPassword: new-password`; coordinator returns `VaultSyncStatus.synced`; uploaded payload decrypts with `new-password`; uploaded payload does not decrypt with `old-password`.

- [ ] **Step 2: Run coordinator tests and verify RED**

Run: `.\.tools\flutter\bin\flutter.bat test test\data\vault_sync_coordinator_test.dart`

Expected: fails because the coordinator does not exist.

- [ ] **Step 3: Implement coordinator**

Implement:

- `enum VaultSyncStatus`
- `class VaultSyncResult`
- `abstract class VaultRemoteStore`
- `class VaultSyncCoordinator`

The coordinator must never call upload if remote decrypt fails and no `remoteMasterPassword` was supplied.

- [ ] **Step 4: Run coordinator tests and verify GREEN**

Run: `.\.tools\flutter\bin\flutter.bat test test\data\vault_sync_coordinator_test.dart`

Expected: coordinator tests pass.

### Task 4: App Integration and Sync UI

**Files:**
- Modify: `lib/main.dart`
- Modify: `lib/features/app_shell.dart`
- Modify: `lib/features/screens/main_vault_screen.dart`
- Create: `test/features/sync_ui_test.dart`

- [ ] **Step 1: Write failing UI/status tests**

Add widget tests that verify:

- `configured sync starts as not synced until a real sync succeeds`: build `AppShell` with configured WebDAV credentials and `VaultSyncStatus.notSynced`; expect `未同步`; expect `已同步` is absent.
- `sync badge invokes the sync callback`: build `MainVaultScreen` with `syncStatus: '未同步'` and a callback that increments a counter; tap the sync badge; expect the counter is `1`.

- [ ] **Step 2: Run UI/status tests and verify RED**

Run: `.\.tools\flutter\bin\flutter.bat test test\features\sync_ui_test.dart`

Expected: fails because the sync callback/status plumbing does not exist.

- [ ] **Step 3: Wire sync status and manual sync**

Pass a real sync status label from `PassStoreApp` to `AppShell` to `MainVaultScreen`. Make the top sync badge clickable. If status is `unconfigured`, clicking should open settings. Otherwise it should invoke sync.

- [ ] **Step 4: Mark local changes unsynced and schedule sync**

After vault changes, save locally immediately, mark metadata as unsynced, update status to `未同步`, and schedule a 3 second delayed sync when WebDAV is configured.

- [ ] **Step 5: Handle changed remote master password**

When manual sync returns `needsNewMasterPassword`, show a password dialog and retry sync with the entered password. On success, update `_masterPassword` to the new value.

- [ ] **Step 6: Run UI/status tests and verify GREEN**

Run: `.\.tools\flutter\bin\flutter.bat test test\features\sync_ui_test.dart`

Expected: UI/status tests pass.

### Task 5: Full Verification

**Files:**
- All files from previous tasks.

- [ ] **Step 1: Format changed Dart files**

Run: `.\.tools\flutter\bin\dart.bat format lib test`

Expected: formatter completes.

- [ ] **Step 2: Run all tests**

Run: `.\.tools\flutter\bin\flutter.bat test`

Expected: all tests pass.

- [ ] **Step 3: Run analyzer**

Run: `.\.tools\flutter\bin\flutter.bat analyze`

Expected: no issues found.

- [ ] **Step 4: Build Windows app**

Run: `.\.tools\flutter\bin\flutter.bat build windows`

Expected: `build\windows\x64\runner\Release\PassStore.exe` is built.

- [ ] **Step 5: Commit sync implementation**

Stage only sync-related files. Do not stage the existing Logo worktree changes unless the user explicitly asks.

```powershell
git add lib\data\webdav_sync_service.dart lib\data\sync_metadata_store.dart lib\data\vault_sync_coordinator.dart lib\main.dart lib\features\app_shell.dart lib\features\screens\main_vault_screen.dart test\data\webdav_sync_service_test.dart test\data\sync_metadata_store_test.dart test\data\vault_sync_coordinator_test.dart test\features\sync_ui_test.dart
git commit -m "feat: add safe WebDAV sync"
```

---

## Self-Review

Spec coverage:

- Safe download/decrypt/merge/upload flow: Task 3.
- Changed master password behavior: Task 3 and Task 4.
- Upload timing: Task 4.
- Real sync status instead of fake `已同步`: Task 4.
- Remote `PassStore/passstore.vault` path: Task 1.
- Metadata/baseline: Task 2.
- Error handling and no remote overwrite on decrypt failure: Task 3.

Placeholder scan: no `TBD`, no `TODO`, no unspecified "handle edge cases" steps.

Type consistency: sync status, metadata, remote file, and coordinator names are introduced before app integration uses them.
