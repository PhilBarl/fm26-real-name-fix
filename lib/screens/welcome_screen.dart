// welcome_screen.dart
//
// The first screen the user sees when they open the app.
// Its job is to briefly explain what the app does and what the user needs
// to have ready before they begin (the zip file from Sortitoutsi).
//
// This screen has no state to manage — it just displays text and a button —
// so it is a StatelessWidget (a widget that never changes after it is built).

import 'package:flutter/material.dart';

/// The welcome screen — step 1 of the wizard.
///
/// [onNext] is a callback that the parent widget provides. When the user taps
/// "Get Started", we call onNext() and the parent moves to the next screen.
/// The screen itself doesn't know or care what comes next — that's the parent's job.
class WelcomeScreen extends StatelessWidget {
  /// Called when the user taps "Get Started".
  final VoidCallback onNext;

  // A constructor in Dart uses the class name followed by parentheses.
  // 'const' means this widget can be created at compile-time (a small performance win).
  // 'required' means the caller MUST provide onNext — it can't be left out.
  const WelcomeScreen({super.key, required this.onNext});

  @override
  Widget build(BuildContext context) {
    // 'context' gives us information about where this widget sits in the app,
    // including the current theme. We use Theme.of(context) to read colours.
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      // AppBar is the horizontal bar at the top of the screen.
      appBar: AppBar(
        title: const Text('FM Real Name Fix Installer'),
        centerTitle: true,
        backgroundColor: colorScheme.surface,
      ),
      body: Center(
        // ConstrainedBox keeps the content from stretching too wide on large monitors.
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: Padding(
            padding: const EdgeInsets.all(32.0),
            // SingleChildScrollView lets the content scroll if the window is very small.
            child: SingleChildScrollView(
              child: Column(
                // mainAxisAlignment centres children vertically within the column.
                mainAxisAlignment: MainAxisAlignment.center,
                // crossAxisAlignment stretches children to fill the column width.
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 24),

                  // App icon / logo area
                  Icon(
                    Icons.sports_soccer,
                    size: 72,
                    color: colorScheme.primary,
                  ),
                  const SizedBox(height: 24),

                  // Main heading
                  Text(
                    'FM Real Name Fix Installer',
                    style: textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: colorScheme.onSurface,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),

                  // Subtitle
                  Text(
                    'Automatically installs the Real Name Fix for Football Manager, '
                    'replacing placeholder names with real club, competition, '
                    'award, and stadium names.',
                    style: textTheme.bodyLarge?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),

                  // "What you'll need" card
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.checklist,
                                  color: colorScheme.primary, size: 20),
                              const SizedBox(width: 8),
                              Text(
                                'What you\'ll need',
                                style: textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          _bulletPoint(
                            context,
                            'The Real Name Fix zip file, downloaded from '
                            'Sortitoutsi (sortitoutsi.net).',
                          ),
                          const SizedBox(height: 8),
                          _bulletPoint(
                            context,
                            'Football Manager installed via Steam, Epic Games, '
                            'or Game Pass.',
                          ),
                          const SizedBox(height: 8),
                          _bulletPoint(
                            context,
                            'Football Manager must be closed before applying the fix.',
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // "Good to know" card
                  Card(
                    color: colorScheme.secondaryContainer.withValues(alpha: 0.4),
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.info_outline,
                                  color: colorScheme.secondary, size: 20),
                              const SizedBox(width: 8),
                              Text(
                                'Good to know',
                                style: textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          _bulletPoint(
                            context,
                            'New save games get the full fix — all club, competition, '
                            'award, and stadium names corrected.',
                          ),
                          const SizedBox(height: 8),
                          _bulletPoint(
                            context,
                            'Existing save games get a partial fix — competition, '
                            'award, and stadium names update, but club names '
                            '(including Brazilian clubs) require a new save.',
                          ),
                          const SizedBox(height: 8),
                          _bulletPoint(
                            context,
                            'The fix must be re-applied after each official FM '
                            'update, as updates restore the original files.',
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),

                  // "Get Started" button
                  FilledButton.icon(
                    onPressed: onNext,
                    icon: const Icon(Icons.arrow_forward),
                    label: const Text('Get Started'),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      textStyle: textTheme.titleMedium,
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Helper that builds a single bullet-point row.
  /// [text] is the content of the bullet point.
  Widget _bulletPoint(BuildContext context, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 6.0),
          child: Icon(
            Icons.circle,
            size: 6,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          // Expanded makes the text fill the remaining row width,
          // allowing it to wrap onto multiple lines correctly.
          child: Text(
            text,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
        ),
      ],
    );
  }
}
