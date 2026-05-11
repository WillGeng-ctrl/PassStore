# PassStore Desktop Design

Date: 2026-05-11

## Purpose

PassStore is a simple personal password storage app for the owner of this repository. The first version targets Windows and macOS desktop only. The app should be easy to understand, quick to use, and safe by default.

The core product promise is:

- Store passwords locally in an encrypted vault.
- Sync the encrypted vault through a free cloud storage option that works well in mainland China.
- Keep the cloud provider unable to read password data.
- Avoid complex account, tag, favorite, dashboard, or team-sharing features.

## First Version Scope

The first version includes:

- Create a new encrypted password vault.
- Unlock an existing vault with a master password.
- Add, edit, delete, and restore password entries.
- Search password entries.
- Assign each entry to one category.
- Provide default categories: `网站`, `应用`, `游戏`, `其他`.
- Allow users to add, rename, and delete custom categories.
- Provide a recycle bin for deleted entries.
- Copy account, password, and URL fields.
- Hide passwords by default, with an explicit show action.
- In the add/edit entry dialog, show the password field as plain text by default for lower-friction personal use.
- Clear copied passwords from the clipboard after a configurable delay.
- Auto-lock the vault after an idle timeout.
- Sync the encrypted vault through Jianguoyun WebDAV.
- Merge sync changes at entry level by default.
- Export and import encrypted local backups.

The first version excludes:

- Mobile apps.
- Browser extensions.
- Password autofill.
- Tags.
- Favorites.
- Recently used lists.
- Multi-category entries.
- Multi-user sharing.
- Cloud accounts owned by PassStore.
- Complex filtering, analytics, or management dashboards.

## Platform Strategy

The app will be built with Flutter Desktop for Windows and macOS. Flutter is chosen because it can later share most core logic with iOS and Android versions, while still allowing the desktop UI to follow desktop habits.

The implementation should separate reusable core logic from desktop-specific shell code:

- `VaultCore`: password entry and category behavior.
- `CryptoService`: master password handling, key derivation, encryption, decryption, and integrity checks.
- `LocalStore`: encrypted vault file, app settings, and sync metadata.
- `WebDavSyncService`: Jianguoyun WebDAV upload, download, remote metadata, and conflict merge coordination.
- `DesktopShell`: Windows and macOS window, menu, shortcut, tray/menu-bar integration, and platform storage.
- `DesktopUI`: simple desktop-facing screens and interactions.

Future mobile versions should add mobile shell and UI layers while reusing vault, crypto, local storage, and sync logic.

## Data Model

Each password entry includes:

- Stable `entryId`.
- Title.
- Account or username.
- Password.
- URL.
- Notes.
- Category ID.
- Created timestamp.
- Updated timestamp.
- Deleted timestamp, when in recycle bin.
- Entry revision.
- Last modified device ID.
- Field-level modified timestamps for conflict merging.

Each category includes:

- Stable `categoryId`.
- Name.
- Sort order.
- Whether it is a built-in category.
- Created timestamp.
- Updated timestamp.

Built-in categories are:

- `网站`
- `应用`
- `游戏`
- `其他`

Each entry belongs to exactly one category. When a custom category is deleted, entries in that category move to `其他`.

## Vault File

Local disk and cloud storage both store an encrypted vault file, for example:

`passstore.vault`

The file contains non-sensitive envelope metadata outside the encrypted payload:

- Format version.
- Encryption algorithm.
- Key derivation parameters.
- Salt.
- Nonce.
- Vault ID.
- Vault revision.
- Created timestamp.
- Updated timestamp.
- Last modified device ID.

The encrypted payload contains:

- Password entries.
- Categories.
- Recycle bin data.
- Sync merge metadata.
- App preferences that are safe to keep inside the vault.

## Security Design

The master password is never stored. If the user forgets the master password, the vault cannot be recovered.

