//
//  AppViewModel.swift
//  LightAndroidDevTools
//
//  Main view model managing application state and business logic
//

import SwiftUI
import Foundation
import Combine
import UniformTypeIdentifiers

@MainActor
class AppViewModel: ObservableObject {

    // MARK: - Published Properties

    @Published var avdList: [String] = []
    @Published var selectedAVD: String?
    @Published var detectedModules: [String] = []
    @Published var isRunning = false
    @Published var emulatorRunning = false
    @Published var lastTaskSuccess: Bool?
    @Published var scrollToEnd = false
    @Published var showSigningDialog = false
    @Published var showAuthDialog = false
    @Published var authCode = ""
    @Published var taskDuration: TimeInterval = 0
    @Published var isScanningWireless = false

    // MARK: - Services

    @ObservedObject var settings = AppSettings()
    @ObservedObject var logManager = LogManager()
    private let androidService = AndroidService()
    private let commandExecutor = CommandExecutor()

    // MARK: - Private Properties

    private var emulatorCheckTimer: Timer?
    private var taskDurationTimer: Timer?
    private var taskStartTime: Date?
    private var activeProcesses: Set<UUID> = []
    private var currentRunningProcess: Process?

    // MARK: - Initialization

    init() {
        loadInitialData()
    }

    // MARK: - Lifecycle Methods

    func onAppear() {
        startEmulatorStatusCheck()
    }

    func onDisappear() {
        cleanupTimer()
        cleanupAllProcesses()
    }

    func onProjectPathChange() {
        detectModules()
    }

    // MARK: - Public Methods

    func refreshAVDList() {
        avdList.removeAll()
        avdList = androidService.getAVDList()

        if !avdList.isEmpty {
            if selectedAVD == nil {
                selectedAVD = avdList[0]
            }
            logManager.log("✓ 找到设备: \(avdList.joined(separator: ", "))")
        } else {
            logManager.log("⚠️ 未找到任何设备")
        }

        Task {
            refreshWirelessDevices()
        }
    }

    func startAVD() {
        guard let avd = selectedAVD else { return }

        if emulatorRunning {
            killEmulator()
        } else {
            launchEmulator(avd)
        }
    }

    func buildProject() {
        guard !settings.projectPath.isEmpty else { return }
        isRunning = true

        Task {
            await prepareGradleEnvironment()
            let command = "cd \(settings.projectPath) && ./gradlew compileDebugSources"
            executeCommandAsync(command, label: "编译")
        }
    }

    func buildAndRun() {
        guard !settings.projectPath.isEmpty else { return }
        isRunning = true

        Task {
            await prepareGradleEnvironment()
            if let packageName = androidService.getPackageName(
                projectPath: settings.projectPath,
                module: settings.selectedAppModule
            ) {
                let gradleTask = settings.buildType == AppConfig.Build.debugBuildType ? "installDebug" : "installRelease"
                let mainActivity = androidService.getMainActivity(
                    projectPath: settings.projectPath,
                    module: settings.selectedAppModule
                ) ?? "MainActivity"

                let cmd = "cd \(settings.projectPath) && ./gradlew \(gradleTask) && sleep 2 && \(AppConfig.AndroidSDK.adbPath) shell am start -n \(packageName)/.\(mainActivity)"
                executeCommandAsync(cmd, label: "编译并运行")
            } else {
                logManager.log("❌ 无法解析包名,请检查 build.gradle", type: .error)
                isRunning = false
            }
        }
    }

    func buildAPK() {
        guard !settings.projectPath.isEmpty else { return }

        if settings.buildType == AppConfig.Build.releaseBuildType {
            showSigningDialog = true
        } else {
            isRunning = true
            Task {
                await prepareGradleEnvironment()
                let command = "cd \(settings.projectPath) && ./gradlew assembleDebug"
                executeCommandAsync(command, label: "编译Debug APK")
            }
        }
    }

