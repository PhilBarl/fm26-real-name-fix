// result_screen.dart
//
// The final screen of the wizard. Shows either a success confirmation or
// a detailed error message depending on what happened during the fix operation.
//
// A "Start Over" button resets the whole wizard so the user can run the
// installer again (e.g. after a new FM patch update).

import 'package:flutter/material.dart';

import '../services/file_operations.dart';

/// The result screen — shown after the fix operation completes.
///
/// [result] holds the outcome (success or failure + message) from [applyFix].
/// [onStartOver] resets the wizard back to the welcome screen.
class ResultScreen extends StatelessWidget {
  final FixResult result;
  final VoidCallback onStartOver;

  const ResultScreen({
    super.key,
    required this.result,
    required this.onStartOver,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    // Choose colours and icons based on success or failure.
    final Color headerColor =
        result.success ? Colors.green.shade700 : colorScheme.error;
    final IconData headerIcon =
        result.success ? Icons.check_circle : Icons.error;
    final String headerText = result.success ? 'Fix Applied!' : 'Fix Failed';

    return Scaffold(
      appBar: AppBar(
        title: const Text('FM Real Name Fix Installer'),
        centerTitle: true,
        automaticallyImplyLeading: false, // No back button on the final screen.
        backgroundColor: colorScheme.surface,
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Padding(
            padding: const EdgeInsets.all(40.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Large icon
                Icon(headerIcon, size: 80, color: headerColor),
                const SizedBox(height: 20),

                // Heading
                Text(
                  headerText,
                  style: textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: headerColor,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),

                // Message card
                Card(
                  color: result.success
                      ? Colors.green.shade900.withValues(alpha: 0.3)
                      : colorScheme.errorContainer.withValues(alpha: 0.4),
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Text(
                      result.message,
                      style: textTheme.bodyLarge?.copyWith(
                        color: colorScheme.onSurface,
                        height: 1.5,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
                const SizedBox(height: 32),

                // "Start Over" button — resets to the beginning.
                // Useful when re-applying after a new FM patch update.
                OutlinedButton.icon(
                  onPressed: onStartOver,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Start Over'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    textStyle: textTheme.titleMedium,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
