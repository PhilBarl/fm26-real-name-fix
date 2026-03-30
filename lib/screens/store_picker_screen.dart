// store_picker_screen.dart
//
// Step 2 of the wizard: the user selects which game store they have FM
// installed through (Steam, Epic Games, or Game Pass on Windows).
//
// The chosen store is stored in AppState and later used by the path resolver
// to determine where to look for the FM database folder.

import 'package:flutter/material.dart';

import '../models/app_state.dart';
import '../widgets/step_header.dart';

/// Step 2 — game store selection.
///
/// This is a StatefulWidget because the dropdown selection is local UI state
/// (the user can change their mind before pressing Next).
class StorePickerScreen extends StatefulWidget {
  /// The shared wizard state object. We write the store choice into it.
  final AppState appState;

  /// Called when the user taps "Next".
  final VoidCallback onNext;

  /// Called when the user taps "Back".
  final VoidCallback onBack;

  const StorePickerScreen({
    super.key,
    required this.appState,
    required this.onNext,
    required this.onBack,
  });

  @override
  State<StorePickerScreen> createState() => _StorePickerScreenState();
}

class _StorePickerScreenState extends State<StorePickerScreen> {
  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    // Get the list of stores valid for this OS (Game Pass excluded on non-Windows).
    final List<Store> stores = availableStores();

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
                  step: 'Step 2 of 4',
                  title: 'Select Your Game Store',
                  icon: Icons.store_outlined,
                ),
                const SizedBox(height: 24),

                Text(
                  'Choose the store you used to buy Football Manager. '
                  'This tells the app where to look for the game files.',
                  style: textTheme.bodyLarge?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 24),

                // Store selection cards — one per available store.
                // We use a Column of tappable cards rather than a dropdown
                // so the choices are clearly visible without extra taps.
                ...stores.map((store) => _StoreCard(
                      store: store,
                      selected: widget.appState.store == store,
                      onTap: () {
                        setState(() {
                          widget.appState.store = store;
                        });
                      },
                    )),

                const Spacer(),

                Row(
                  children: [
                    TextButton.icon(
                      onPressed: widget.onBack,
                      icon: const Icon(Icons.arrow_back),
                      label: const Text('Back'),
                    ),
                    const Spacer(),
                    FilledButton.icon(
                      // Next is disabled until a store has been selected.
                      onPressed: widget.appState.store != null
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
}

// ---------------------------------------------------------------------------
// Store selection card
// ---------------------------------------------------------------------------

/// A tappable card representing a single store option.
///
/// Highlights with the primary colour when [selected] is true.
class _StoreCard extends StatelessWidget {
  final Store store;
  final bool selected;
  final VoidCallback onTap;

  const _StoreCard({
    required this.store,
    required this.selected,
    required this.onTap,
  });

  /// Returns the icon for each store.
  IconData _iconFor(Store store) {
    switch (store) {
      case Store.steam:
        return Icons.videogame_asset;
      case Store.epicGames:
        return Icons.gamepad_outlined;
      case Store.gamePass:
        return Icons.sports_esports;
    }
  }

  /// Returns a short description for each store shown below the name.
  String _descriptionFor(Store store) {
    switch (store) {
      case Store.steam:
        return 'Installed via the Steam client';
      case Store.epicGames:
        return 'Installed via the Epic Games Launcher';
      case Store.gamePass:
        return 'Installed via Xbox / Game Pass on Windows';
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10.0),
      child: InkWell(
        // InkWell makes any widget tappable with a ripple effect.
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          // AnimatedContainer smoothly transitions between the selected and
          // unselected appearances when the user taps.
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected
                  ? colorScheme.primary
                  : colorScheme.outlineVariant,
              width: selected ? 2 : 1,
            ),
            color: selected
                ? colorScheme.primaryContainer.withValues(alpha: 0.3)
                : colorScheme.surface,
          ),
          child: Row(
            children: [
              Icon(
                _iconFor(store),
                color: selected
                    ? colorScheme.primary
                    : colorScheme.onSurfaceVariant,
                size: 28,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      storeLabel(store),
                      style: textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: selected
                            ? colorScheme.primary
                            : colorScheme.onSurface,
                      ),
                    ),
                    Text(
                      _descriptionFor(store),
                      style: textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              if (selected)
                Icon(Icons.check_circle, color: colorScheme.primary, size: 22),
            ],
          ),
        ),
      ),
    );
  }
}
