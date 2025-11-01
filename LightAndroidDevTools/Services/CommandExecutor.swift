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

    /// Stop all Gradle daemon processes to prevent lock contention
    nonisolated func stopGradleDaemons(projectPath: String, outputHandler: @escaping OutputHandler) {
        outputHandler(["🔍 检查 Gradle 守护进程..."], .normal)

        // First, try to stop daemons gracefully using gradlew
        let gracefulStopTask = createProcess(command: "cd \(projectPath) && ./gradlew --stop 2>&1")
        let stopPipe = Pipe()
        gracefulStopTask.standardOutput = stopPipe
        gracefulStopTask.standardError = stopPipe

        do {
            try gracefulStopTask.run()
            gracefulStopTask.waitUntilExit()

            if let output = String(data: stopPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8), !output.isEmpty {
                let lines = output.split(separator: "\n").map(String.init).filter { !$0.isEmpty }
                if !lines.isEmpty {
                    outputHandler(lines, .normal)
                }
            }

            if gracefulStopTask.terminationStatus == 0 {
                outputHandler(["✓ Gradle 守护进程已停止"], .success)
            }
        } catch {
            outputHandler(["⚠️ 停止 Gradle 守护进程时出错: \(error.localizedDescription)"], .normal)
        }

        // Wait a bit for daemons to fully terminate
        Thread.sleep(forTimeInterval: 0.5)

        // Additionally, forcefully kill any remaining Gradle daemon processes
        let killTask = createProcess(command: "pkill -f 'GradleDaemon' 2>/dev/null || true")
        try? killTask.run()
        killTask.waitUntilExit()

        outputHandler(["✓ Gradle 锁检查完成"], .success)
    }

    /// Check if Gradle lock files exist and optionally remove stale locks
    nonisolated func checkGradleLocks(outputHandler: @escaping OutputHandler) -> Bool {
        let gradleCachePath = NSHomeDirectory() + "/.gradle/caches"
        let fileManager = FileManager.default

        guard fileManager.fileExists(atPath: gradleCachePath) else {
            return true // No cache directory, no locks to worry about
        }

        // Check for journal lock
        let journalLockPath = gradleCachePath + "/journal-1/journal-1.lock"
        if fileManager.fileExists(atPath: journalLockPath) {
            // Check if lock file can be read (might indicate stale lock)
            do {
                let attributes = try fileManager.attributesOfItem(atPath: journalLockPath)
                if let modDate = attributes[.modificationDate] as? Date {
                    let age = Date().timeIntervalSince(modDate)
                    if age > 300 { // Lock older than 5 minutes might be stale
                        outputHandler(["⚠️ 检测到过期的 Gradle 锁文件 (已存在 \(Int(age/60)) 分钟)"], .normal)
                        return false
                    }
                }
            } catch {
                // Couldn't check lock attributes
            }
        }

        return true
    }

    // MARK: - Private Methods

    private nonisolated func createProcess(command: String) -> Process {
        // Cache config values to avoid actor isolation issues
        let shellPath = "/bin/bash"
        let shellArgPrefix = "-i"
        let shellArgCommand = "-c"
        let androidHome = NSHomeDirectory() + "/Library/Android/sdk"

        let task = Process()
        task.launchPath = shellPath
        task.environment = ProcessInfo.processInfo.environment.merging(
            ["ANDROID_HOME": androidHome]
        ) { _, new in new }
        task.arguments = [shellArgPrefix, shellArgCommand, command]
        return task
    }
}
