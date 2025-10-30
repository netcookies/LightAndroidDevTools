//
//  CustomControls.swift
//  LightAndroidDevTools
//
//  Custom UI controls
//

import SwiftUI

// MARK: - Unified TextField

struct UnifiedTextField: View {
    let placeholder: String
    @Binding var text: String

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: AppConfig.UI.cornerRadius)
                .fill(Color(NSColor.textBackgroundColor))
                .overlay(
                    RoundedRectangle(cornerRadius: AppConfig.UI.cornerRadius)
                        .stroke(Color(NSColor.separatorColor), lineWidth: AppConfig.UI.borderWidth)
                )

            TextField(placeholder, text: $text)
                .textFieldStyle(.plain)
                .padding(.horizontal, AppConfig.UI.buttonPadding)
        }
        .frame(height: AppConfig.UI.controlHeight)
    }
}

// MARK: - Unified Picker

struct UnifiedPicker<SelectionValue: Hashable, Content: View>: View {
    let selection: Binding<SelectionValue>
    let content: () -> Content
    let width: CGFloat?

    init(selection: Binding<SelectionValue>, width: CGFloat? = nil, @ViewBuilder content: @escaping () -> Content) {
        self.selection = selection
        self.width = width
        self.content = content
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: AppConfig.UI.cornerRadius)
                .fill(Color(NSColor.controlBackgroundColor))
                .overlay(
                    RoundedRectangle(cornerRadius: AppConfig.UI.cornerRadius)
                        .stroke(Color(NSColor.separatorColor), lineWidth: AppConfig.UI.borderWidth)
                )

            Picker("", selection: selection, content: content)
                .pickerStyle(.menu)
                .labelsHidden()
                .padding(.horizontal, 4)
        }
        .frame(width: width, height: AppConfig.UI.controlHeight)
    }
}

// MARK: - Unified Segmented Picker

struct UnifiedSegmentedPicker<SelectionValue: Hashable, Content: View>: View {
    let selection: Binding<SelectionValue>
    let content: () -> Content
    let width: CGFloat?

    init(selection: Binding<SelectionValue>, width: CGFloat? = nil, @ViewBuilder content: @escaping () -> Content) {
        self.selection = selection
        self.width = width
        self.content = content
    }

    var body: some View {
        Picker("", selection: selection, content: content)
            .pickerStyle(.segmented)
            .labelsHidden()
            .frame(width: width, height: AppConfig.UI.controlHeight)
    }
}
