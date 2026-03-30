// preflight_screen.dart
//
// Step 4 of the wizard: shows the user a full summary of exactly what will
// happen before any changes are made. This gives them a chance to review
// and confirm — or go back and change something — before any files are deleted.

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import '../models/app_state.dart';
import '../services/file_operations.dart';
import '../widgets/step_header.dart';

/// Step 4 — pre-flight confirmation screen.
///
/// On first load it calls [buildPreflightInfo] to inspect the selected folders
/// and zip without modifying anything, then displays the results.
///
/// StatefulWidget is used because we need to track the async loading state.
class PreflightScreen extends StatefulWidget {
  final AppState appState;
  final VoidCallback onNext; // proceeds to the apply screen
  final VoidCallback onBack;

  const PreflightScreen({
    super.key,
    required this.appState,
    required this.onNext,
    required this.onBack,
  });

  @override
  State<PreflightScreen> createState() => _PreflightScreenState();
}

class _PreflightScreenState extends State<PreflightScreen> {
  // Null while loading, populated once buildPreflightInfo completes.
  PreflightInfo? _info;

  // Set to true if the fix folder couldn't be read or no fix folders were found in it.
  bool _zipError = false;

  @override
  void initState() {
    super.initState();
    _loadPreflightInfo();
  }

  Future<void> _loadPreflightInfo() async {
    final PreflightInfo? info = await buildPreflightInfo(
      fixFolderPath: widget.appState.fixFolderPath!,
      targetFolders: widget.appState.selectedVersionFolders.toList(),
    );

    setState(() {
      _info = info;
      _zipError = (info == null);
    });
  }

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
          constraints: const BoxConstraints(maxWidth: 640),
          child: Padding(
            padding: const EdgeInsets.all(32.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                StepHeader(
                  step: 'Step 4 of 4',
                  title: 'Review & Confirm',
                  icon: Icons.checklist_rtl,
                ),
                const SizedBox(height: 24),

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
                    // The "Apply Fix" button is only shown once we have valid info.
                    if (_info != null)
                      FilledButton.icon(
                        onPressed: widget.onNext,
                        icon: const Icon(Icons.build),
                        label: const Text('Apply Fix'),
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 24, vertical: 14),
                          backgroundColor: colorScheme.error,
                          foregroundColor: colorScheme.onError,
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

  Widget _buildBody(ColorScheme colorScheme, TextTheme textTheme) {
    // Still loading
    if (_info == null && !_zipError) {
      return const Center(child: CircularProgressIndicator());
    }

    // Fix folder read error
    if (_zipError) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 56, color: colorScheme.error),
            const SizedBox(height: 16),
            Text(
              'Could not read the fix folder',
              style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'The selected folder could not be read, or it does not contain '
              'the expected fix sub-folders (dbc, edt, Inc).\n\n'
              'Go back and select the correct Real Name Fix folder from Sortitoutsi.',
              style: textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    // Show the full pre-flight summary
    final info = _info!;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Review the changes below. Once you tap "Apply Fix", the selected '
            'folders will be permanently deleted and replaced.',
            style: textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 20),

          // --- Fix folder being used ---
          _SectionCard(
            icon: Icons.folder_outlined,
            title: 'Source fix folder',
            color: colorScheme.secondaryContainer,
            child: Text(
              info.fixFolderPath,
              style: textTheme.bodySmall?.copyWith(fontFamily: 'monospace'),
            ),
          ),
          const SizedBox(height: 12),

          // --- What will be copied in from the fix folder ---
          _SectionCard(
            icon: Icons.download,
            title: 'Folders to be copied in (from fix folder)',
            color: colorScheme.primaryContainer,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: info.foldersInSource
                  .map((f) => _folderRow(context, f, Icons.add_circle_outline,
                      colorScheme.primary))
                  .toList(),
            ),
          ),
          const SizedBox(height: 12),

          // --- What will be deleted per version folder ---
          ...info.targetFolders.map((versionFolder) {
            final String versionName = p.basename(versionFolder);
            final List<String> toDelete =
                info.foldersToDelete[versionFolder] ?? [];

            return Padding(
              padding: const EdgeInsets.only(bottom: 12.0),
              child: _SectionCard(
                icon: Icons.delete_outline,
                title: 'Version $versionName — folders to be deleted',
                color: colorScheme.errorContainer,
                child: toDelete.isEmpty
                    ? Text(
                        'No existing fix folders found — nothing to delete.',
                        style: textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: toDelete
                            .map((f) => _folderRow(
                                context,
                                f,
                                Icons.remove_circle_outline,
                                colorScheme.error))
                            .toList(),
                      ),
              ),
            );
          }),

          // --- Warning banner ---
          Card(
            color: colorScheme.tertiaryContainer.withValues(alpha: 0.5),
            child: Padding(
              padding: const EdgeInsets.all(14.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.warning_amber_rounded,
                      color: colorScheme.tertiary, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Existing save games will receive updated competition, '
                      'award, and stadium names — but club names only update '
                      'in new save games.',
                      style: textTheme.bodySmall?.copyWith(
                        color: colorScheme.onTertiaryContainer,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  /// A single row showing a folder name with an icon and colour.
  Widget _folderRow(
      BuildContext context, String name, IconData icon, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3.0),
      child: Row(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Text(
            '$name/',
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(fontFamily: 'monospace'),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Reusable section card
// ---------------------------------------------------------------------------

/// A card with a coloured header row and arbitrary content beneath.
class _SectionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final Color color;
  final Widget child;

  const _SectionCard({
    required this.icon,
    required this.title,
    required this.color,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Coloured header
          Container(
            color: color.withValues(alpha: 0.4),
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              children: [
                Icon(icon, size: 18, color: colorScheme.onSurface),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          // Content
          Padding(
            padding: const EdgeInsets.all(14.0),
            child: child,
          ),
        ],
      ),
    );
  }
}
