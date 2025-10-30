//
//  WindowManager.swift
//  LightAndroidDevTools
//
//  Window management utilities
//

import AppKit
import SwiftUI

/// Manages window sizing and positioning
struct WindowManager {

    /// Configure window for compact mode
    static func configureCompactMode(window: NSWindow, screen: NSScreen) {
        let newSize = NSSize(width: AppConfig.Window.compactWidth, height: AppConfig.Window.compactHeight)
        window.setContentSize(newSize)

        let screenFrame = screen.visibleFrame
        let x = screenFrame.maxX - newSize.width
        let y = screenFrame.maxY - newSize.height
        window.setFrameOrigin(NSPoint(x: x, y: y))
        window.level = .floating
    }

    /// Configure window for full mode
    static func configureFullMode(window: NSWindow, screen: NSScreen) {
        let newSize = NSSize(width: AppConfig.Window.fullWidth, height: AppConfig.Window.fullHeight)
        window.setContentSize(newSize)

        let screenFrame = screen.visibleFrame
        let x = screenFrame.midX - newSize.width / 2
        let y = screenFrame.midY - newSize.height / 2
        window.setFrameOrigin(NSPoint(x: x, y: y))
        window.level = .normal
    }

    /// Setup window close button to terminate app
    static func setupCloseButton(window: NSWindow) {
        window.standardWindowButton(.closeButton)?.target = NSApp
        window.standardWindowButton(.closeButton)?.action = #selector(NSApplication.terminate(_:))
    }
}
