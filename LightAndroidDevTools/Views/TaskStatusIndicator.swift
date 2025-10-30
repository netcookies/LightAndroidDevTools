//
//  TaskStatusIndicator.swift
//  LightAndroidDevTools
//
//  Task status indicator components
//

import SwiftUI

// MARK: - Task Status Indicator (Full View)

struct TaskStatusIndicator: View {
    let isRunning: Bool
    let taskDuration: TimeInterval
    let lastTaskSuccess: Bool?
    let onStop: () -> Void

    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    var body: some View {
        Group {
            if isRunning {
                Button(action: onStop) {
                    HStack(spacing: 6) {
                        Text(formatDuration(taskDuration))
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundColor(.secondary)
                        Image(systemName: "stop.circle.fill")
                            .font(.system(size: 14))
                            .foregroundColor(.red)
                    }
                    .frame(height: AppConfig.UI.controlHeight)
                    .padding(.horizontal, 10)
                    .background(Color(.controlBackgroundColor))
                    .cornerRadius(AppConfig.UI.cornerRadius)
                    .overlay(
                        RoundedRectangle(cornerRadius: AppConfig.UI.cornerRadius)
                            .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
                .help("停止任务")
            } else if let success = lastTaskSuccess {
                HStack(spacing: 6) {
                    Image(systemName: success ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundColor(success ? .green : .red)
                        .font(.system(size: 16))
                    Text(success ? "完成" : "失败")
                        .font(.caption)
                        .foregroundColor(success ? .green : .red)
                }
                .frame(height: AppConfig.UI.controlHeight)
                .padding(.horizontal, 10)
                .background(Color(.controlBackgroundColor))
                .cornerRadius(AppConfig.UI.cornerRadius)
                .overlay(
                    RoundedRectangle(cornerRadius: AppConfig.UI.cornerRadius)
                        .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                )
            }
        }
    }
}

// MARK: - Compact Task Status Indicator

struct CompactTaskStatusIndicator: View {
    let isRunning: Bool
    let taskDuration: TimeInterval
    let lastTaskSuccess: Bool?
    let onStop: () -> Void

    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    var body: some View {
        Group {
            if isRunning {
                Button(action: onStop) {
                    HStack(spacing: 4) {
                        Text(formatDuration(taskDuration))
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundColor(.secondary)
                        Image(systemName: "stop.circle.fill")
                            .font(.system(size: 12))
                            .foregroundColor(.red)
                    }
                    .frame(height: AppConfig.UI.controlHeight)
                    .padding(.horizontal, 6)
                    .background(Color(.controlBackgroundColor))
                    .cornerRadius(4)
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
                .help("停止任务")
            } else if let success = lastTaskSuccess {
                Image(systemName: success ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .foregroundColor(success ? .green : .red)
                    .font(.system(size: 16))
                    .frame(width: AppConfig.UI.controlHeight, height: AppConfig.UI.controlHeight)
                    .help(success ? "完成" : "失败")
            }
        }
    }
}
