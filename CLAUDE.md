# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

---

## Development Commands

```bash
# Run the app (on the current platform)
flutter run -d macos      # or -d windows / -d linux

# Build a release binary
flutter build macos       # or windows / linux

# Run tests
flutter test

# Run a single test file
flutter test test/widget_test.dart

# Add a package
flutter pub add <package_name>

# Get/update dependencies
flutter pub get

# Analyze code
flutter analyze
```

---

## Current State

v1 implementation is complete and builds cleanly (`flutter build macos --debug`). All packages are installed. The full wizard flow is implemented across these files:

```
lib/
  main.dart                     — app root, WizardRoot step controller
  models/app_state.dart         — shared wizard state (zip path, store, version folders)
  services/path_resolver.dart   — OS+store → db/ path, dynamic version folder scanning
  services/file_operations.dart — delete old folders, extract zip, copy replacements
  widgets/step_header.dart      — shared StepHeader widget used by all screens
  screens/
    welcome_screen.dart         — step 0: intro + what you'll need
    zip_picker_screen.dart      — step 1: select zip file
    store_picker_screen.dart    — step 2: Steam / Epic / Game Pass
    folder_confirm_screen.dart  — step 3: auto-detect FM folder, version checkboxes
    preflight_screen.dart       — step 4: review what will be deleted/copied
    apply_screen.dart           — runs fix, live progress log
    result_screen.dart          — success or error + Start Over
```

---

## Architecture Plan

The app will be structured as a linear multi-step wizard. Each step is a separate screen/widget. State (selected zip path, selected store, detected FM folder path) flows forward through the steps — a simple top-level `StatefulWidget` holding shared state, or a dedicated state object passed down, is sufficient for v1 without a state management package.

Key separation of concerns:
- **UI screens** — one widget per wizard step (welcome, zip picker, store picker, folder confirm, pre-flight, progress, result).
- **Path resolution logic** — a pure Dart function/class that takes `(Platform, Store)` and returns the expected FM26 database path. Isolated so it can be tested without UI.
- **File operations** — a service class wrapping `dart:io` delete/copy and the `archive` zip extraction. All destructive calls wrapped in `try/catch`.

---

# FM26 Real Name Fix App

## Project Overview
A Flutter desktop app that automates the installation of the Football Manager 2026 Real Name Fix. The fix replaces fake/placeholder names (teams, competitions, awards, stadiums) with real licensed names.

The fix is sourced from Sortitoutsi: https://sortitoutsi.net

The app does NOT distribute the fix files. Instead, the user downloads the zip themselves from Sortitoutsi, then points the app at it. The app handles all the file operations automatically.

---

## Target Platforms
- macOS
- Windows
- Linux

Build separately on each platform. Use `Platform.isMacOS`, `Platform.isWindows`, `Platform.isLinux` to detect OS at runtime.

---

## What the Fix Actually Does

### Step 1 — Delete old folders
Navigate to the FM26 database folder (path varies by OS and store, see below) and delete these three folders:
- `dbc`
- `edt`
- `Inc`

Leave any `*_fm` folder intact (e.g. `2600_fm`, `2610_fm`, `2500_fm`) — do NOT delete it.

### Step 2 — Copy new folders
Extract the downloaded zip and copy the replacement `dbc`, `edt`, and `Inc` folders into the same database folder.

### Step 3 — Done
User must restart FM26 for changes to take effect. Fix must be applied before starting a new save game.

---

## FM26 Database Folder Paths (by OS and store)

### macOS
**Steam:**
`~/Library/Application Support/Steam/steamapps/common/Football Manager 26/fm.app/Contents/PlugIns/game_plugin.bundle/Contents/Resources/shared/data/database/db/2600`

Note: On Mac, `fm.app` and `game_plugin.bundle` are app bundles. The app must navigate inside them programmatically — no need for the user to manually "Show Package Contents".

**Epic Games:**
`~/Library/Application Support/Epic/FootballManager2026/fm.app/Contents/PlugIns/game_plugin.bundle/Contents/Resources/shared/data/database/db/2600`

### Windows
**Steam:**
`C:\Program Files (x86)\Steam\steamapps\common\Football Manager 2026\shared\data\database\db\2600`

(Note: May also be `Program Files` without `(x86)` depending on system setup)

**Epic Games:**
`C:\Program Files (x86)\Epic Games\FootballManager26\shared\data\database\db\2600`

**Game Pass / Xbox:**
`C:\XboxGames\Football Manager 26\shared\data\database\db\2600`

### Linux
**Steam (native):**
`~/.local/share/Steam/steamapps/common/Football Manager 2026/shared/data/database/db/2600`

**Steam Deck (Proton):**
`~/.local/share/Steam/steamapps/compatdata/2252570/pfx/drive_c/users/steamuser/My Documents/Sports Interactive/Football Manager 2026/editor data`

---

## Important Notes
- The patch version folder may be `2600`, `2610`, `2620` etc. depending on which FM26 patch is installed. The app should detect which version folder exists.
- The fix must be re-applied after each official FM26 patch/update, as Steam re-installs the original files during updates.
- **New saves** get the full fix — all club names, competition names, awards, and stadiums corrected.
- **Existing saves** get a partial fix — competition names, award names, and stadium names update, but club names do not. Brazilian club names in particular require a new save due to how `dbc` files work.

---

## App UI Flow

1. **Welcome screen** — brief explanation of what the app does and what the user needs to have ready (downloaded zip from Sortitoutsi).
2. **Select zip file** — file picker filtered to `.zip` files.
3. **Select store** — dropdown: Steam / Epic Games / Game Pass (Xbox).
4. **Auto-detect FM26 folder** — app tries to find the correct path based on OS + store selection. If found, show the path and allow the user to confirm or override. If not found, show a folder picker.
5. **Pre-flight check** — show a summary of exactly what will be deleted and what will be copied. Require user confirmation before proceeding.
6. **Apply fix** — delete `dbc`, `edt`, `Inc` from target folder, extract and copy replacements from zip.
7. **Result screen** — success confirmation or error message with details.

---

## Code Style & Annotations

The developer is a beginner with Flutter and Dart and wants to learn from the code. All code must be thoroughly annotated:

- Every file should have a top-level comment explaining what it does and why it exists.
- Every class should have a comment explaining its purpose and role in the app.
- Every method/function should have a comment explaining what it does, what its parameters mean, and what it returns.
- Non-obvious logic (file path construction, zip extraction, OS detection, etc.) should have inline comments explaining the reasoning step by step.
- Where a Flutter or Dart concept is used that a beginner might not know (e.g. `async/await`, `FutureBuilder`, `StatefulWidget`, `BuildContext`), add a brief plain-English explanation in a comment.
- Prefer clarity over cleverness — if there's a more explicit way to write something that's easier to follow, use that.

---

## Flutter / Dart Notes
- Use `dart:io` for all file operations (delete, copy, directory listing).
- Use `path_provider` package to help locate common directories.
- Use `file_picker` package for the zip file picker and folder override picker.
- Use `archive` package to extract the zip file in-memory without requiring a temp folder.
- Wrap all destructive operations (delete) in try/catch with clear error messages.
- Before deleting, consider making a backup of the original folders (optional stretch goal).

---

## Roadmap

### v1 (current)
- Zip-based installer as described above.

### v2 (future)
- App generates the fix files itself using a built-in fake→real name mapping database.
- Mapping database hosted as a JSON file on GitHub, auto-updated by the app.
- No zip download required — fully self-contained.
