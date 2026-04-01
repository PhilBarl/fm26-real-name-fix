# FM26 Real Name Fix — Installer App

A Flutter desktop app that automates installing the Football Manager 2026 Real Name Fix.

The fix replaces fake/placeholder names (clubs, competitions, awards, stadiums) with real licensed names. It is sourced from [Sortitoutsi](https://sortitoutsi.net) — **this app does not distribute the fix files**. You download the zip yourself, then point the app at it.

---

## Platforms

- macOS
- Windows
- Linux

---

## How it works

1. **Download** the Real Name Fix zip from Sortitoutsi.
2. **Run this app** and follow the wizard:
   - Select the downloaded zip file
   - Select your store (Steam / Epic Games / Game Pass)
   - Confirm the auto-detected FM26 folder
   - Review what will be deleted and copied
   - Apply the fix
3. **Restart FM26** for changes to take effect.

> The fix must be re-applied after each official FM26 patch/update, as Steam re-installs the original files during updates.

---

## What the fix changes

| Scope | New saves | Existing saves |
|---|---|---|
| Club names | Yes | No (requires new save) |
| Competition names | Yes | Yes |
| Award names | Yes | Yes |
| Stadium names | Yes | Yes |

---

## Building from source

Requires [Flutter](https://flutter.dev) with desktop support enabled.

```bash
# macOS
flutter build macos

# Windows
flutter build windows

# Linux
flutter build linux
```

---

## Development

```bash
# Run on current platform
flutter run -d macos   # or windows / linux

# Run tests
flutter test

# Analyze code
flutter analyze
```

---

## License

MIT
