// path_resolver.dart
//
// This file contains the logic for figuring out where FM is installed
// on the current machine, based on the operating system and the game store.
//
// Each store installs FM to a different folder. Within that folder, the
// database lives several directories deep inside a `db/` directory.
// Inside `db/` are numbered sub-folders — one per game version/patch —
// such as `2600` (FM26 base), `2610` (FM26 patch 1), `2500` (FM25), etc.
//
// Rather than hardcoding a list of known version numbers, this file scans
// the `db/` directory dynamically. This means:
//   - New FM26 patches are picked up automatically without any code changes.
//   - FM saves imported from previous FM versions (FM25, FM24 …) are also found.
//
// This logic is kept in a plain Dart file with no Flutter dependencies
// so it can be unit-tested without a running app.

import 'dart:io';
import 'package:path/path.dart' as p;

import '../models/app_state.dart';

// ---------------------------------------------------------------------------
// Public entry point
// ---------------------------------------------------------------------------

/// Tries to find the FM database `db/` folder for the given [store] on the
/// current operating system, then scans it for version sub-folders.
///
/// Returns a [ResolvedPaths] object containing:
///   - [ResolvedPaths.dbFolderPath]: the path to the `db/` directory itself.
///   - [ResolvedPaths.versionFolders]: all version sub-folders found inside it
///     (e.g. `["/path/db/2500", "/path/db/2600", "/path/db/2610"]`),
///     sorted highest-first so the most recent version appears at the top.
///
/// Returns null if the expected install location doesn't exist on this machine
/// (meaning FM is not installed, or is installed somewhere non-standard).
///
/// Multiple candidate paths are tried because Steam/Epic use slightly different
/// folder names across OS versions and FM releases (e.g. "Football Manager 26"
/// vs "Football Manager 2026", "fm.app" vs "fm26.app").
Future<ResolvedPaths?> resolveDbFolder(Store store) async {
  // Step 1: get the list of candidate db/ paths for this OS + store.
  // We try each one in order and use the first that actually exists.
  final List<String>? candidates = _getDbPathCandidates(store);
  if (candidates == null || candidates.isEmpty) {
    // This store isn't supported on the current OS (e.g. Game Pass on macOS).
    return null;
  }

  for (final rawPath in candidates) {
    // Step 2: expand the leading '~' to the real home directory path.
    final String dbPath = _expandHome(rawPath);

    // Step 3: confirm this candidate db/ directory exists.
    final Directory dbDir = Directory(dbPath);
    if (!await dbDir.exists()) {
      continue; // This candidate doesn't exist — try the next one.
    }

    // Step 4: scan db/ for version sub-folders (any sub-directory whose name
    // is all digits, e.g. "2600", "2610", "2500").
    final List<String> versionFolders = await _findVersionFolders(dbDir);

    if (versionFolders.isEmpty) {
      continue; // This db/ exists but has no version folders — try the next.
    }

    // Found a valid path with version folders — use it.
    return ResolvedPaths(
      dbFolderPath: dbPath,
      versionFolders: versionFolders,
    );
  }

  // None of the candidates matched.
  return null;
}

// ---------------------------------------------------------------------------
// Result type
// ---------------------------------------------------------------------------

/// Holds the result of a successful path resolution.
class ResolvedPaths {
  /// The full path to the `db/` directory.
  final String dbFolderPath;

  /// All version sub-folders found inside [dbFolderPath], sorted
  /// highest (most recent) first.
  final List<String> versionFolders;

  const ResolvedPaths({
    required this.dbFolderPath,
    required this.versionFolders,
  });
}

// ---------------------------------------------------------------------------
// db/ path per OS + store
// ---------------------------------------------------------------------------

/// Returns a list of candidate `db/` directory paths to try for the given
/// store on the current OS, ordered most-likely-first.
///
/// We try multiple variants because:
/// - Steam on macOS has used both "Football Manager 26" and "Football Manager 2026"
///   as the steamapps folder name across different FM releases.
/// - The main app bundle has been named "fm.app" in some installs and "fm26.app"
///   (or similar) in others.
/// - Epic store folder names also vary slightly.
///
/// Returns null if the combination is not supported on this OS at all
/// (e.g. Game Pass on macOS).
List<String>? _getDbPathCandidates(Store store) {
  if (Platform.isMacOS) return _macDbPathCandidates(store);
  if (Platform.isWindows) return _windowsDbPathCandidates(store);
  if (Platform.isLinux) return _linuxDbPathCandidates(store);
  return null;
}

