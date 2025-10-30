//
//  ButtonStyles.swift
//  LightAndroidDevTools
//
//  Custom button styles
//

import SwiftUI

// MARK: - Button Styles

struct ToolbarButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .frame(minWidth: 32, minHeight: AppConfig.UI.controlHeight)
            .padding(.horizontal, AppConfig.UI.buttonPadding)
            .background(
                RoundedRectangle(cornerRadius: AppConfig.UI.cornerRadius)
                    .fill(configuration.isPressed ? Color(NSColor.controlColor).opacity(0.5) : Color(NSColor.controlBackgroundColor))
            )
            .overlay(
                RoundedRectangle(cornerRadius: AppConfig.UI.cornerRadius)
                    .stroke(Color(NSColor.separatorColor), lineWidth: AppConfig.UI.borderWidth)
            )
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
            .opacity(isEnabled ? 1.0 : 0.5)
    }
}

struct CompactIconButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .frame(width: AppConfig.UI.controlHeight, height: AppConfig.UI.controlHeight)
            .background(
                RoundedRectangle(cornerRadius: 5)
                    .fill(configuration.isPressed ? Color(NSColor.controlColor).opacity(0.5) : Color(NSColor.controlBackgroundColor))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 5)
                    .stroke(Color(NSColor.separatorColor), lineWidth: AppConfig.UI.borderWidth)
            )
            .scaleEffect(configuration.isPressed ? 0.92 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
            .opacity(isEnabled ? 1.0 : 0.5)
    }
}

struct PrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.vertical, 7)
            .padding(.horizontal, 16)
            .background(
                RoundedRectangle(cornerRadius: AppConfig.UI.cornerRadius)
                    .fill(Color.accentColor.opacity(configuration.isPressed ? 0.8 : 1.0))
            )
            .foregroundColor(.white)
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
            .opacity(isEnabled ? 1.0 : 0.5)
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.vertical, 7)
            .padding(.horizontal, 16)
            .background(
                RoundedRectangle(cornerRadius: AppConfig.UI.cornerRadius)
                    .fill(configuration.isPressed ? Color(NSColor.controlColor).opacity(0.5) : Color(NSColor.controlBackgroundColor))
            )
            .overlay(
                RoundedRectangle(cornerRadius: AppConfig.UI.cornerRadius)
                    .stroke(Color(NSColor.separatorColor), lineWidth: 0.8)
            )
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
            .opacity(isEnabled ? 1.0 : 0.5)
    }
}

struct SmallButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.caption)
            .padding(.vertical, 5)
            .padding(.horizontal, 10)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(configuration.isPressed ? Color(NSColor.controlColor).opacity(0.5) : Color(NSColor.controlBackgroundColor))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .stroke(Color(NSColor.separatorColor), lineWidth: AppConfig.UI.borderWidth)
            )
            .scaleEffect(configuration.isPressed ? 0.94 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
            .opacity(isEnabled ? 1.0 : 0.5)
    }
}