The master password is used locally to derive a vault encryption key through a strong password-based key derivation function such as Argon2id, or a mature Flutter/Dart-compatible alternative if Argon2id support is not stable enough on desktop.

The vault payload is encrypted with authenticated encryption such as XChaCha20-Poly1305 or AES-256-GCM, depending on library maturity and desktop compatibility.

Cloud storage only receives encrypted vault data. Jianguoyun never receives plaintext passwords or the master password.

WebDAV credentials are not stored in the vault. They should be stored in platform secure storage:

- Windows Credential Manager on Windows.
- Keychain on macOS.

## Sync Design

Sync uses Jianguoyun WebDAV as a simple encrypted file transport.

The app uploads and downloads the whole encrypted vault file, but merge behavior is entry-based after decryption. Remote metadata such as `etag` and `lastModified` is used to detect whether the cloud file changed, but actual merge decisions use entry IDs, revisions, device IDs, and field-level modified timestamps.

Common merge behavior:

- Local-only new entry: keep it and upload merged vault.
- Remote-only new entry: keep it locally.
- Different entries changed on both devices: merge automatically.
- One side deleted an entry and the other side did not modify it: move it to recycle bin.
- One side deleted an entry while the other side modified it: preserve both states and ask the user.
- Same entry changed on both devices in different fields: merge automatically.
- Same entry changed on both devices in the same field: ask the user which value to keep.

The app should avoid silent data loss. Conflicted field values should remain available until the user resolves them.

## Desktop Interaction Principles

The exact interface design will be handled separately in Figma, but the product interaction should remain simple:

- The app opens to unlock or to the main vault view.
- Search should be prominent and fast.
- Category navigation should be a simple tree in the left sidebar.
- Entry editing should be direct and low friction.
- The main vault screen should have only one primary `新建条目` action to avoid duplicate choices.
- Copying account, password, and URL should be one-click.
- Unlock and first-run screens should follow the blue/white desktop style from the Figma reference, not a green-tinted style.
- The app should use platform/system font fallbacks so Chinese text is clear on Windows and macOS.
- Error messages should explain what the user can do next without moving buttons or changing the overall form layout.
- Sync status should be visible but quiet. If WebDAV credentials are not configured, it must show an unconfigured state instead of `已同步`.
- Desktop windows should open centered and use balanced dimensions close to a normal desktop app ratio instead of looking stretched or oddly placed.

The app should not feel like an admin console. It should feel like a small personal utility.

## Error Handling

Expected error cases:

- Wrong master password.
- Corrupted or incompatible vault file.
- WebDAV login failure.
- WebDAV network timeout.
- Remote vault missing.
- Local and remote vault both changed.
- Field-level sync conflict.
- Clipboard clear failure.

The app should preserve local data when sync fails. Sync errors should not block local password access after successful unlock.

## Testing Focus

Security and sync behavior carry the most risk, so tests should focus on:

- Vault encryption and decryption round trips.
- Wrong password failure.
- Corrupted payload failure.
- Entry create, edit, delete, restore behavior.
- Category create, rename, delete behavior.
- Moving entries to `其他` when a custom category is deleted.
- Entry-level merge cases.
- Field-level conflict cases.
- WebDAV metadata handling with a mock sync backend.
- Clipboard clear timing where practical.

## Figma Design Brief

The Figma design should cover the desktop version only.

Required screens:

- First-run create vault screen.
- Unlock screen.
- Main password list and detail screen.
- Add or edit password entry flow.
- Category management flow.
- Recycle bin view.
- Jianguoyun WebDAV settings screen.
- Sync conflict resolution screen.

Design constraints:

- Keep the product easy to use.
- Use only the categories `网站`, `应用`, `游戏`, `其他` as defaults.
- Do not introduce tags, favorites, recent lists, dashboards, or complex filters.
- Prefer a calm desktop utility style.
- Ensure Windows and macOS interactions can both feel natural.
