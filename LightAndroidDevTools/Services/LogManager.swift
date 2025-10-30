//
//  LogManager.swift
//  LightAndroidDevTools
//
//  Service for managing log output
//

import Foundation
import Combine

/// Manages log output with automatic trimming
class LogManager: ObservableObject {
    @Published var logOutput: [LogLine] = [LogLine(text: "准备就绪")]

    /// Add a single log message
    func log(_ message: String, type: LogType = .normal) {
        let timestamp = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
        let line = LogLine(text: "[\(timestamp)] \(message)", type: type)
        logOutput.append(line)
        trimIfNeeded()
    }

    /// Add multiple log lines
    func appendLogs(_ lines: [String], type: LogType = .normal) {
        logOutput.append(contentsOf: lines.map { LogLine(text: $0, type: type) })
        trimIfNeeded()
    }

    /// Clear all logs
    func clear() {
        logOutput.removeAll()
    }

    /// Trim logs if threshold is exceeded
    private func trimIfNeeded() {
        if logOutput.count > AppConfig.Log.trimThreshold {
            let removeCount = logOutput.count - AppConfig.Log.maxLines
            logOutput.removeFirst(removeCount)
        }
    }
}
