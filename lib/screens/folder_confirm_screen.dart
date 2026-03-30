// folder_confirm_screen.dart
//
// Step 3 of the wizard: the app tries to automatically find the FM database
// folder based on the OS and the store the user chose. If found, it scans
// for version sub-folders (2600, 2610, 2500, etc.) and shows them as
// checkboxes. The user selects which version folders to apply the fix to.
//
// If auto-detection fails, a "Browse" button lets the user navigate to the
// db/ folder manually.

import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import '../models/app_state.dart';
import '../services/path_resolver.dart';
import '../widgets/step_header.dart';

/// Step 3 — FM folder detection and version folder selection.
///
/// This screen does async work on first load (the path resolver scans the
/// file system), so we need a StatefulWidget to track the loading state.
class FolderConfirmScreen extends StatefulWidget {
  final AppState appState;
  final VoidCallback onNext;
  final VoidCallback onBack;

  const FolderConfirmScreen({
    super.key,
    required this.appState,
    required this.onNext,
    required this.onBack,
  });

  @override
  State<FolderConfirmScreen> createState() => _FolderConfirmScreenState();
}

// ---------------------------------------------------------------------------
// Detection state — what phase is the folder-detection in?
// ---------------------------------------------------------------------------

/// The three possible states of the auto-detection process.
enum _DetectionStatus {
  /// Still scanning the file system.
  loading,

  /// Scan complete and at least one version folder was found.
  found,

  /// Scan complete but the FM folder could not be found automatically.
  notFound,
}

// ---------------------------------------------------------------------------
// Screen state
// ---------------------------------------------------------------------------

class _FolderConfirmScreenState extends State<FolderConfirmScreen> {
  _DetectionStatus _status = _DetectionStatus.loading;

  // True while a manual directory picker is open.
  bool _browsing = false;

  // Controller for the "paste path" text field shown as an alternative to the
  // folder picker on macOS (where the picker cannot navigate inside .app bundles).
  final TextEditingController _pathController = TextEditingController();

  // True while the manually-typed path is being validated.
  bool _validatingPath = false;

  // Error message to show under the text field, or null if no error.
  String? _pathError;

  /// Called once when the widget is first inserted into the widget tree.
  /// 'initState' is the right place to kick off one-time async work.
  @override
  void initState() {
    super.initState();
    _autoDetect();
  }

