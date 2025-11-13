# Fix Dart Analysis Server Connection Issues

## What This Error Means

The Dart Analysis Server is the language server that provides code analysis, autocomplete, and error checking in your IDE. The error shows it's repeatedly crashing and failing to restart, which can cause:
- Loss of code completion
- Missing error highlighting
- Slow IDE performance

## Solutions (Try in Order)

### Solution 1: Restart Dart Analysis Server (Quickest)

**In VS Code:**
1. Press `Ctrl+Shift+P` (or `Cmd+Shift+P` on Mac)
2. Type: `Dart: Restart Analysis Server`
3. Press Enter

**Or:**
1. Open Command Palette (`Ctrl+Shift+P`)
2. Type: `Developer: Reload Window`
3. Press Enter

### Solution 2: Clean Flutter Project

Open terminal in your project root and run:

```bash
flutter clean
flutter pub get
```

This clears cached build files and refreshes dependencies.

### Solution 3: Clear Dart Analysis Server Cache

**Windows:**
1. Close VS Code
2. Delete this folder: `%APPDATA%\Dart-Code\analysis-server`
3. Restart VS Code

**Or manually:**
- Navigate to: `C:\Users\YourUsername\AppData\Roaming\Dart-Code\analysis-server`
- Delete the entire folder
- Restart VS Code

### Solution 4: Update Flutter and Dart Extensions

1. In VS Code, go to Extensions (`Ctrl+Shift+X`)
2. Search for "Dart" and "Flutter"
3. Click "Update" if updates are available
4. Restart VS Code

### Solution 5: Check for Large Files or Circular Dependencies

Sometimes very large files or circular imports can crash the analysis server. Check:
- Files over 1000 lines
- Circular import chains
- Syntax errors in recently edited files

### Solution 6: Increase Analysis Server Memory (If Needed)

If the project is very large, you may need to increase memory:

1. Open VS Code settings (`Ctrl+,`)
2. Search for: `dart.analysisServerFolding`
3. Add to `settings.json`:
```json
{
  "dart.analysisServerFolding": true,
  "dart.maxAnalysisIssues": 1000
}
```

### Solution 7: Reinstall Dart/Flutter Extensions

1. Uninstall "Dart" and "Flutter" extensions
2. Restart VS Code
3. Reinstall both extensions
4. Restart VS Code again

### Solution 8: Check Flutter/Dart SDK

Make sure your Flutter SDK is properly installed:

```bash
flutter doctor
```

Fix any issues shown.

## Quick Checklist

- [ ] Restart Analysis Server via Command Palette
- [ ] Run `flutter clean` and `flutter pub get`
- [ ] Clear analysis server cache folder
- [ ] Update Dart/Flutter extensions
- [ ] Restart VS Code completely
- [ ] Check `flutter doctor` for SDK issues

## If Nothing Works

1. Close VS Code completely
2. Delete `.dart_tool` folder in your project
3. Delete `analysis-server` cache folder
4. Run `flutter clean && flutter pub get`
5. Reopen VS Code

The analysis server should restart fresh and work properly.

