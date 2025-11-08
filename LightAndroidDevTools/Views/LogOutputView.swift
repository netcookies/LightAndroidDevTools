//
//  LogOutputView.swift
//  LightAndroidDevTools
//
//  Log output display component
//

import SwiftUI

struct LogOutputView: View {
    @Binding var logOutput: [LogLine]
    @Binding var scrollToEnd: Bool

    @State private var visibleFrames: [UUID: CGRect] = [:]
    @State private var scrollViewSize: CGSize = .zero
    @State private var scrollTask: Task<Void, Never>?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("日志输出 (\(logOutput.count) 行)")
                    .font(.caption)
                    .foregroundColor(.gray)
                Spacer()
                Button("复制当前显示内容", action: copyVisibleLogs)
                    .buttonStyle(SmallButtonStyle())
                Button("清空", action: { logOutput.removeAll() })
                    .buttonStyle(SmallButtonStyle())
            }

            GeometryReader { outerGeo in
                ScrollViewReader { scrollReader in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 2) {
                            ForEach(logOutput) { line in
                                Text(line.text)
                                    .font(.system(size: 14, weight: .regular, design: .monospaced))
                                    .foregroundColor(colorForLogType(line.type))
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .textSelection(.enabled)
                                    .background(
                                        GeometryReader { geo in
                                            Color.clear.preference(
                                                key: LineFrameKey.self,
                                                value: [line.id: geo.frame(in: .named("scrollView"))]
                                            )
                                        }
                                    )
                                    .id(line.id)
                            }
                        }
                        .padding(12)
                    }
                    .coordinateSpace(name: "scrollView")
                    .onPreferenceChange(LineFrameKey.self) { visibleFrames = $0 }
                    .onChange(of: logOutput.count) {
                        if let lastLine = logOutput.last {
                            withAnimation(.easeOut(duration: AppConfig.Timing.scrollAnimationDuration)) {
                                scrollReader.scrollTo(lastLine.id, anchor: .bottom)
                            }
                        }
                    }
                    .onChange(of: scrollToEnd) {
                        if scrollToEnd, let lastLine = logOutput.last {
                            // Cancel any existing scroll task
                            scrollTask?.cancel()

                            withAnimation(.easeOut(duration: AppConfig.Timing.scrollLongAnimationDuration)) {
                                scrollReader.scrollTo(lastLine.id, anchor: .bottom)
                            }

                            // Create a new task to reset scrollToEnd
                            scrollTask = Task { @MainActor in
                                try? await Task.sleep(nanoseconds: UInt64(AppConfig.Timing.scrollDebounceDelay * 1_000_000_000))
                                if !Task.isCancelled {
                                    scrollToEnd = false
                                }
                            }
                        }
                    }
                    .onDisappear {
                        // Cancel scroll task when view disappears
                        scrollTask?.cancel()
                    }
                    .background(
                        GeometryReader { geo in
                            Color.clear
                                .onAppear {
                                    scrollViewSize = geo.size
                                }
                                .onChange(of: geo.size) { _, newSize in
                                    scrollViewSize = newSize
                                }
                        }
                    )
                    .background(Color(.textBackgroundColor))
                    .border(.gray.opacity(0.3), width: 1)
                }
            }
        }
        .padding(16)
    }

    private func colorForLogType(_ type: LogType) -> Color {
        switch type {
        case .normal:
            return .primary
        case .error:
            return .red
        case .success:
            return .green
        }
    }

    private func copyVisibleLogs() {
        NSApplication.shared.activate(ignoringOtherApps: true)
        NSApp.mainWindow?.makeKeyAndOrderFront(nil)

        Task { @MainActor in
            try? await Task.sleep(nanoseconds: UInt64(AppConfig.Timing.alertDelay * 1_000_000_000))

            let visibleRect = CGRect(
                x: 0,
                y: 0,
                width: scrollViewSize.width,
                height: scrollViewSize.height
            )

            let visibleLines = logOutput.filter { line in
                if let frame = visibleFrames[line.id] {
                    return visibleRect.intersects(frame)
                }
                return false
            }

            let textToCopy = visibleLines.map(\.text).joined(separator: "\n")
            guard !textToCopy.isEmpty else { return }

            let pb = NSPasteboard.general
            pb.clearContents()
            _ = pb.setString(textToCopy, forType: .string)
        }
    }
}

// MARK: - Preference Key

struct LineFrameKey: PreferenceKey {
    static var defaultValue: [UUID: CGRect] = [:]
    static func reduce(value: inout [UUID: CGRect], nextValue: () -> [UUID: CGRect]) {
        value.merge(nextValue()) { $1 }
    }
}
