// zip_picker_screen.dart
//
// Step 1 of the wizard: the user selects the Real Name Fix folder they
// downloaded from Sortitoutsi.
//
// The fix is distributed as a folder (not a zip). The user downloads it,
// then uses this screen to point the app at it. The folder should contain
// dbc/, edt/, and Inc/ sub-folders.
//
// We use the 'file_picker' package to open a native OS folder-chooser dialog.
// The selected path is stored in AppState so the rest of the wizard can use it.

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../models/app_state.dart';
import '../widgets/step_header.dart';

/// Step 1 — fix folder selection.
///
/// This is a StatefulWidget because the screen has local state: whether the
/// folder picker is currently open (to disable the button while it's loading).
///
/// StatefulWidget is used when a widget needs to remember something that can
/// change over time. Here we remember whether we're waiting for the picker.
class ZipPickerScreen extends StatefulWidget {
  /// The shared wizard state object. We write the folder path into it.
  final AppState appState;

  /// Called when the user taps "Next" (only enabled once a folder is chosen).
  final VoidCallback onNext;

  /// Called when the user taps "Back".
  final VoidCallback onBack;

  const ZipPickerScreen({
    super.key,
    required this.appState,
    required this.onNext,
    required this.onBack,
  });

  // createState() is required by StatefulWidget. It creates the mutable State
  // object that lives alongside this widget.
  @override
  State<ZipPickerScreen> createState() => _ZipPickerScreenState();
}

/// The State class holds mutable data and logic for ZipPickerScreen.
///
/// The underscore prefix (_) means this class is private to this file —
/// callers only see ZipPickerScreen, never _ZipPickerScreenState.
class _ZipPickerScreenState extends State<ZipPickerScreen> {
  // Whether the folder picker dialog is currently open.
  // We use this to show a spinner and disable the button while waiting.
  bool _picking = false;

  /// Opens the native folder picker dialog and, if the user selects a folder,
  /// stores the path in [widget.appState].
  ///
  /// 'async' means this function can pause while waiting for the picker to return
  /// a result without freezing the UI. 'await' is used to wait at each pause point.
  Future<void> _pickFolder() async {
    // Tell the UI we are opening the picker (triggers a rebuild to show spinner).
    setState(() => _picking = true);

    try {
      // FilePicker.platform.getDirectoryPath() opens the OS folder-chooser dialog.
      // It returns the selected folder path as a String, or null if cancelled.
      final String? selectedPath = await FilePicker.platform.getDirectoryPath(
        dialogTitle: 'Select the Real Name Fix folder',
      );

      // selectedPath is null if the user cancelled without selecting a folder.
      if (selectedPath != null) {
        // setState() tells Flutter to rebuild the widget with the new value.
        // We must always update state inside setState() so Flutter knows
        // the UI needs to be redrawn.
        setState(() {
          widget.appState.fixFolderPath = selectedPath;
        });
      }
    } finally {
      // 'finally' runs whether or not an error occurred — ensures we always
      // clear the loading state even if something goes wrong.
      setState(() => _picking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    // Whether a folder has been chosen yet (used to enable/disable Next).
    final bool hasFolder = widget.appState.fixFolderPath != null;

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
                // Step indicator
                StepHeader(
                  step: 'Step 1 of 4',
                  title: 'Select the Fix Folder',
                  icon: Icons.folder_outlined,
                ),
                const SizedBox(height: 24),

                Text(
                  'Download the Real Name Fix from sortitoutsi.net, then '
                  'select the downloaded folder below. The app will read its '
                  'contents — it is never modified or moved.',
                  style: textTheme.bodyLarge?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 24),

                // Browse button
                OutlinedButton.icon(
                  onPressed: _picking ? null : _pickFolder,
                  // Show a spinner while the picker is open.
                  icon: _picking
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.folder_open),
                  label: Text(_picking ? 'Opening…' : 'Browse for fix folder…'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    textStyle: textTheme.bodyLarge,
                  ),
                ),
                const SizedBox(height: 16),

                // Selected folder display (only shown once a folder is picked)
                if (hasFolder)
                  Card(
                    color: colorScheme.primaryContainer.withValues(alpha: 0.4),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Row(
                        children: [
                          Icon(Icons.check_circle,
                              color: colorScheme.primary, size: 20),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Selected folder:',
                                  style: textTheme.labelSmall?.copyWith(
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  widget.appState.fixFolderPath!,
                                  style: textTheme.bodyMedium?.copyWith(
                                    fontFamily: 'monospace',
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 2,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                // Push nav buttons to the bottom
                const Spacer(),

                // Navigation row: Back on the left, Next on the right
                Row(
                  children: [
                    TextButton.icon(
                      onPressed: widget.onBack,
                      icon: const Icon(Icons.arrow_back),
                      label: const Text('Back'),
                    ),
                    const Spacer(),
                    FilledButton.icon(
                      // Next is disabled until a folder has been selected.
                      onPressed: hasFolder ? widget.onNext : null,
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
}