/// macOS candidate db/ paths.
///
/// On macOS, `fm.app` and `game_plugin.bundle` are "app bundles" — they look
/// like single files in Finder but are really folders. Dart's `dart:io` treats
/// them as regular directories, so we can navigate inside them freely in code.
///
/// We try:
///   - "Football Manager 26"  (short form — the folder name seen in some installs)
///   - "Football Manager 2026" (full year — seen in other installs)
/// and both "fm.app" and "fm26.app" as the inner bundle name.
List<String>? _macDbPathCandidates(Store store) {
  // The inner path shared by all macOS variants, after the game root and app name.
  const String afterBundle =
      'Contents/PlugIns/game_plugin.bundle/Contents/Resources/shared/data/database/db';

  // We build every combination of game folder name × app bundle name.
  List<String> buildCandidates(String baseDir, List<String> appNames) {
    return appNames.map((app) => p.join(baseDir, app, afterBundle)).toList();
  }

  switch (store) {
    case Store.steam:
      // Steam installs under ~/Library/Application Support/Steam/steamapps/common/
      // The exact folder name for FM26 has varied; try both.
      const String steamBase =
          '~/Library/Application Support/Steam/steamapps/common';
      return [
        ...buildCandidates('$steamBase/Football Manager 26',   ['fm.app', 'fm26.app']),
        ...buildCandidates('$steamBase/Football Manager 2026', ['fm.app', 'fm26.app']),
      ];

    case Store.epicGames:
      // Epic on macOS uses a different base location.
      const String epicBase =
          '~/Library/Application Support/Epic';
      return [
        ...buildCandidates('$epicBase/FootballManager2026', ['fm.app', 'fm26.app']),
        ...buildCandidates('$epicBase/FootballManager26',   ['fm.app', 'fm26.app']),
      ];

    case Store.gamePass:
      return null; // Game Pass is Windows-only.
  }
}

/// Windows candidate db/ paths.
///
/// We default to `Program Files (x86)` (the standard Steam/Epic location on
/// 64-bit Windows) but also try `Program Files` without `(x86)` for users on
/// systems where Steam chose the non-x86 directory.
List<String>? _windowsDbPathCandidates(Store store) {
  const String inner = r'shared\data\database\db';

  switch (store) {
    case Store.steam:
      return [
        p.join(r'C:\Program Files (x86)\Steam\steamapps\common\Football Manager 2026', inner),
        p.join(r'C:\Program Files\Steam\steamapps\common\Football Manager 2026', inner),
        p.join(r'C:\Program Files (x86)\Steam\steamapps\common\Football Manager 26', inner),
        p.join(r'C:\Program Files\Steam\steamapps\common\Football Manager 26', inner),
      ];
    case Store.epicGames:
      return [
        p.join(r'C:\Program Files (x86)\Epic Games\FootballManager2026', inner),
        p.join(r'C:\Program Files\Epic Games\FootballManager2026', inner),
        p.join(r'C:\Program Files (x86)\Epic Games\FootballManager26', inner),
        p.join(r'C:\Program Files\Epic Games\FootballManager26', inner),
      ];
    case Store.gamePass:
      return [
        p.join(r'C:\XboxGames\Football Manager 26', inner),
        p.join(r'C:\XboxGames\Football Manager 2026', inner),
      ];
  }
}

/// Linux candidate db/ paths.
List<String>? _linuxDbPathCandidates(Store store) {
  const String inner = 'shared/data/database/db';

  switch (store) {
    case Store.steam:
      return [
        p.join('~/.local/share/Steam/steamapps/common/Football Manager 2026', inner),
        p.join('~/.local/share/Steam/steamapps/common/Football Manager 26', inner),
      ];
    case Store.epicGames:
      // Epic on Linux is not officially supported by SI.
      return null;
    case Store.gamePass:
      return null; // Windows-only.
  }
}

