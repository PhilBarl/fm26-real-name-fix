// apply_screen.dart
//
// This screen runs the actual fix operation and shows a live scrolling log
// of everything that happens. The user can watch the progress in real time.
//
// Because the fix operation is async (it reads files and writes to disk),
// we kick it off in initState() and update the log list via setState() each
// time the operation reports a progress step.

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../models/app_state.dart';
import '../services/file_operations.dart';

/// The apply screen — runs the fix and streams progress to the UI.
///
/// [onDone] is called with the [FixResult] when the operation completes,
/// so the parent can advance to the result screen.
class ApplyScreen extends StatefulWidget {
  final AppState appState;
  final ValueChanged<FixResult> onDone;

  const ApplyScreen({
    super.key,
    required this.appState,
    required this.onDone,
  });

  @override
  State<ApplyScreen> createState() => _ApplyScreenState();
}

class _ApplyScreenState extends State<ApplyScreen> {
  // The list of progress messages shown in the scrolling log.
  final List<String> _log = [];

  // Whether the operation has finished (success or failure).
  bool _done = false;

  // ScrollController lets us programmatically scroll the log to the bottom
  // each time a new entry is added.
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    // Start the fix as soon as the screen appears.
    _runFix();
  }

  @override
  void dispose() {
    // Always dispose of controllers to free memory when the widget is removed.
    _scrollController.dispose();
    super.dispose();
  }

  /// Calls [applyFix] with the data from [AppState] and collects progress
  /// messages into [_log]. When done, calls [widget.onDone] with the result.
  Future<void> _runFix() async {
    final FixResult result = await applyFix(
      fixFolderPath: widget.appState.fixFolderPath!,
      // Convert the Set to a List so applyFix can iterate in order.
      targetFolders: widget.appState.selectedVersionFolders.toList(),
      onProgress: (FixProgress progress) {
        // setState() triggers a UI rebuild so the new log line appears immediately.
        setState(() {
          _log.add(progress.message);
        });
        // After the rebuild, scroll the log to show the latest line.
        // SchedulerBinding.instance.addPostFrameCallback waits until the current
        // frame has finished drawing before running the scroll — this ensures
        // the new item is in the list before we try to scroll to it.
        SchedulerBinding.instance.addPostFrameCallback((_) {
          if (_scrollController.hasClients) {
            _scrollController.animateTo(
              _scrollController.position.maxScrollExtent,
              duration: const Duration(milliseconds: 150),
              curve: Curves.easeOut,
            );
          }
        });
      },
    );

    // Mark the operation as done so the UI can update.
    setState(() => _done = true);

    // A brief pause so the user can see the final log line before we advance.
    await Future.delayed(const Duration(milliseconds: 600));

    // Call the parent callback — it will navigate to the result screen.
    if (mounted) {
      widget.onDone(result);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('FM Real Name Fix Installer'),
        centerTitle: true,
        // Disable the back button while the fix is running to prevent
        // the user from interrupting a partial file operation.
        automaticallyImplyLeading: false,
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
                // Header
                Row(
                  children: [
                    // Show a spinner while running, a tick when done.
                    _done
                        ? Icon(Icons.check_circle,
                            color: colorScheme.primary, size: 28)
                        : SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: colorScheme.primary,
                            ),
                          ),
                    const SizedBox(width: 12),
                    Text(
                      _done ? 'Fix applied!' : 'Applying fix…',
                      style: textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  _done
                      ? 'All done. Moving to the results screen…'
                      : 'Please wait — do not close Football Manager '
                          'while this is running.',
                  style: textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 20),

                // Scrolling log output
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: colorScheme.surface,
                      border: Border.all(color: colorScheme.outlineVariant),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: _log.isEmpty
                        ? const Center(child: Text('Starting…'))
                        : ListView.builder(
                            controller: _scrollController,
                            padding: const EdgeInsets.all(12),
                            itemCount: _log.length,
                            itemBuilder: (context, index) {
                              final String line = _log[index];
                              // Colour lines differently based on their content.
                              final Color lineColor = _colorForLine(
                                  line, colorScheme);
                              return Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 1.5),
                                child: Text(
                                  line,
                                  style: TextStyle(
                                    fontFamily: 'monospace',
                                    fontSize: 12,
                                    color: lineColor,
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Returns a colour for a log line based on its content.
  /// Section headers get the primary colour; success lines get green;
  /// everything else uses the default text colour.
  Color _colorForLine(String line, ColorScheme colorScheme) {
    if (line.startsWith('──')) return colorScheme.primary;
    if (line.contains('✓')) return Colors.green;
    if (line.contains('Deleting')) return colorScheme.error;
    return colorScheme.onSurface;
  }
}
