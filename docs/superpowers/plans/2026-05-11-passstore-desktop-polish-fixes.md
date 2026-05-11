# PassStore Desktop Polish Fixes Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Apply the latest desktop usability fixes so PassStore looks closer to the blue/white Figma direction, opens like a normal desktop utility, and avoids misleading or duplicate UI states.

**Architecture:** Keep the current Flutter structure. Add widget tests for observable UI behavior, then make scoped changes in screen widgets, app shell state, and native desktop window setup.

**Tech Stack:** Flutter Desktop, Dart, `flutter_test`, Windows runner C++, macOS runner Swift.

---

## File Structure

- Modify: `docs/superpowers/specs/2026-05-11-passstore-desktop-design.md` - record the approved product refinements.
- Modify: `test/widget_test.dart` - add regression tests for UI behavior.
- Modify: `lib/main.dart` - update app theme, system font fallbacks, and surface styling.
- Modify: `lib/features/app_shell.dart` - derive sync status from WebDAV settings.
- Modify: `lib/features/screens/create_vault_screen.dart` - blue/white first-run screen and stable error area.
- Modify: `lib/features/screens/unlock_screen.dart` - blue/white unlock screen and stable error area.
- Modify: `lib/features/screens/main_vault_screen.dart` - remove duplicate new-entry button and update status badge colors.
- Modify: `lib/features/screens/edit_entry_dialog.dart` - show password as plain text by default and reduce dialog width.
- Modify: `windows/runner/main.cpp` - center the Windows window and use balanced dimensions.
- Modify: `macos/Runner/MainFlutterWindow.swift` - center the macOS window on launch.

## Task 1: Widget Regression Tests

- [ ] Add tests to `test/widget_test.dart` that prove:
  - unlock error text appears without moving the unlock button;
  - create-vault validation error appears without moving the create button;
  - the main screen has only one `新建条目` button;
  - unconfigured WebDAV shows `未配置同步`;
  - the edit-entry password field is not obscured by default.

- [ ] Run:

```powershell
$env:Path = (Resolve-Path .tools/flutter/bin).Path + ';' + $env:Path
flutter test test/widget_test.dart
```

Expected: the new tests fail against the current implementation for the duplicate button, hardcoded sync status, shifting errors, and obscured password.

## Task 2: Flutter UI and Behavior Fixes

- [ ] Update `lib/main.dart` to use blue/white theme colors and platform font fallbacks.
- [ ] Update `lib/features/app_shell.dart` to pass `未配置同步` when `webDavSettings.isConfigured` is false.
- [ ] Update `lib/features/screens/create_vault_screen.dart` and `lib/features/screens/unlock_screen.dart` so error text lives in a reserved-height area.
- [ ] Update `lib/features/screens/main_vault_screen.dart` so only the sidebar `新建条目` action remains.
- [ ] Update `lib/features/screens/edit_entry_dialog.dart` so password text is visible by default.
- [ ] Run `flutter test test/widget_test.dart`.

Expected: all widget tests pass.

## Task 3: Native Window Startup

- [ ] Update `windows/runner/main.cpp` to use a balanced window size and calculate centered origin from the primary screen.
- [ ] Update `macos/Runner/MainFlutterWindow.swift` to call `center()` after restoring the frame.
- [ ] Run `flutter analyze`.

Expected: analyzer reports no issues.

## Task 4: Full Verification and Commit

- [ ] Run:

```powershell
$env:Path = (Resolve-Path .tools/flutter/bin).Path + ';' + $env:Path
flutter test
flutter analyze
flutter build windows
```

Expected: tests pass, analyzer has no issues, and Windows release build succeeds.

- [ ] Commit the docs, tests, UI, and runner changes with:

```powershell
git add docs test lib windows macos
git commit -m "fix: polish desktop vault UI"
```

## Self-Review

- Spec coverage: The plan covers every latest user request: blue style, stable error layout, system fonts, centered startup, accurate sync status, single new-entry action, plain password entry field, and better window proportions.
- Placeholder scan: No TBD, TODO, or deferred requirements remain.
- Type consistency: All referenced widgets and settings fields already exist in the current Flutter codebase.
