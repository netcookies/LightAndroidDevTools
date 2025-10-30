# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

LightAndroidDevTools is a macOS-native desktop application built with SwiftUI that provides a graphical interface for Android development tasks. It simplifies Android project building, emulator management, and APK deployment without requiring command-line interaction.

## Build and Run

```bash
# Build the project
xcodebuild -project LightAndroidDevTools.xcodeproj -scheme LightAndroidDevTools build

# Run the project (or use Xcode UI)
open LightAndroidDevTools.xcodeproj
# Then press Cmd+R in Xcode to build and run
```

## Architecture

### Single-File SwiftUI Application

The entire application is contained in a single Swift file: `LightAndroidDevTools/LightAndroidDevToolsApp.swift` (~1500 lines). This includes:

- **App Entry Point**: `LightAndroidDevToolsApp` struct managing window modes (compact/full)
- **Main View**: `ContentView` containing all UI and business logic
- **Nested Components**: `LogOutputView` for log display with virtual scrolling
- **Supporting Types**: `LogLine`, `LogType`, `LineFrameKey` for log management

### Dual-Mode UI Design

The app supports two window modes controlled by `isCompactMode` state:

1. **Full View** (900x650): Complete interface with all controls, settings, and log output
2. **Compact View** (500x85): Minimalist floating toolbar with essential buttons only

Window mode changes trigger dynamic resizing, repositioning, and window level changes (floating for compact mode).

### State Management

All state is managed using SwiftUI `@State` properties in `ContentView`:
- `avdList`, `selectedAVD`: Android Virtual Device management
- `projectPath`, `buildType`, `selectedAppModule`: Project configuration
- `logOutput`: Array of `LogLine` structs for real-time output
- `isRunning`, `emulatorRunning`: Task execution status
- Settings persistence via `UserDefaults` (project path, build type, module, keystore info)

### Android SDK Integration

The app interacts with Android SDK tools installed at `~/Library/Android/sdk`:

- **Emulator**: `~/Library/Android/sdk/emulator/emulator` - Launch AVDs
- **ADB**: `~/Library/Android/sdk/platform-tools/adb` - Device management, app installation
- **Build Tools**: `~/Library/Android/sdk/build-tools/36.0.0/` - APK signing (zipalign, apksigner)
- **Gradle**: Uses `./gradlew` wrapper from selected Android project

All commands are executed via `/bin/bash` with `ANDROID_HOME` environment variable set.

### Process Execution Patterns

Two execution modes for Android SDK commands:

1. **Async with Real-time Output** (`executeCommand`):
   - Uses `Pipe` with `readabilityHandler` for live stdout/stderr streaming
   - Logs appear in UI as command executes
   - Used for: build, install, run operations

2. **Synchronous with Blocking** (`executeCommandSync`):
   - Waits for completion with `task.waitUntilExit()`
   - Returns success boolean for sequential workflows
   - Used for: APK signing pipeline (zipalign → sign → verify)

Process lifecycle tracking via `activeProcesses` UUID set for cleanup on app termination.

### APK Signing Workflow

For release builds, the app implements a multi-step signing process:

1. User configures keystore via dialog (`showSigningDialog`)
2. Gradle builds unsigned APK: `assembleRelease`
3. `zipalign` optimizes APK alignment
4. `apksigner` signs with keystore credentials
5. `apksigner verify` validates signature
6. Cleanup of intermediate files (aligned APK, unsigned APK)

The workflow is executed sequentially using `executeCommandSync` to ensure each step completes before the next begins.

### Log Management System

Logs use a bounded circular buffer to prevent memory issues:
- Max lines: 1000 (hard limit)
- Trim threshold: 1200 (triggers cleanup)
- Auto-scroll to latest entries
- "Copy visible area" feature using `GeometryReader` to detect visible frames

Each log line is a `LogLine` struct with UUID, text, and type (normal/error/success) for color-coded display.

### mDNS Wireless Device Discovery

The app includes experimental wireless ADB device discovery:

1. Sets `ADB_MDNS_OPENSCREEN=1` environment variable
2. Restarts ADB server to enable mDNS
3. Executes `adb mdns services` to discover devices
4. Parses output for IP:port combinations
5. Presents modal dialogs to user for each discovered device
6. Connects via `adb connect <ip>:<port>`

Handles offline device cleanup by disconnecting stale connections.

### Module Detection

When a project path is selected, the app scans for Android modules:
- Searches subdirectories for `build.gradle` or `build.gradle.kts`
- Populates `detectedModules` array
- Auto-selects first module if current selection is invalid

### Package Name and Activity Resolution

Uses regex parsing of Gradle build files and AndroidManifest.xml:

- **Package Name**: Searches for `namespace` or `applicationId` in `build.gradle[.kts]`
- **Main Activity**: Parses `AndroidManifest.xml` for activity with `.MainActivity` in android:name

Required for launching apps after installation via `adb shell am start`.

### Emulator Status Polling

A `Timer` polls every 1 second to check emulator status:
- Executes `adb devices | grep emulator`
- Updates `emulatorRunning` state based on output
- Drives UI button state (play/stop icon)

Timer is cleaned up on view disappearance to prevent memory leaks.

## Key File Locations

- **Main Source**: `LightAndroidDevTools/LightAndroidDevToolsApp.swift`
- **Xcode Project**: `LightAndroidDevTools.xcodeproj`
- **Expected Android SDK**: `~/Library/Android/sdk` (hardcoded path)

## Development Notes

- The entire application logic is in a single file, making it easy to understand but potentially difficult to maintain as features grow
- Consider splitting into separate files if adding significant new features (e.g., Models/, Views/, Services/)
- All Android SDK paths are hardcoded to macOS default location
- The app requires Android SDK to be installed; no SDK bundling or path configuration UI
- Build tools version is hardcoded to `36.0.0` in signing workflow
- Passwords are stored in UserDefaults (not secure - consider Keychain for production)