    func buildAndSignRelease() {
        isRunning = true

        // Capture values needed for background work
        let projectPath = settings.projectPath
        let selectedModule = settings.selectedAppModule
        let keystorePath = settings.keystorePath
        let keyAlias = settings.keyAlias
        let storePassword = settings.storePassword
        let keyPassword = settings.keyPassword

        Task {
            await prepareGradleEnvironment()

            // Use executeAsync for real-time log output (like other build commands)
            let processId = UUID()
            let command = "cd \(projectPath) && ./gradlew assembleRelease"

            let process = commandExecutor.executeAsync(
                command,
                label: "编译Release APK",
                processId: processId
            ) { [weak self] lines, type in
                Task { @MainActor [weak self] in
                    self?.logManager.appendLogs(lines, type: type)
                }
            } completionHandler: { [weak self] success in
                Task { @MainActor [weak self] in
                    guard let self = self else { return }
                    self.activeProcesses.remove(processId)
                    self.currentRunningProcess = nil

                    if success {
                        self.logManager.log("✓ 编译Release APK 完成", type: .success)
                        // Now perform signing in background thread
                        Task.detached { [weak self] in
                            guard let self = self else { return }
                            await self.performSignAPK(
                                projectPath: projectPath,
                                selectedModule: selectedModule,
                                keystorePath: keystorePath,
                                keyAlias: keyAlias,
                                storePassword: storePassword,
                                keyPassword: keyPassword
                            )
                        }
                    } else {
                        self.logManager.log("✗ 编译Release APK 失败", type: .error)
                        self.isRunning = false
                        self.stopTaskTimer()
                    }
                }
            }

            activeProcesses.insert(processId)
            currentRunningProcess = process
            startTaskTimer()
        }
    }

    func installAPK() {
        guard !settings.projectPath.isEmpty else { return }
        isRunning = true

        Task {
            let adbPath = AppConfig.AndroidSDK.adbPath
            let fileManager = FileManager.default

            let apkSearchPath: String
            let buildVariant: String

            if settings.buildType == AppConfig.Build.debugBuildType {
                apkSearchPath = "\(settings.projectPath)/\(settings.selectedAppModule)/build/outputs/apk/debug"
                buildVariant = "debug"
            } else {
                apkSearchPath = "\(settings.projectPath)/\(settings.selectedAppModule)/release"
                buildVariant = "release"
            }

            do {
                guard fileManager.fileExists(atPath: apkSearchPath) else {
                    logManager.log("❌ APK 目录不存在: \(apkSearchPath)", type: .error)
                    logManager.log("💡 请先执行「编译APK」", type: .normal)
                    isRunning = false
                    return
                }

                let files = try fileManager.contentsOfDirectory(atPath: apkSearchPath)
                    .filter { $0.hasSuffix(".apk") }
                    .sorted { a, b in
                        let aTime = (try? fileManager.attributesOfItem(atPath: "\(apkSearchPath)/\(a)")[.modificationDate] as? Date) ?? .distantPast
                        let bTime = (try? fileManager.attributesOfItem(atPath: "\(apkSearchPath)/\(b)")[.modificationDate] as? Date) ?? .distantPast
                        return aTime > bTime
                    }

                guard let apkName = files.first else {
                    logManager.log("❌ 未找到 \(buildVariant.capitalized) APK", type: .error)
                    logManager.log("💡 请先执行「编译APK」", type: .normal)
                    isRunning = false
                    return
                }

                let apkPath = "\(apkSearchPath)/\(apkName)"
                logManager.log("📦 找到 APK：\(apkPath)")

                let installCmd = "\(adbPath) install -r \"\(apkPath)\""
                executeCommandAsync(installCmd, label: "安装\(buildVariant.capitalized) APK")

            } catch {
                logManager.log("❌ 无法读取APK目录: \(error.localizedDescription)", type: .error)
                isRunning = false
            }
        }
    }

    func performAuth() {
        guard !authCode.isEmpty else { return }
        isRunning = true

        let code = authCode
        authCode = ""

        Task {
            let command = "\(AppConfig.AndroidSDK.adbPath) shell input text \(code)"
            executeCommandAsync(command, label: "授权设备")
        }
    }

    func stopCurrentTask() {
        if let process = currentRunningProcess {
            commandExecutor.killProcess(process)
            logManager.log("⚠️ 已终止当前任务", type: .error)
            isRunning = false
            lastTaskSuccess = false
            currentRunningProcess = nil
            stopTaskTimer()
        }
    }

    func selectProjectPath() -> String? {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.message = "选择 Android 项目根目录"

        if panel.runModal() == .OK {
            return panel.urls.first?.path ?? ""
        }
        return nil
    }

    func selectKeystoreFile() -> String? {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowedContentTypes = [.item]
        panel.message = "选择 Keystore 文件 (.jks 或 .keystore)"

        if panel.runModal() == .OK {
            return panel.url?.path ?? ""
        }
        return nil
    }

    // MARK: - Private Methods

    private func loadInitialData() {
        refreshAVDList()
        detectModules()
    }

