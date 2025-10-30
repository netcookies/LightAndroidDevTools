//
//  CommandExecutor.swift
//  LightAndroidDevTools
//
//  Service for executing shell commands
//

import Foundation

/// Manages command execution with Android SDK environment
final class CommandExecutor: @unchecked Sendable {

    typealias OutputHandler = ([String], LogType) -> Void
    typealias CompletionHandler = (Bool) -> Void

    /// Execute a command asynchronously with real-time output
    func executeAsync(
        _ command: String,
        label: String,
        processId: UUID,
        outputHandler: @escaping OutputHandler,
        completionHandler: @escaping CompletionHandler
    ) -> Process {
        let task = createProcess(command: command)

        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        task.standardOutput = stdoutPipe
        task.standardError = stderrPipe

        let stdoutHandle = stdoutPipe.fileHandleForReading
        let stderrHandle = stderrPipe.fileHandleForReading

        // Real-time stdout handling
        stdoutHandle.readabilityHandler = { handle in
            let data = handle.availableData
            if !data.isEmpty, let output = String(data: data, encoding: .utf8) {
                let lines = output.split(separator: "\n").map(String.init)
                outputHandler(lines, .normal)
            }
        }

        // Real-time stderr handling
        stderrHandle.readabilityHandler = { handle in
            let data = handle.availableData
            if !data.isEmpty, let output = String(data: data, encoding: .utf8) {
                let lines = output.split(separator: "\n").map(String.init)
                outputHandler(lines, .error)
            }
        }

        task.terminationHandler = { t in
            stdoutHandle.readabilityHandler = nil
            stderrHandle.readabilityHandler = nil

            let success = t.terminationStatus == 0
            completionHandler(success)
        }

        do {
            try task.run()
        } catch {
            stdoutHandle.readabilityHandler = nil
            stderrHandle.readabilityHandler = nil
            outputHandler(["执行失败：\(error.localizedDescription)"], .error)
            completionHandler(false)
        }

        return task
    }

    /// Execute a command synchronously and wait for completion
    func executeSync(
        _ command: String,
        label: String,
        outputHandler: @escaping OutputHandler
    ) -> Bool {
        let task = createProcess(command: command)

        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        task.standardOutput = stdoutPipe
        task.standardError = stderrPipe

        let stdoutHandle = stdoutPipe.fileHandleForReading
        let stderrHandle = stderrPipe.fileHandleForReading

        outputHandler(["▶️ \(label)..."], .normal)

        // Real-time output handlers
        stdoutHandle.readabilityHandler = { handle in
            let data = handle.availableData
            if !data.isEmpty, let output = String(data: data, encoding: .utf8) {
                let lines = output.split(separator: "\n").map(String.init)
                outputHandler(lines, .normal)
            }
        }

        stderrHandle.readabilityHandler = { handle in
            let data = handle.availableData
            if !data.isEmpty, let output = String(data: data, encoding: .utf8) {
                let lines = output.split(separator: "\n").map(String.init)
                outputHandler(lines, .normal)
            }
        }

        do {
            try task.run()
            task.waitUntilExit()

            // Clean up handlers
            stdoutHandle.readabilityHandler = nil
            stderrHandle.readabilityHandler = nil

            // Read any remaining output
            let remainingStdout = stdoutHandle.readDataToEndOfFile()
            let remainingStderr = stderrHandle.readDataToEndOfFile()

            if !remainingStdout.isEmpty, let output = String(data: remainingStdout, encoding: .utf8) {
                let lines = output.split(separator: "\n").map(String.init)
                outputHandler(lines, .normal)
            }

            if !remainingStderr.isEmpty, let output = String(data: remainingStderr, encoding: .utf8) {
                let lines = output.split(separator: "\n").map(String.init)
                outputHandler(lines, .normal)
            }

            let success = task.terminationStatus == 0

            if success {
                outputHandler(["✓ \(label) 完成"], .success)
            } else {
                outputHandler(["✗ \(label) 失败 (代码: \(task.terminationStatus))"], .error)
            }

            return success
        } catch {
            stdoutHandle.readabilityHandler = nil
            stderrHandle.readabilityHandler = nil
            outputHandler(["❌ 执行失败：\(error.localizedDescription)"], .error)
            return false
        }
    }

    /// Kill a running process and its children
    func killProcess(_ process: Process) {
        guard process.isRunning else { return }

        let pid = process.processIdentifier

        // Use pkill to terminate process group
        let killTask = Process()
        killTask.launchPath = AppConfig.Process.shellPath
        killTask.arguments = [AppConfig.Process.shellArgCommand, "pkill -TERM -P \(pid); kill -TERM \(pid)"]
        try? killTask.run()
        killTask.waitUntilExit()

        // Wait for graceful exit
        Thread.sleep(forTimeInterval: AppConfig.Timing.processKillDelay)

        // Force terminate if still running
        if process.isRunning {
            process.terminate()
        }
    }

    // MARK: - Private Methods

    private func createProcess(command: String) -> Process {
        let task = Process()
        task.launchPath = AppConfig.Process.shellPath
        task.environment = ProcessInfo.processInfo.environment.merging(
            ["ANDROID_HOME": AppConfig.AndroidSDK.homeDirectory]
        ) { _, new in new }
        task.arguments = [AppConfig.Process.shellArgPrefix, AppConfig.Process.shellArgCommand, command]
        return task
    }
}
