// file_operations.dart
//
// This file handles all the destructive and potentially slow file work:
//   1. Deleting the old dbc/, edt/, and Inc/ folders from the target version folder(s).
//   2. Copying the replacement dbc/, edt/, and Inc/ folders from the fix folder
//      the user downloaded from Sortitoutsi into each target.
//
// All work is done using dart:io (the standard Dart file system library).
//
// Every destructive operation is wrapped in a try/catch so that if something
// goes wrong, we return a clear error message rather than crashing the app.

import 'dart:io';

import 'package:path/path.dart' as p;

// ---------------------------------------------------------------------------
// Constants
// ---------------------------------------------------------------------------

/// The names of the three folders the fix replaces inside each version folder.
/// These are the only folders we delete and re-copy — we never touch any
/// `*_fm` folder (e.g. `2600_fm`, `2610_fm`, `2500_fm`).
const List<String> kFixFolderNames = ['dbc', 'edt', 'Inc'];

// ---------------------------------------------------------------------------
// Public types
// ---------------------------------------------------------------------------

/// The result of running the full fix operation.
class FixResult {
  /// True if the fix was applied without errors.
  final bool success;

  /// Human-readable description of what happened (shown on the result screen).
  final String message;

  const FixResult({required this.success, required this.message});
}

/// A single line of progress text emitted during the fix operation.
/// The UI listens to a stream of these to show a live progress log.
class FixProgress {
  final String message;
  const FixProgress(this.message);
}

// ---------------------------------------------------------------------------
// Pre-flight information
// ---------------------------------------------------------------------------

/// Describes exactly what the fix will do — shown to the user for confirmation
/// before any destructive operations begin.
class PreflightInfo {
  /// The fix folder path being used (the downloaded folder from Sortitoutsi).
  final String fixFolderPath;

  /// The version folders that will be modified (the ones the user checked).
  final List<String> targetFolders;

  /// Which of the fix folders (dbc, edt, Inc) currently exist in each target
  /// and will therefore be deleted. Keyed by version folder path.
  final Map<String, List<String>> foldersToDelete;

  /// Which fix folders were found inside the source fix folder and will be copied in.
  final List<String> foldersInSource;

  /// The path to the FM26 "editor data" folder where .fmf files will be copied.
  /// Null if no editor data folder path is available (the .fmf step will be skipped).
  final String? editorDataFolderPath;

  /// Whether [editorDataFolderPath] already exists on disk.
  /// If false, the apply step will create it automatically.
  final bool editorDataFolderExists;

  /// The .fmf filenames found in the EDITOR DATA sub-folder of the fix folder.
  /// These files will be copied into [editorDataFolderPath].
  /// Empty if no EDITOR DATA folder or .fmf files were found.
  final List<String> fmfFilesToCopy;

  const PreflightInfo({
    required this.fixFolderPath,
    required this.targetFolders,
    required this.foldersToDelete,
    required this.foldersInSource,
    required this.editorDataFolderPath,
    required this.editorDataFolderExists,
    required this.fmfFilesToCopy,
  });
}

