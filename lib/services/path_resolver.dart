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
Future<ResolvedPaths?> resolveDbFolder(Store store) async {
  // Step 1: get the OS-specific path to the `db/` directory for this store.
  final String? rawDbPath = _getDbPath(store);
  if (rawDbPath == null) {
    // This store isn't supported on the current OS (e.g. Game Pass on macOS).
    return null;
  }

  // Step 2: expand the leading '~' to the real home directory path.
  final String dbPath = _expandHome(rawDbPath);

  // Step 3: confirm the db/ directory exists.
  final Directory dbDir = Directory(dbPath);
  if (!await dbDir.exists()) {
    return null;
  }

  // Step 4: scan db/ for version sub-folders (any sub-directory whose name
  // is all digits, e.g. "2600", "2610", "2500").
  final List<String> versionFolders = await _findVersionFolders(dbDir);

  if (versionFolders.isEmpty) {
    // The db/ directory exists but has no recognised version folders.
    return null;
  }

  return ResolvedPaths(
    dbFolderPath: dbPath,
    versionFolders: versionFolders,
  );
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

/// Returns the path to the `db/` directory (the parent of version folders)
/// for the given store on the current OS.
///
/// Returns null if the combination is not supported.
String? _getDbPath(Store store) {
  if (Platform.isMacOS) return _macDbPath(store);
  if (Platform.isWindows) return _windowsDbPath(store);
  if (Platform.isLinux) return _linuxDbPath(store);
  return null;
}

/// macOS db/ paths.
///
/// On macOS, `fm.app` and `game_plugin.bundle` are "app bundles" — they look
/// like single files in Finder but are really folders. We navigate inside them
/// programmatically just like any other directory.
///
/// We use "Football Manager 26" (with a space before 26) as that is the
/// folder name Steam creates on macOS. Adjust if this changes with future
/// FM releases or patches.
String? _macDbPath(Store store) {
  // The sub-path inside the app bundle that leads to db/
  const String inner =
      'fm.app/Contents/PlugIns/game_plugin.bundle/Contents/Resources/shared/data/database/db';

  switch (store) {
    case Store.steam:
      return p.join(
        '~/Library/Application Support/Steam/steamapps/common/Football Manager 26',
        inner,
      );
    case Store.epicGames:
      return p.join(
        '~/Library/Application Support/Epic/FootballManager2026',
        inner,
      );
    case Store.gamePass:
      return null; // Game Pass is Windows-only.
  }
}

/// Windows db/ paths.
///
/// We default to `Program Files (x86)` which is the standard Steam/Epic
/// install location on 64-bit Windows. The manual override in the UI handles
/// non-standard drive letters or install locations.
String? _windowsDbPath(Store store) {
  const String inner = r'shared\data\database\db';

  switch (store) {
    case Store.steam:
      return p.join(
        r'C:\Program Files (x86)\Steam\steamapps\common\Football Manager 2026',
        inner,
      );
    case Store.epicGames:
      return p.join(
        r'C:\Program Files (x86)\Epic Games\FootballManager26',
        inner,
      );
    case Store.gamePass:
      return p.join(
        r'C:\XboxGames\Football Manager 26',
        inner,
      );
  }
}

/// Linux db/ paths.
String? _linuxDbPath(Store store) {
  switch (store) {
    case Store.steam:
      return p.join(
        '~/.local/share/Steam/steamapps/common/Football Manager 2026',
        'shared/data/database/db',
      );
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
