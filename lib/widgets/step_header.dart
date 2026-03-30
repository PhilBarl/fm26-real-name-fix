// step_header.dart
//
// A small reusable widget that shows a step label (e.g. "Step 2 of 4"),
// an icon, and a title at the top of each wizard screen.
// Keeping it in its own file lets every screen import it without circular
// dependencies.

import 'package:flutter/material.dart';

/// Displays the step number, an icon, and a screen title.
/// Used consistently at the top of every wizard step screen.
class StepHeader extends StatelessWidget {
  /// e.g. "Step 1 of 4"
  final String step;

  /// e.g. "Select the Fix Zip File"
  final String title;

  /// Icon displayed next to the title.
  final IconData icon;

  const StepHeader({
    super.key,
    required this.step,
    required this.title,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          step,
          style: textTheme.labelMedium?.copyWith(
            color: colorScheme.primary,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Icon(icon, color: colorScheme.primary, size: 28),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                title,
                style: textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