/// Builds a [PreflightInfo] by inspecting every target folder and the source
/// fix folder without making any changes to the file system.
///
/// [fixFolderPath] — path to the downloaded fix folder.
/// [targetFolders] — all version folder paths the user has selected.
///   This list may contain multiple entries (e.g. 2500, 2600, 2610) when the
///   user wants to patch several FM versions at once.
/// [editorDataFolderPath] — the path where .fmf files will be copied, or null
///   to skip that step.
///
/// Returns null if the fix folder cannot be read or contains none of the
/// expected sub-folders (dbc, edt, Inc).
Future<PreflightInfo?> buildPreflightInfo({
  required String fixFolderPath,
  required List<String> targetFolders,
  String? editorDataFolderPath,
}) async {
  // Check which fix folders currently exist in each selected version folder.
  // We report this per-folder so the pre-flight screen can show exactly what
  // will be deleted from 2500, what from 2600, and so on.
  final Map<String, List<String>> foldersToDelete = {};
  for (final String versionFolder in targetFolders) {
    final List<String> existing = [];
    for (final String folderName in kFixFolderNames) {
      final Directory d = Directory(p.join(versionFolder, folderName));
      if (await d.exists()) {
        existing.add(folderName);
      }
    }
    foldersToDelete[versionFolder] = existing;
  }

  // Inspect the fix folder to see which of the expected sub-folders it contains.
  final List<String> foldersInSource =
      await _detectFoldersInFixFolder(fixFolderPath);

  // If none of the expected folders were found, the user has pointed at the
  // wrong folder — return null to signal an error.
  if (foldersInSource.isEmpty) return null;

  // Resolve the actual root folder (accounting for a possible wrapper sub-folder)
  // so we can look for the EDITOR DATA folder at the same level as dbc/edt/Inc.
  final String sourcePrefix = await _findSourcePrefix(fixFolderPath);
  final String sourceRoot = sourcePrefix.isEmpty
      ? fixFolderPath
      : p.join(fixFolderPath, sourcePrefix);

  // Scan the EDITOR DATA sub-folder (if present) for .fmf files to copy.
  final List<String> fmfFiles = await _detectFmfFiles(sourceRoot);

  // Check whether the editor data folder already exists on disk.
  // If it doesn't, the apply step will create it automatically.
  final bool editorDataExists = editorDataFolderPath != null &&
      await Directory(editorDataFolderPath).exists();

  return PreflightInfo(
    fixFolderPath: fixFolderPath,
    targetFolders: targetFolders,
    foldersToDelete: foldersToDelete,
    foldersInSource: foldersInSource,
    editorDataFolderPath: editorDataFolderPath,
    editorDataFolderExists: editorDataExists,
    fmfFilesToCopy: fmfFiles,
  );
}

// ---------------------------------------------------------------------------
// Main fix operation
// ---------------------------------------------------------------------------