// ---------------------------------------------------------------------------
// Version folder scanning
// ---------------------------------------------------------------------------

/// Scans [dbDir] for sub-directories whose names consist entirely of digits.
///
/// FM stores each version's database in a numbered folder:
///   - `2600` = FM26 base release
///   - `2610` = FM26 patch 1
///   - `2500` = FM25 (relevant when the user has imported an FM25 save)
///   - … and so on for any future patches or past FM versions
///
/// By scanning rather than using a hardcoded list we automatically handle:
///   - New patches released after this app was written
///   - Users who have multiple FM versions installed side-by-side
///   - Imported saves from previous Football Manager games
///
/// Results are sorted highest-first (most recent version at the top), which
/// matches the order presented in the UI checkbox list.
Future<List<String>> _findVersionFolders(Directory dbDir) async {
  final List<String> found = [];

  // list() returns a Stream of FileSystemEntity objects (files and directories).
  // We use await for to iterate over each one asynchronously.
  await for (final FileSystemEntity entity in dbDir.list()) {
    // We only care about directories, not files.
    if (entity is! Directory) continue;

    // Get just the folder name (the last segment of the path).
    final String name = p.basename(entity.path);

    // A version folder name is all digits (e.g. "2600", "2610").
    // RegExp('\d+') means "one or more digit characters".
    // The ^ and $ anchors mean the entire name must match, not just part of it.
    if (RegExp(r'^\d+$').hasMatch(name)) {
      found.add(entity.path);
    }
  }

  // Sort by folder name descending so the highest (newest) version is first.
  // We sort by the basename (the number itself) parsed as an integer.
  found.sort((a, b) => int.parse(p.basename(b)).compareTo(int.parse(p.basename(a))));

  return found;
}

// ---------------------------------------------------------------------------
// Editor data folder
// ---------------------------------------------------------------------------

/// Returns the standard FM26 "editor data" folder path for the current OS.
///
/// This is where .fmf files (editor data files such as the Real Name Fix
/// graphics and name files) must be placed for FM to load them at startup.
///
/// Unlike the database db/ path, this path is the same regardless of which
/// store FM was purchased from — it always lives in the user's personal
/// data area (Documents on Windows, Application Support on macOS/Linux).
///
/// Note: this function returns the expected path whether or not the folder
/// currently exists. The installer will create it if needed.
///
/// Returns null if the home directory cannot be determined.
String? resolveEditorDataFolder() {
  if (Platform.isMacOS) {
    // macOS stores per-user FM data inside ~/Library/Application Support/,
    // not inside the game bundle. This folder is the same for Steam and Epic.
    return _expandHome(
      '~/Library/Application Support/Sports Interactive/Football Manager 26/editor data',
    );
  }

  if (Platform.isWindows) {
    // Windows: %USERPROFILE%\Documents\Sports Interactive\Football Manager 26\editor data
    // USERPROFILE is the standard Windows variable for the current user's home folder
    // (e.g. C:\Users\Phil). We fall back to HOME for unusual setups.
    final String? home =
        Platform.environment['USERPROFILE'] ?? Platform.environment['HOME'];
    if (home == null) return null;
    return p.join(
      home, 'Documents', 'Sports Interactive', 'Football Manager 26', 'editor data',
    );
  }

  if (Platform.isLinux) {
    // Linux follows the XDG convention; FM typically uses ~/Documents.
    return _expandHome(
      '~/Documents/Sports Interactive/Football Manager 26/editor data',
    );
  }

  return null;
}

// ---------------------------------------------------------------------------
// Home directory expansion
// ---------------------------------------------------------------------------

/// Replaces a leading `~` with the user's actual home directory path.
///
/// Dart doesn't expand `~` automatically the way a shell does, so we do it
/// manually. On macOS/Linux the home directory is in the HOME environment
/// variable; on Windows it's in USERPROFILE.
String _expandHome(String path) {
  if (!path.startsWith('~')) return path;

  final String? home =
      Platform.environment['HOME'] ?? Platform.environment['USERPROFILE'];

  if (home == null) return path; // Can't determine home — return unchanged.

  // Replace '~/' with the real home path.
  // path.substring(2) skips the '~' and the following separator character.
  return p.join(home, path.substring(2));
}
