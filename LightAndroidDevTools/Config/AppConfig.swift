//
//  AppConfig.swift
//  LightAndroidDevTools
//
//  Configuration and constants for the application
//

import Foundation

/// Application-wide configuration
struct AppConfig {

    // MARK: - Window Dimensions

    struct Window {
        static let compactWidth: CGFloat = 333
        static let compactHeight: CGFloat = 70
        static let fullWidth: CGFloat = 900
        static let fullHeight: CGFloat = 650
    }

    // MARK: - UI Dimensions

    struct UI {
        static let iconFrameSize: CGFloat = 14
        static let controlHeight: CGFloat = 28
        static let cornerRadius: CGFloat = 6
        static let borderWidth: CGFloat = 0.5
        static let buttonPadding: CGFloat = 8
    }

    // MARK: - Log Management

    struct Log {
        static let maxLines: Int = 1000
        static let trimThreshold: Int = 1200
    }

    // MARK: - Android SDK Paths

    struct AndroidSDK {
        static let homeDirectory: String = NSHomeDirectory() + "/Library/Android/sdk"
        static let emulatorPath: String = homeDirectory + "/emulator/emulator"
        static let adbPath: String = homeDirectory + "/platform-tools/adb"
        static let buildToolsVersion: String = "36.0.0"
        static let buildToolsPath: String = homeDirectory + "/build-tools/\(buildToolsVersion)"
        static let zipalignPath: String = buildToolsPath + "/zipalign"
        static let apksignerPath: String = buildToolsPath + "/apksigner"
    }

    // MARK: - UserDefaults Keys

    struct UserDefaultsKeys {
        static let isCompactMode = "isCompactMode"
        static let projectPath = "projectPath"
        static let buildType = "buildType"
        static let selectedAppModule = "selectedAppModule"
        static let keystorePath = "keystorePath"
        static let keyAlias = "keyAlias"
        static let storePassword = "storePassword"
        static let keyPassword = "keyPassword"
    }

    // MARK: - Build Configuration

    struct Build {
        static let defaultModule = "app"
        static let debugBuildType = "debug"
        static let releaseBuildType = "release"
    }

    // MARK: - Timing

    struct Timing {
        static let emulatorCheckInterval: TimeInterval = 1.0
        static let taskTimerInterval: TimeInterval = 0.1
        static let adbRestartDelay: TimeInterval = 1.0
        static let mdnsInitDelay: TimeInterval = 2.0
        static let processKillDelay: TimeInterval = 0.5
        static let alertDelay: TimeInterval = 0.05
        static let scrollAnimationDuration: TimeInterval = 0.2
        static let scrollLongAnimationDuration: TimeInterval = 0.3
        static let scrollDebounceDelay: TimeInterval = 0.1
    }

    // MARK: - Process Management

    struct Process {
        static let shellPath = "/bin/bash"
        static let shellArgPrefix = "-i"
        static let shellArgCommand = "-c"
    }

    // MARK: - Dialog Dimensions

    struct Dialog {
        static let signingWidth: CGFloat = 500
        static let authWidth: CGFloat = 400
        static let authTextFieldWidth: CGFloat = 300
    }
}