/// Applies the Real Name Fix to every folder in [targetFolders], and also
/// copies any .fmf editor data files into [editorDataFolderPath] if provided.
///
/// For each version folder (e.g. 2500, 2600, 2610 …) the steps are:
///   1. Delete the existing dbc/, edt/, Inc/ sub-folders (if present).
///   2. Copy dbc/, edt/, Inc/ from [fixFolderPath] into that version folder.
///
/// If [editorDataFolderPath] is provided and the fix folder contains an
/// EDITOR DATA sub-folder with .fmf files, those files are also copied there.
/// The editor data folder is created automatically if it does not yet exist.
///
/// [fixFolderPath] — path to the downloaded fix folder.
/// [targetFolders] — version folder paths selected by the user (may be many).
/// [onProgress] — callback called with a [FixProgress] message for each step.
///   The apply screen passes this to a live log widget.
/// [editorDataFolderPath] — optional path to the FM26 editor data folder.
///
/// Returns a [FixResult] indicating overall success or the first error.
Future<FixResult> applyFix({
  required String fixFolderPath,
  required List<String> targetFolders,
  required void Function(FixProgress) onProgress,
  String? editorDataFolderPath,
}) async {
  onProgress(const FixProgress('Checking source fix folder…'));

  // Verify the fix folder exists before we start.
  final Directory sourceDir = Directory(fixFolderPath);
  if (!await sourceDir.exists()) {
    return FixResult(
      success: false,
      message: 'The fix folder could not be found at:\n$fixFolderPath\n\n'
          'Please go back and re-select it.',
    );
  }

  // Check which fix sub-folders exist inside the source folder.
  // We need to find at least one of dbc/, edt/, or Inc/ to proceed.
  final List<String> sourceFolders =
      await _detectFoldersInFixFolder(fixFolderPath);
  if (sourceFolders.isEmpty) {
    return FixResult(
      success: false,
      message: 'The selected folder does not contain any of the expected '
          'fix sub-folders (dbc, edt, Inc).\n\n'
          'Make sure you have selected the correct Real Name Fix folder '
          'from Sortitoutsi.',
    );
  }

  // Detect whether the fix folders are directly inside fixFolderPath, or
  // wrapped in a single sub-folder (e.g. "Real Name Fix v1.0/dbc/...").
  // _findSourcePrefix returns "" if the fix folders are at the top level,
  // or the name of the wrapper sub-folder if one exists.
  final String sourcePrefix = await _findSourcePrefix(fixFolderPath);
  // The actual root folder containing dbc/, edt/, Inc/.
  final String sourceRoot = sourcePrefix.isEmpty
      ? fixFolderPath
      : p.join(fixFolderPath, sourcePrefix);

  // --- Apply to each selected version folder ---
  for (final String versionFolder in targetFolders) {
    final String versionName = p.basename(versionFolder);
    onProgress(FixProgress('── Applying to version $versionName ──'));

    // Step 1: Delete old fix folders.
    for (final String folderName in kFixFolderNames) {
      final Directory target = Directory(p.join(versionFolder, folderName));
      if (await target.exists()) {
        onProgress(FixProgress('  Deleting $folderName/…'));
        try {
          // recursive: true deletes the folder and everything inside it.
          await target.delete(recursive: true);
        } catch (e) {
          return FixResult(
            success: false,
            message:
                'Failed to delete $folderName/ inside $versionName.\n\n'
                'Details: $e\n\n'
                'Make sure Football Manager is not running.',
          );
        }
      } else {
        onProgress(FixProgress('  $folderName/ not present, skipping.'));
      }
    }

    // Step 2: Copy replacement folders from the fix folder.
    onProgress(FixProgress('  Copying replacement folders…'));
    try {
      await _copyFixFolders(
        sourceRoot: sourceRoot,
        targetFolder: versionFolder,
        onProgress: onProgress,
      );
    } catch (e) {
      return FixResult(
        success: false,
        message: 'Failed to copy files into $versionName.\n\nDetails: $e',
      );
    }

    onProgress(FixProgress('  ✓ Done with $versionName.'));
  }

  // --- Copy .fmf editor data files (if applicable) ---
  if (editorDataFolderPath != null) {
    // Look for an EDITOR DATA sub-folder at the same level as dbc/edt/Inc.
    final List<String> fmfFiles = await _detectFmfFiles(sourceRoot);

    if (fmfFiles.isNotEmpty) {
      onProgress(const FixProgress('── Copying editor data files ──'));

      // Create the editor data folder if it doesn't already exist.
      // FM will not create this folder automatically on a fresh install.
      final Directory editorDataDir = Directory(editorDataFolderPath);
      if (!await editorDataDir.exists()) {
        onProgress(FixProgress(
            '  Creating folder: $editorDataFolderPath'));
        try {
          // recursive: true creates parent folders as needed.
          await editorDataDir.create(recursive: true);
        } catch (e) {
          return FixResult(
            success: false,
            message: 'Could not create the editor data folder:\n'
                '$editorDataFolderPath\n\nDetails: $e',
          );
        }
      }

      // Find the EDITOR DATA sub-folder inside sourceRoot to copy from.
      final Directory? editorDataSource =
          await _findEditorDataSubDir(sourceRoot);
      if (editorDataSource != null) {
        for (final String fileName in fmfFiles) {
          final File sourceFile =
              File(p.join(editorDataSource.path, fileName));
          final File destFile =
              File(p.join(editorDataFolderPath, fileName));
          onProgress(FixProgress('  Copying: $fileName'));
          try {
            await sourceFile.copy(destFile.path);
          } catch (e) {
            return FixResult(
              success: false,
              message: 'Failed to copy $fileName to the editor data folder.'
                  '\n\nDetails: $e',
            );
          }
        }
        onProgress(const FixProgress('  ✓ Editor data files copied.'));
      }
    } else {
      onProgress(const FixProgress(
          'No EDITOR DATA folder found in the fix — skipping.'));
    }
  }

  return const FixResult(
    success: true,
    message:
        'The Real Name Fix was applied successfully!\n\n'
        'Restart Football Manager for the changes to take effect.\n\n'
        'Note: Club name corrections only apply to new save games. '
        'Existing saves will receive updated competition names, award names, '
        'and stadium names.',
  );
}

