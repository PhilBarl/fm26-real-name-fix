// main.dart
//
// The entry point for the FM Real Name Fix Installer app.
//
// This file does two things:
//   1. Defines the root MaterialApp widget with the app's theme.
//   2. Defines the WizardRoot widget, which owns the shared AppState and
//      controls which wizard screen is currently shown.
//
// Think of WizardRoot as the "conductor" — it holds all the data and decides
// what step the user is on, while each individual screen widget is a "performer"
// that only knows about its own job.

import 'package:flutter/material.dart';

import 'models/app_state.dart';
import 'screens/apply_screen.dart';
import 'screens/folder_confirm_screen.dart';
import 'screens/preflight_screen.dart';
import 'screens/result_screen.dart';
import 'screens/store_picker_screen.dart';
import 'screens/welcome_screen.dart';
import 'screens/zip_picker_screen.dart';
import 'services/file_operations.dart';

// ---------------------------------------------------------------------------
// App entry point
// ---------------------------------------------------------------------------

/// main() is the function Dart calls when the app starts.
/// runApp() takes a widget and makes it the root of the entire UI.
void main() {
  runApp(const FmRealNameFixApp());
}

// ---------------------------------------------------------------------------
// Root app widget
// ---------------------------------------------------------------------------

/// The root of the application. Sets up the Material theme and hands off to
/// WizardRoot to manage the actual wizard flow.
///
/// StatelessWidget is used here because the app-level configuration (theme,
/// title) never changes at runtime.
class FmRealNameFixApp extends StatelessWidget {
  const FmRealNameFixApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FM Real Name Fix Installer',
      // debugShowCheckedModeBanner removes the red "DEBUG" banner in the corner.
      debugShowCheckedModeBanner: false,
      // Material 3 dark theme with a green primary colour.
      // ColorScheme.fromSeed() generates a full harmonious colour palette from
      // a single seed colour, adapting it for dark mode.
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF2E7D32), // deep green
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: const WizardRoot(),
    );
  }
}

// ---------------------------------------------------------------------------
// Wizard root — step controller
// ---------------------------------------------------------------------------

/// Owns the [AppState] object and the current wizard step index.
/// Renders the correct screen for the current step and provides navigation
/// callbacks to each screen.
///
/// StatefulWidget is used because both _step and _appState can change as
/// the user moves through the wizard.
class WizardRoot extends StatefulWidget {
  const WizardRoot({super.key});

  @override
  State<WizardRoot> createState() => _WizardRootState();
}

// ---------------------------------------------------------------------------
// Wizard step indices — named constants make the switch statement readable.
// ---------------------------------------------------------------------------

const int _stepWelcome = 0;
const int _stepZipPicker = 1;
const int _stepStorePicker = 2;
const int _stepFolderConfirm = 3;
const int _stepPreflight = 4;
const int _stepApply = 5;
const int _stepResult = 6;

class _WizardRootState extends State<WizardRoot> {
  // The current wizard step. Starts at the welcome screen.
  int _step = _stepWelcome;

  // The shared state object. All data collected during the wizard lives here.
  // We create a fresh one when the app starts and again on "Start Over".
  AppState _appState = AppState();

  // The result of the fix operation, stored so we can pass it to the result screen.
  FixResult? _fixResult;

  /// Advances to a specific step.
  void _goTo(int step) {
    setState(() => _step = step);
  }

  /// Resets everything back to the start (called by the "Start Over" button).
  void _startOver() {
    setState(() {
      _step = _stepWelcome;
      _appState = AppState(); // discard all collected data
      _fixResult = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    // AnimatedSwitcher smoothly fades between screens when _step changes.
    // This gives the wizard a polished feel without complex navigation code.
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 200),
      child: _buildCurrentStep(),
    );
  }

  /// Returns the widget for the current step.
  ///
  /// Each screen receives the AppState (to read and write shared data) and
  /// callbacks for navigating forward and backward.
  ///
  /// The 'key' on each widget is important for AnimatedSwitcher — it tells
  /// Flutter that a genuinely different widget is being shown, triggering
  /// the fade animation. Without unique keys, Flutter might reuse the
  /// previous widget's state instead of creating a fresh one.
  Widget _buildCurrentStep() {
    switch (_step) {
      case _stepWelcome:
        return WelcomeScreen(
          key: const ValueKey(_stepWelcome),
          onNext: () => _goTo(_stepZipPicker),
        );

      case _stepZipPicker:
        return ZipPickerScreen(
          key: const ValueKey(_stepZipPicker),
          appState: _appState,
          onNext: () => _goTo(_stepStorePicker),
          onBack: () => _goTo(_stepWelcome),
        );

      case _stepStorePicker:
        return StorePickerScreen(
          key: const ValueKey(_stepStorePicker),
          appState: _appState,
          onNext: () => _goTo(_stepFolderConfirm),
          onBack: () => _goTo(_stepZipPicker),
        );

      case _stepFolderConfirm:
        return FolderConfirmScreen(
          key: const ValueKey(_stepFolderConfirm),
          appState: _appState,
          onNext: () => _goTo(_stepPreflight),
          onBack: () => _goTo(_stepStorePicker),
        );

      case _stepPreflight:
        return PreflightScreen(
          key: const ValueKey(_stepPreflight),
          appState: _appState,
          onNext: () => _goTo(_stepApply),
          onBack: () => _goTo(_stepFolderConfirm),
        );

      case _stepApply:
        return ApplyScreen(
          key: const ValueKey(_stepApply),
          appState: _appState,
          onDone: (FixResult result) {
            // Store the result, then advance to the result screen.
            setState(() => _fixResult = result);
            _goTo(_stepResult);
          },
        );

      case _stepResult:
        return ResultScreen(
          key: const ValueKey(_stepResult),
          result: _fixResult!,
          onStartOver: _startOver,
        );

      default:
        // This should never happen, but Dart requires a default case.
        return const SizedBox.shrink();
    }
  }
}