    /// Prepare Gradle environment by stopping existing daemons to prevent lock issues
    private nonisolated func prepareGradleEnvironment() async {
        let executor = await CommandExecutor()
        let projectPath = await self.settings.projectPath

        // Stop any existing Gradle daemons
        await withCheckedContinuation { continuation in
            executor.stopGradleDaemons(projectPath: projectPath) { [weak self] lines, type in
                Task { @MainActor [weak self] in
                    self?.logManager.appendLogs(lines, type: type)
                }
            }
            continuation.resume()
        }

        // Check for stale locks
        let locksOk = await withCheckedContinuation { continuation in
            let result = executor.checkGradleLocks { [weak self] lines, type in
                Task { @MainActor [weak self] in
                    self?.logManager.appendLogs(lines, type: type)
                }
            }
            continuation.resume(returning: result)
        }

        if !locksOk {
            await MainActor.run { [weak self] in
                self?.logManager.log("💡 提示: 如果构建仍然失败，请尝试在终端运行: ./gradlew --stop", type: .normal)
            }
        }
    }

    private func detectModules() {
        guard !settings.projectPath.isEmpty else {
            logManager.log("⚠️ 项目路径为空，无法扫描模块")
            return
        }

        logManager.log("🔍 开始扫描模块目录：\(settings.projectPath)")
        let modules = androidService.detectModules(projectPath: settings.projectPath)

        if !modules.isEmpty {
            detectedModules = modules
            for module in modules {
                logManager.log("✓ 发现模块: \(module)")
            }

            if !detectedModules.contains(settings.selectedAppModule) {
                settings.selectedAppModule = detectedModules[0]
            }
        } else {
            logManager.log("⚠️ 未找到任何模块")
            detectedModules = []
        }
    }

    private func launchEmulator(_ avd: String) {
        isRunning = true
        startTaskTimer()

        Task {
            if let _ = androidService.launchEmulator(avd) {
                logManager.log("✓ 正在启动模拟器: \(avd)")
                isRunning = false
                stopTaskTimer()
                startEmulatorStatusCheck()
            } else {
                logManager.log("❌ 启动失败", type: .error)
                isRunning = false
                stopTaskTimer()
            }
        }
    }

    private func killEmulator() {
        isRunning = true
        startTaskTimer()

        Task {
            let success = androidService.killEmulator()

            if success {
                logManager.log("✓ 已关闭模拟器")
            } else {
                logManager.log("❌ 关闭失败", type: .error)
            }
            isRunning = false
            stopTaskTimer()
        }
    }