// ---------------------------------------------------------------------------
// Private helpers
// ---------------------------------------------------------------------------

/// Copies dbc/, edt/, and Inc/ from [sourceRoot] into [targetFolder],
/// recursively copying every file and sub-directory within each fix folder.
///
/// [sourceRoot] — the folder that directly contains dbc/, edt/, and Inc/.
/// [targetFolder] — the FM version folder to copy into (e.g. .../db/2600).
/// [onProgress] — receives a message for each file written.
Future<void> _copyFixFolders({
  required String sourceRoot,
  required String targetFolder,
  required void Function(FixProgress) onProgress,
}) async {
  for (final String folderName in kFixFolderNames) {
    final Directory sourceSubDir = Directory(p.join(sourceRoot, folderName));

    // Skip fix folders that don't exist in the source (not all zips include all three).
    if (!await sourceSubDir.exists()) continue;

    // list() returns all entities (files + sub-folders) inside a directory.
    // recursive: true means it descends into every sub-folder automatically.
    // followLinks: false avoids following symbolic links, which could cause
    // unintended copies outside the source folder.
    await for (final FileSystemEntity entity
        in sourceSubDir.list(recursive: true, followLinks: false)) {
      // Build the path of this entity relative to the source sub-folder root.
      // For example: if sourceSubDir = ".../dbc" and entity = ".../dbc/foo/bar.dat"
      // then relativePath = "foo/bar.dat"
      final String relativePath =
          p.relative(entity.path, from: sourceSubDir.path);

      // Build the full destination path by combining the target folder,
      // the fix folder name, and the relative path within it.
      final String destPath =
          p.join(targetFolder, folderName, relativePath);

      if (entity is File) {
        // Ensure the destination parent directory exists before copying.
        await Directory(p.dirname(destPath)).create(recursive: true);
        // Copy the file — this preserves the content exactly.
        await entity.copy(destPath);
        onProgress(FixProgress(
            '  Copied: ${p.join(folderName, relativePath)}'));
      } else if (entity is Directory) {
        // Create the destination sub-directory if it doesn't already exist.
        await Directory(destPath).create(recursive: true);
      }
    }
  }
}

/// Detects whether [fixFolderPath] contains a single wrapper sub-folder
/// (e.g. "Real Name Fix v1.0") that itself contains dbc/, edt/, Inc/.
///
/// Some downloads wrap the content in one extra folder level. This function
/// checks for that pattern and returns the wrapper folder name if found,
/// or an empty string if the fix folders are directly in [fixFolderPath].
///
/// Examples:
///   fixFolderPath/dbc/...          → returns ""
///   fixFolderPath/RealNameFix/dbc/ → returns "RealNameFix"
Future<String> _findSourcePrefix(String fixFolderPath) async {
  final Directory dir = Directory(fixFolderPath);
  final List<FileSystemEntity> topLevel =
      await dir.list(followLinks: false).toList();

  // Collect only sub-directory names at the top level.
  final List<String> subDirNames = topLevel
      .whereType<Directory>()
      .map((d) => p.basename(d.path))
      .toList();

  // If the fix folders (dbc, edt, Inc) are directly present, no prefix needed.
  final bool hasDirectFixFolders =
      subDirNames.any((name) => kFixFolderNames.contains(name));
  if (hasDirectFixFolders) return '';

  // If there is exactly one sub-directory and it is not a fix folder name,
  // it is likely a wrapper. Check whether the fix folders live inside it.
  if (subDirNames.length == 1) {
    final String candidate = subDirNames.first;
    final Directory candidateDir =
        Directory(p.join(fixFolderPath, candidate));
    final List<FileSystemEntity> innerEntities =
        await candidateDir.list(followLinks: false).toList();
    final List<String> innerDirNames = innerEntities
        .whereType<Directory>()
        .map((d) => p.basename(d.path))
        .toList();
    if (innerDirNames.any((name) => kFixFolderNames.contains(name))) {
      return candidate; // Wrapper folder found.
    }
  }

  return ''; // Could not determine a wrapper; try the top level anyway.
}

