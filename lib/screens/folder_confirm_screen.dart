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

  /// Called once when the widget is first inserted into the widget tree.
  /// 'initState' is the right place to kick off one-time async work.
  @override
  void initState() {
    super.initState();
    _autoDetect();
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
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
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
          '${storeLabel(widget.appState.store!)}.\n\n'
          'This can happen if FM is installed on a different drive or in a '
          'custom location. Use the button below to navigate to the db/ folder '
          'inside your FM installation manually.',
          style: textTheme.bodyMedium?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        FilledButton.icon(
          onPressed: _browsing ? null : _browseForFolder,
          icon: _browsing
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.drive_folder_upload),
          label: const Text('Browse for FM folder…'),
          style: FilledButton.styleFrom(
            padding:
                const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          ),
        ),
        const SizedBox(height: 16),
        TextButton(
          onPressed: _autoDetect,
          child: const Text('Try auto-detection again'),
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