    func startEmulatorStatusCheck() {
        cleanupTimer()

        emulatorCheckTimer = Timer.scheduledTimer(withTimeInterval: AppConfig.Timing.emulatorCheckInterval, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.checkEmulatorStatus()
            }
        }
        RunLoop.main.add(emulatorCheckTimer!, forMode: .common)
        checkEmulatorStatus()
    }

    private func checkEmulatorStatus() {
        Task {
            let isRunning = androidService.isEmulatorRunning()
            emulatorRunning = isRunning
        }
    }

    private func cleanupTimer() {
        emulatorCheckTimer?.invalidate()
        emulatorCheckTimer = nil
    }

    private func cleanupAllProcesses() {
        activeProcesses.removeAll()
    }

    private func startTaskTimer() {
        taskStartTime = Date()
        taskDuration = 0
        taskDurationTimer?.invalidate()
        taskDurationTimer = Timer.scheduledTimer(withTimeInterval: AppConfig.Timing.taskTimerInterval, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self = self, let startTime = self.taskStartTime else { return }
                self.taskDuration = Date().timeIntervalSince(startTime)
            }
        }
        RunLoop.main.add(taskDurationTimer!, forMode: .common)
    }

    private func stopTaskTimer() {
        taskDurationTimer?.invalidate()
        taskDurationTimer = nil
        taskStartTime = nil
        taskDuration = 0
    }

    private func executeCommandAsync(_ command: String, label: String) {
        let processId = UUID()
        lastTaskSuccess = nil

        let process = commandExecutor.executeAsync(
            command,
            label: label,
            processId: processId
        ) { [weak self] lines, type in
            Task { @MainActor [weak self] in
                self?.logManager.appendLogs(lines, type: type)
            }
        } completionHandler: { [weak self] success in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                self.activeProcesses.remove(processId)
                self.currentRunningProcess = nil
                self.stopTaskTimer()
                self.lastTaskSuccess = success

                if success {
                    self.logManager.log("✓ \(label) 完成", type: .success)
                } else {
                    self.logManager.log("✗ \(label) 失败", type: .error)
                }
                self.isRunning = false
            }
        }

        activeProcesses.insert(processId)
        currentRunningProcess = process
        startTaskTimer()
    }

    /// Perform APK signing in background thread (nonisolated to avoid blocking main thread)
    private nonisolated func performSignAPK(
        projectPath: String,
        selectedModule: String,
        keystorePath: String,
        keyAlias: String,
        storePassword: String,
        keyPassword: String
    ) async {
        // Create executor in background context
        let executor = await CommandExecutor()
        let buildToolsPath = await AppConfig.AndroidSDK.buildToolsPath
        let apkDir = "\(projectPath)/\(selectedModule)/build/outputs/apk/release"
        let releasePath = "\(projectPath)/\(selectedModule)/release"
        let unsignedAPK = "\(apkDir)/app-release-unsigned.apk"
        let alignedAPK = "\(apkDir)/app-release-aligned.apk"
        let finalAPK = "\(releasePath)/app-release.apk"
        let idsigFile = "\(finalAPK).idsig"

        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: unsignedAPK) else {
            await MainActor.run { [weak self] in
                self?.logManager.log("❌ 未找到未签名的APK: \(unsignedAPK)", type: .error)
                self?.isRunning = false
                self?.stopTaskTimer()
            }
            return
        }

        await MainActor.run { [weak self] in
            self?.logManager.log("✓ 找到未签名APK，开始签名流程")
            self?.logManager.log("🧹 清理旧的签名文件...")
        }

        // Cleanup old files
        do {
            if fileManager.fileExists(atPath: alignedAPK) {
                try fileManager.removeItem(atPath: alignedAPK)
                await MainActor.run { [weak self] in
                    self?.logManager.log("✓ 已删除旧的对齐文件")
                }
            }

            if fileManager.fileExists(atPath: finalAPK) {
                try fileManager.removeItem(atPath: finalAPK)
                await MainActor.run { [weak self] in
                    self?.logManager.log("✓ 已删除旧的签名文件")
                }
            }

            if fileManager.fileExists(atPath: idsigFile) {
                try fileManager.removeItem(atPath: idsigFile)
                await MainActor.run { [weak self] in
                    self?.logManager.log("✓ 已删除旧的签名临时文件")
                }
            }
        } catch {
            await MainActor.run { [weak self] in
                self?.logManager.log("⚠️ 清理旧文件时出错: \(error.localizedDescription)", type: .error)
            }
        }

        // Step 1: zipalign
        let zipalignSuccess = await executor.executeSync(
            "\(buildToolsPath)/zipalign -v -p 4 \"\(unsignedAPK)\" \"\(alignedAPK)\"",
            label: "对齐APK"
        ) { [weak self] lines, type in
            Task { @MainActor [weak self] in
                self?.logManager.appendLogs(lines, type: type)
            }
        }

        guard zipalignSuccess else {
            await MainActor.run { [weak self] in
                self?.logManager.log("❌ APK对齐失败", type: .error)
                self?.isRunning = false
                self?.stopTaskTimer()
            }
            return
        }

        // Step 2: Sign
        let signSuccess = await executor.executeSync(
            "\(buildToolsPath)/apksigner sign --ks \"\(keystorePath)\" --ks-key-alias \"\(keyAlias)\" --ks-pass pass:\(storePassword) --key-pass pass:\(keyPassword) --out \"\(finalAPK)\" \"\(alignedAPK)\"",
            label: "签名APK"
        ) { [weak self] lines, type in
            Task { @MainActor [weak self] in
                self?.logManager.appendLogs(lines, type: type)
            }
        }

        guard signSuccess else {
            await MainActor.run { [weak self] in
                self?.logManager.log("❌ APK签名失败", type: .error)
                self?.isRunning = false
                self?.stopTaskTimer()
            }
            return
        }

        // Step 3: Verify
        let verifySuccess = await executor.executeSync(
            "\(buildToolsPath)/apksigner verify \"\(finalAPK)\"",
            label: "验证签名"
        ) { [weak self] lines, type in
            Task { @MainActor [weak self] in
                self?.logManager.appendLogs(lines, type: type)
            }
        }

        await MainActor.run { [weak self] in
            guard let self = self else { return }

            if verifySuccess {
                self.logManager.log("✅ APK签名成功!", type: .success)
                self.logManager.log("📦 文件位置: \(finalAPK)")

                // Cleanup intermediate files
                do {
                    let fileManager = FileManager.default
                    if fileManager.fileExists(atPath: alignedAPK) {
                        try fileManager.removeItem(atPath: alignedAPK)
                    }
                    if fileManager.fileExists(atPath: unsignedAPK) {
                        try fileManager.removeItem(atPath: unsignedAPK)
                    }
                    self.logManager.log("✓ 已清理临时文件")
                } catch {
                    self.logManager.log("⚠️ 清理临时文件失败: \(error.localizedDescription)")
                }
                self.lastTaskSuccess = true
            } else {
                self.logManager.log("⚠️ 签名验证失败", type: .error)
                self.lastTaskSuccess = false
            }
            self.isRunning = false
            self.stopTaskTimer()
        }
    }

    private func refreshWirelessDevices() {
        // Implementation for wireless device scanning would go here
        // This is a placeholder - the full mDNS implementation from original file
        // can be moved here if needed
    }
}
