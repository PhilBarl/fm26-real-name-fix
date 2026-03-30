// app_state.dart
//
// This file defines the shared state that flows through the entire wizard.
// Rather than passing individual variables between screens, we bundle everything
// into one AppState object so it's easy to read and pass around.
//
// In Flutter, "state" just means data that can change and that the UI reacts to.
// By keeping all wizard state in one place, any screen can read or update it.

// The 'dart:io' import gives us Platform, which lets us detect macOS/Windows/Linux.
import 'dart:io';

// ---------------------------------------------------------------------------
// Store — which game store the user has FM26 installed through
// ---------------------------------------------------------------------------

/// Represents the three stores FM26 can be purchased from.
/// Each store installs the game to a different folder path.
enum Store {
  steam,
  epicGames,
  gamePass, // Windows-only (Xbox Game Pass)
}

/// Returns a human-readable label for the store, used in dropdown menus.
String storeLabel(Store store) {
  switch (store) {
    case Store.steam:
      return 'Steam';
    case Store.epicGames:
      return 'Epic Games';
    case Store.gamePass:
      return 'Game Pass (Xbox)';
  }
}

/// Returns which stores are valid on the current platform.
/// Game Pass is only available on Windows, so we exclude it on macOS/Linux.
List<Store> availableStores() {
  if (Platform.isWindows) {
    return [Store.steam, Store.epicGames, Store.gamePass];
  } else {
    // macOS and Linux only have Steam and Epic
    return [Store.steam, Store.epicGames];
  }
}

// ---------------------------------------------------------------------------
// AppState — the single object that holds all wizard data
// ---------------------------------------------------------------------------

/// Holds all the information collected during the install wizard.
///
/// This is a plain Dart class (not a Flutter widget). It stores:
/// - The zip file path the user selected
/// - Which store they chose
/// - The FM26 database folder path (auto-detected or manually chosen)
///
/// The root widget (in main.dart) owns an instance of this and passes it
/// down to each screen as a constructor argument.
class AppState {
  // The path to the fix folder the user downloaded from Sortitoutsi.
  // This folder should contain dbc/, edt/, and Inc/ sub-folders.
  // Null until the user has picked a folder.
  String? fixFolderPath;

  // Which game store FM26 is installed through.
  // Null until the user has made a selection.
  Store? store;

  // The full path to the FM26 database folder that contains the version
  // sub-folders (i.e. the `db/` directory).
  // This is either auto-detected from the OS/store or manually set by the user.
  // Null until detection or manual selection has occurred.
  String? dbFolderPath;

  // Whether the dbFolderPath was set manually by the user (true)
  // or auto-detected by the app (false). Used for display purposes.
  bool dbFolderManuallySet = false;

  // All version sub-folders found inside dbFolderPath.
  // Each entry is a full path, e.g. "/path/to/db/2600".
  // This list may contain multiple entries when the user has several FM
  // versions installed or has imported saves from previous FM versions.
  // Populated after auto-detection or manual folder selection.
  List<String> availableVersionFolders = [];

  // The subset of availableVersionFolders that the user has checked.
  // The fix will be applied to each of these folders.
  // Represented as a Set so membership checks are O(1).
  Set<String> selectedVersionFolders = {};

  // ---------------------------------------------------------------------------
  // Convenience helpers
  // ---------------------------------------------------------------------------

  /// Returns true only when we have everything needed to run the pre-flight check:
  /// a fix folder, a store, a db folder path, and at least one version selected.
  bool get isReadyForPreflight =>
      fixFolderPath != null &&
      store != null &&
      dbFolderPath != null &&
      selectedVersionFolders.isNotEmpty;

  /// Selects all available version folders (used by the "Select All" checkbox).
  void selectAllVersionFolders() {
    selectedVersionFolders = Set.from(availableVersionFolders);
  }

  /// Deselects all version folders.
  void deselectAllVersionFolders() {
    selectedVersionFolders = {};
  }

  /// Returns true if every available version folder is currently selected.
  /// Used to determine whether the "Select All" checkbox should be checked.
  bool get allVersionFoldersSelected =>
      availableVersionFolders.isNotEmpty &&
      selectedVersionFolders.length == availableVersionFolders.length;
}
  