  /// Called when this widget is removed from the tree permanently.
  /// We must dispose the TextEditingController to free memory.
  @override
  void dispose() {
    _pathController.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Auto-detection
  // ---------------------------------------------------------------------------

  /// Runs the path resolver and populates AppState with whatever is found.
  Future<void> _autoDetect() async {
    setState(() => _status = _DetectionStatus.loading);

    // resolveDbFolder returns null if the FM folder doesn't exist at the
    // expected path, or a ResolvedPaths object if it does.
    final ResolvedPaths? resolved =
        await resolveDbFolder(widget.appState.store!);

    if (resolved != null) {
      setState(() {
        widget.appState.dbFolderPath = resolved.dbFolderPath;
        widget.appState.dbFolderManuallySet = false;
        widget.appState.availableVersionFolders = resolved.versionFolders;
        // Auto-select all version folders found. The user can uncheck any
        // they don't want to patch.
        widget.appState.selectAllVersionFolders();
        _status = _DetectionStatus.found;
      });
    } else {
      setState(() {
        _status = _DetectionStatus.notFound;
      });
    }
  }

  // ---------------------------------------------------------------------------
  // Manual path text entry (macOS primary, all platforms secondary)
  // ---------------------------------------------------------------------------

  /// Validates the path typed by the user into the text field and, if valid,
  /// populates AppState with the db/ folder and its version sub-folders.
  ///
  /// On macOS the folder picker cannot navigate inside .app bundles, so this
  /// text field is the primary manual-override path. On other platforms it is
  /// offered as an alternative to the folder picker.
  Future<void> _submitManualPath() async {
    final String raw = _pathController.text.trim();
    if (raw.isEmpty) {
      setState(() => _pathError = 'Please enter a path.');
      return;
    }

    setState(() {
      _validatingPath = true;
      _pathError = null;
    });

    try {
      // Expand ~ to the real home directory, just like the auto-detector does.
      final String expanded = _expandHome(raw);
      final Directory dir = Directory(expanded);

      if (!await dir.exists()) {
        setState(() => _pathError = 'Folder not found. Check the path and try again.');
        return;
      }

      // Scan for version sub-folders.
      // This can throw a FileSystemException on macOS if the app cannot read
      // the directory contents (e.g. a permission error). We catch that below
      // and show a helpful message rather than failing silently.
      final List<String> versionFolders = await _scanForVersionFolders(dir);

      if (versionFolders.isNotEmpty) {
        // The typed path is the db/ folder itself.
        setState(() {
          widget.appState.dbFolderPath = expanded;
          widget.appState.dbFolderManuallySet = true;
          widget.appState.availableVersionFolders = versionFolders;
          widget.appState.selectAllVersionFolders();
          _status = _DetectionStatus.found;
          _pathError = null;
        });
      } else {
        // Maybe the user typed a version folder directly (e.g. ending in /2600).
        final String folderName = p.basename(expanded);
        if (RegExp(r'^\d+$').hasMatch(folderName)) {
          setState(() {
            widget.appState.dbFolderPath = p.dirname(expanded);
            widget.appState.dbFolderManuallySet = true;
            widget.appState.availableVersionFolders = [expanded];
            widget.appState.selectAllVersionFolders();
            _status = _DetectionStatus.found;
            _pathError = null;
          });
        } else {
          setState(() => _pathError =
              'No FM version folders (e.g. 2600) found in that directory. '
              'Make sure the path points to the db/ folder.');
        }
      }
    } on FileSystemException catch (e) {
      // The OS rejected the directory read (e.g. permissions). Show the error
      // clearly so the user is not left with a silently disabled Next button.
      setState(() => _pathError =
          'Could not read that folder (${e.osError?.message ?? e.message}). '
          'Check the path is correct and the app has permission to access it.');
    } catch (e) {
      // Catch-all for any other unexpected error during validation.
      setState(() => _pathError = 'Unexpected error: $e');
    } finally {
      setState(() => _validatingPath = false);
    }
  }

  /// Expands a leading ~ to the real home directory.
  /// Mirrors the private helper in path_resolver.dart so this screen can use
  /// it without importing an internal function.
  String _expandHome(String path) {
    if (!path.startsWith('~')) return path;
    final String? home =
        Platform.environment['HOME'] ?? Platform.environment['USERPROFILE'];
    if (home == null) return path;
    return p.join(home, path.substring(2));
  }

  // ---------------------------------------------------------------------------
  // Manual folder browse
  // ---------------------------------------------------------------------------

  /// Opens a directory picker so the user can manually locate the db/ folder.
  ///
  /// After selection we scan the chosen folder for version sub-folders,
  /// exactly like we do during auto-detection.
  Future<void> _browseForFolder() async {
    setState(() => _browsing = true);

    try {
      // getDirectoryPath() opens the OS folder picker and returns the chosen
      // path, or null if the user cancelled.
      final String? chosen = await FilePicker.platform.getDirectoryPath(
        dialogTitle: 'Select the FM db/ folder',
      );

      if (chosen == null) return; // User cancelled.

      // Scan the chosen directory for version sub-folders.
      final Directory chosenDir = Directory(chosen);
      final List<String> versionFolders =
          await _scanForVersionFolders(chosenDir);

      if (versionFolders.isNotEmpty) {
        // The chosen directory is the db/ folder containing version sub-folders.
        setState(() {
          widget.appState.dbFolderPath = chosen;
          widget.appState.dbFolderManuallySet = true;
          widget.appState.availableVersionFolders = versionFolders;
          widget.appState.selectAllVersionFolders();
          _status = _DetectionStatus.found;
        });
      } else {
        // Maybe the user picked a version folder directly (e.g. they navigated
        // into 2600/ instead of db/). Check if the folder name is all digits.
        final String folderName = p.basename(chosen);
        if (RegExp(r'^\d+$').hasMatch(folderName)) {
          // Treat the parent as the db/ folder and this folder as the only version.
          setState(() {
            widget.appState.dbFolderPath = p.dirname(chosen);
            widget.appState.dbFolderManuallySet = true;
            widget.appState.availableVersionFolders = [chosen];
            widget.appState.selectAllVersionFolders();
            _status = _DetectionStatus.found;
          });
        } else {
          // Neither case matched — show an error.
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'No FM version folders found in the selected directory. '
                  'Please navigate to the db/ folder inside your FM installation.',
                ),
                duration: Duration(seconds: 6),
              ),
            );
          }
        }
      }
    } finally {
      setState(() => _browsing = false);
    }
  }

  /// Scans [dir] for sub-directories whose names are all digits.
  /// Mirrors the logic in path_resolver.dart's _findVersionFolders().
  Future<List<String>> _scanForVersionFolders(Directory dir) async {
    if (!await dir.exists()) return [];

    final List<String> found = [];
    await for (final FileSystemEntity entity in dir.list()) {
      if (entity is! Directory) continue;
      final String name = p.basename(entity.path);
      if (RegExp(r'^\d+$').hasMatch(name)) {
        found.add(entity.path);
      }
    }

    // Sort highest (newest) first.
    found.sort(
        (a, b) => int.parse(p.basename(b)).compareTo(int.parse(p.basename(a))));

    return found;
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('FM Real Name Fix Installer'),
        centerTitle: true,
        backgroundColor: colorScheme.surface,
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: Padding(
            padding: const EdgeInsets.all(32.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                StepHeader(
                  step: 'Step 3 of 4',
                  title: 'Confirm FM Folder',
                  icon: Icons.folder_outlined,
                ),
                const SizedBox(height: 24),

                // Body content changes based on detection status.
                Expanded(child: _buildBody(colorScheme, textTheme)),

                // Navigation
                Row(
                  children: [
                    TextButton.icon(
                      onPressed: widget.onBack,
                      icon: const Icon(Icons.arrow_back),
                      label: const Text('Back'),
                    ),
                    const Spacer(),
                    FilledButton.icon(
                      // Next is only enabled when at least one version is selected.
                      onPressed:
                          widget.appState.selectedVersionFolders.isNotEmpty
                              ? widget.onNext
                              : null,
                      icon: const Icon(Icons.arrow_forward),
                      label: const Text('Next'),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 24, vertical: 14),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Builds the main body content depending on [_status].
  Widget _buildBody(ColorScheme colorScheme, TextTheme textTheme) {
    switch (_status) {
      case _DetectionStatus.loading:
        return _buildLoading(colorScheme, textTheme);
      case _DetectionStatus.found:
        return _buildFound(colorScheme, textTheme);
      case _DetectionStatus.notFound:
        return _buildNotFound(colorScheme, textTheme);
    }
  }

  // ---------------------------------------------------------------------------
  // Loading state
  // ---------------------------------------------------------------------------

  Widget _buildLoading(ColorScheme colorScheme, TextTheme textTheme) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const CircularProgressIndicator(),
        const SizedBox(height: 20),
        Text(
          'Looking for FM installation…',
          style: textTheme.bodyLarge?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Found state
  // ---------------------------------------------------------------------------

  Widget _buildFound(ColorScheme colorScheme, TextTheme textTheme) {
    final List<String> versions = widget.appState.availableVersionFolders;
    final bool multipleVersions = versions.length > 1;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Detected folder card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        widget.appState.dbFolderManuallySet
                            ? Icons.folder
                            : Icons.check_circle,
                        color: colorScheme.primary,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        widget.appState.dbFolderManuallySet
                            ? 'Folder set manually'
                            : 'FM installation found',
                        style: textTheme.titleSmall?.copyWith(
                          color: colorScheme.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.appState.dbFolderPath!,
                    style: textTheme.bodySmall?.copyWith(
                      fontFamily: 'monospace',
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 12),
                  // "Change Folder" button lets the user override the path.
                  OutlinedButton.icon(
                    onPressed: _browsing ? null : _browseForFolder,
                    icon: _browsing
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.drive_folder_upload, size: 18),
                    label: const Text('Change folder'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Version folder selection
          Text(
            multipleVersions
                ? 'Select which version folders to apply the fix to:'
                : 'Version folder to apply the fix to:',
            style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            multipleVersions
                ? 'Multiple FM version folders were found. This can happen when '
                    'you have imported saves from a previous FM game, or have '
                    'multiple patch versions installed.'
                : 'One version folder was found.',
            style: textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),

          // "Select All" checkbox — only shown when there are multiple versions.
          if (multipleVersions)
            _SelectAllCheckbox(appState: widget.appState, onChanged: () {
              setState(() {});
            }),

          // Individual version checkboxes.
          ...versions.map((versionPath) => _VersionCheckbox(
                versionPath: versionPath,
                checked:
                    widget.appState.selectedVersionFolders.contains(versionPath),
                onChanged: (checked) {
                  setState(() {
                    if (checked) {
                      widget.appState.selectedVersionFolders.add(versionPath);
                    } else {
                      widget.appState.selectedVersionFolders.remove(versionPath);
                    }
                  });
                },
              )),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Not-found state
  // ---------------------------------------------------------------------------

  Widget _buildNotFound(ColorScheme colorScheme, TextTheme textTheme) {
    // On macOS the folder picker cannot navigate inside .app bundles, so the
    // path text field is shown first. On other platforms the folder picker is
    // shown first with the text field as a secondary option.
    final bool isMacOS = Platform.isMacOS;

    return SingleChildScrollView(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(height: 8),
          Icon(Icons.search_off, size: 56, color: colorScheme.onSurfaceVariant),
          const SizedBox(height: 16),
          Text(
            'FM installation not found',
            style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'The app could not find FM at the expected location for '
            '${storeLabel(widget.appState.store!)}. '
            'This can happen if FM is installed on a different drive or in a '
            'custom location.',
            style: textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),

          // On macOS, the primary option is pasting the path because the
          // system folder picker cannot navigate inside .app bundles.
          if (isMacOS) ...[
            _buildPastePathSection(colorScheme, textTheme),
            const SizedBox(height: 20),
            const Divider(),
            const SizedBox(height: 12),
            Text(
              'Or use the folder picker (note: you cannot navigate inside '
              '.app bundles with the picker on macOS — use the path field above instead):',
              style: textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
          ],

          OutlinedButton.icon(
            onPressed: _browsing ? null : _browseForFolder,
            icon: _browsing
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.drive_folder_upload),
            label: const Text('Browse for FM folder…'),
          ),

          if (!isMacOS) ...[
            const SizedBox(height: 20),
            const Divider(),
            const SizedBox(height: 12),
            Text(
              'Or paste the path to the db/ folder directly:',
              style: textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 12),
            _buildPastePathSection(colorScheme, textTheme),
          ],

          const SizedBox(height: 16),
          TextButton(
            onPressed: _autoDetect,
            child: const Text('Try auto-detection again'),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  /// Builds the "paste a path" text field + submit button used for manual entry.
  Widget _buildPastePathSection(ColorScheme colorScheme, TextTheme textTheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Paste the path to the db/ folder:',
          style: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        // Show the expected path as a hint so the user knows what to look for.
        Text(
          Platform.isMacOS
              ? 'e.g. ~/Library/Application Support/Steam/steamapps/common/'
                'Football Manager 26/fm.app/Contents/PlugIns/'
                'game_plugin.bundle/Contents/Resources/shared/data/database/db'
              : Platform.isWindows
                  ? r'e.g. C:\Program Files (x86)\Steam\steamapps\common\'
                    r'Football Manager 2026\shared\data\database\db'
                  : 'e.g. ~/.local/share/Steam/steamapps/common/'
                    'Football Manager 2026/shared/data/database/db',
          style: textTheme.bodySmall?.copyWith(
            color: colorScheme.onSurfaceVariant,
            fontFamily: 'monospace',
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _pathController,
          decoration: InputDecoration(
            hintText: 'Paste or type the path here…',
            errorText: _pathError,
            border: const OutlineInputBorder(),
            isDense: true,
          ),
          // Allow submitting with Enter key.
          onSubmitted: (_) => _submitManualPath(),
        ),
        const SizedBox(height: 8),
        FilledButton.icon(
          onPressed: _validatingPath ? null : _submitManualPath,
          icon: _validatingPath
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.check),
          label: const Text('Use this path'),
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Version checkbox widgets
// ---------------------------------------------------------------------------

/// The "Select All / Deselect All" checkbox shown above the version list
/// when multiple versions are available.
class _SelectAllCheckbox extends StatelessWidget {
  final AppState appState;
  final VoidCallback onChanged;

  const _SelectAllCheckbox({required this.appState, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final bool allSelected = appState.allVersionFoldersSelected;

    return CheckboxListTile(
      // tristate: true allows an intermediate state (dash) when only some are checked.
      tristate: true,
      // value is null (dash) for partial selection, true for all, false for none.
      value: appState.selectedVersionFolders.isEmpty
          ? false
          : (allSelected ? true : null),
      onChanged: (_) {
        if (allSelected) {
          appState.deselectAllVersionFolders();
        } else {
          appState.selectAllVersionFolders();
        }
        onChanged();
      },
      title: Text(
        allSelected ? 'Deselect all' : 'Select all',
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
      controlAffinity: ListTileControlAffinity.leading,
    );
  }
}

/// A single checkbox row for one version folder.
class _VersionCheckbox extends StatelessWidget {
  final String versionPath;
  final bool checked;
  final ValueChanged<bool> onChanged;

  const _VersionCheckbox({
    required this.versionPath,
    required this.checked,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    // Show just the folder name (e.g. "2600") as the title.
    final String versionName = p.basename(versionPath);

    // Derive a human-friendly FM version label from the folder number.
    // The first two digits are the FM year (26 = FM26, 25 = FM25, etc.).
    final String fmLabel = _fmLabel(versionName);

    return CheckboxListTile(
      value: checked,
      onChanged: (value) => onChanged(value ?? false),
      title: Text('Version $versionName  $fmLabel'),
      subtitle: Text(
        versionPath,
        style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
        overflow: TextOverflow.ellipsis,
      ),
      controlAffinity: ListTileControlAffinity.leading,
    );
  }

  /// Converts a version folder name like "2600" into a label like "(FM26)".
  /// The first two digits correspond to the FM release year.
  String _fmLabel(String version) {
    if (version.length >= 2) {
      return '(FM${version.substring(0, 2)})';
    }
    return '';
  }
}
