//
//  LogLine.swift
//  LightAndroidDevTools
//
//  Data model for log output
//

import Foundation

/// Type of log message
enum LogType {
    case normal
    case error
    case success
}

/// A single line in the log output
struct LogLine: Identifiable, Hashable {
    let id = UUID()
    let text: String
    let type: LogType

    init(text: String, type: LogType = .normal) {
        self.text = text
        self.type = type
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: LogLine, rhs: LogLine) -> Bool {
        lhs.id == rhs.id
    }
}