/// Looks for a sub-folder named "EDITOR DATA" (case-insensitive) directly
/// inside [sourceRoot] and returns all .fmf filenames found inside it.
///
/// [sourceRoot] is the folder that directly contains dbc/, edt/, Inc/ (and
/// potentially an EDITOR DATA folder). It already accounts for any wrapper
/// sub-folder, so callers don't need to repeat that logic.
///
/// Returns an empty list if the EDITOR DATA folder doesn't exist or is empty.
Future<List<String>> _detectFmfFiles(String sourceRoot) async {
  final Directory? editorDataDir = await _findEditorDataSubDir(sourceRoot);
  if (editorDataDir == null) return [];

  try {
    final List<FileSystemEntity> entries =
        await editorDataDir.list(followLinks: false).toList();
    // Return only .fmf files (case-insensitive extension check), sorted.
    return entries
        .whereType<File>()
        .where((f) => p.extension(f.path).toLowerCase() == '.fmf')
        .map((f) => p.basename(f.path))
        .toList()
      ..sort();
  } catch (_) {
    return [];
  }
}

/// Finds a sub-directory named "EDITOR DATA" (or "editor data" — the match
/// is case-insensitive) directly inside [sourceRoot].
///
/// Returns the [Directory] if found, or null if no such sub-folder exists.
Future<Directory?> _findEditorDataSubDir(String sourceRoot) async {
  try {
    final Directory rootDir = Directory(sourceRoot);
    if (!await rootDir.exists()) return null;

    final List<FileSystemEntity> entries =
        await rootDir.list(followLinks: false).toList();

    for (final entity in entries) {
      if (entity is Directory) {
        // Compare in lowercase so "EDITOR DATA", "editor data", "Editor Data"
        // all match correctly regardless of how the download was packaged.
        if (p.basename(entity.path).toLowerCase() == 'editor data') {
          return entity;
        }
      }
    }
  } catch (_) {
    // Swallow read errors — callers treat null as "not found".
  }
  return null;
}

/// Inspects [fixFolderPath] and returns which of the fix folder names
/// (dbc, edt, Inc) are present as direct sub-folders (accounting for one
/// level of wrapper if present).
///
/// Used by [buildPreflightInfo] to tell the user what will be copied in.
/// Returns an empty list if the folder cannot be read or contains none of
/// the expected sub-folders.
Future<List<String>> _detectFoldersInFixFolder(String fixFolderPath) async {
  try {
    final String prefix = await _findSourcePrefix(fixFolderPath);
    final String root = prefix.isEmpty
        ? fixFolderPath
        : p.join(fixFolderPath, prefix);

    final Directory rootDir = Directory(root);
    final List<FileSystemEntity> entries =
        await rootDir.list(followLinks: false).toList();
    final Set<String> subDirNames = entries
        .whereType<Directory>()
        .map((d) => p.basename(d.path))
        .toSet();

    // Return only the fix folder names that are actually present, in canonical order.
    return kFixFolderNames
        .where((name) => subDirNames.contains(name))
        .toList();
  } catch (_) {
    return [];
  }
}
