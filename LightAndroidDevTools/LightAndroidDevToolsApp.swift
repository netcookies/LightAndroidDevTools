import SwiftUI

@main
struct LightAndroidDevToolsApp: App {
    @State private var isCompactMode = UserDefaults.standard.bool(forKey: "isCompactMode")

    var body: some Scene {
        WindowGroup {
            ContentView(isCompactMode: $isCompactMode)
            .onAppear {
                let compact = UserDefaults.standard.bool(forKey: "isCompactMode")
                if let window = NSApplication.shared.windows.first {
                    if (compact) {
                        window.setContentSize(NSSize(width: 500, height: 85))
                        window.level = .floating
                    } else {
                        window.setContentSize(NSSize(width: 900, height: 650))
                        window.level = .normal
                    }
                    window.standardWindowButton(.closeButton)?.target = NSApp
                    window.standardWindowButton(.closeButton)?.action = #selector(NSApplication.terminate(_:))
                }
            }
            .onChange(of: isCompactMode) {
                UserDefaults.standard.set(isCompactMode, forKey: "isCompactMode")
                if let window = NSApplication.shared.windows.first,
                   let screen = window.screen ?? NSScreen.main {

                    if isCompactMode {
                        let newSize = NSSize(width: 500, height: 85)
                        window.setContentSize(newSize)

                        let screenFrame = screen.visibleFrame
                        let x = screenFrame.maxX - newSize.width
                        let y = screenFrame.maxY - newSize.height
                        window.setFrameOrigin(NSPoint(x: x, y: y))
                        window.level = .floating
                    } else {
                        let newSize = NSSize(width: 900, height: 650)
                        window.setContentSize(newSize)

                        if let screen = window.screen ?? NSScreen.main {
                            let screenFrame = screen.visibleFrame
                            let x = screenFrame.midX - newSize.width / 2
                            let y = screenFrame.midY - newSize.height / 2
                            window.setFrameOrigin(NSPoint(x: x, y: y))
                        }
                        window.level = .normal
                    }
                }
            }
        }
    }
}

enum LogType {
    case normal
    case error
    case success
}

struct ContentView: View {
    @State private var avdList: [String] = []
    @State private var selectedAVD: String?
    @State private var projectPath: String = ""
    @State private var buildType: String = "debug"
    @State private var isRunning = false
    @State private var logOutput: [LogLine] = [LogLine(text: "准备就绪")]
    @State private var selectedAppModule: String = "app"
    @Binding var isCompactMode: Bool
    @State private var detectedModules: [String] = []
    @State private var emulatorRunning = false
    @State private var emulatorCheckTimer: Timer?
    @State private var isScanningWireless = false
    @State private var activeProcesses: Set<UUID> = []
    @State private var lastTaskSuccess: Bool? = nil
    @State private var scrollToEnd = false
    
    private let maxLogLines = 1000
    private let logTrimThreshold = 1200
    
    private let defaults = UserDefaults.standard
    private let projectPathKey = "projectPath"
    private let buildTypeKey = "buildType"
    private let appModuleKey = "selectedAppModule"
    
    var body: some View {
        Group {
            if isCompactMode {
                compactView
            } else {
                fullView
            }
        }
        .onAppear {
            loadSettings()
            refreshAVDList()
            startEmulatorStatusCheck()
        }
        .onDisappear {
            cleanupTimer()
            cleanupAllProcesses()
        }
        .onChange(of: isCompactMode) {
            startEmulatorStatusCheck()
            if !isCompactMode {
                scrollToEnd = true
            }
        }
        .onChange(of: projectPath) {
            saveSettings()
            detectModules()
        }
        .onChange(of: buildType) {
            saveSettings()
        }
        .onChange(of: selectedAppModule) {
            saveSettings()
        }
    }
    
    private func cleanupTimer() {
        emulatorCheckTimer?.invalidate()
        emulatorCheckTimer = nil
    }
    
    private func cleanupAllProcesses() {
        activeProcesses.removeAll()
    }
    
    var fullView: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("项目路径")
                            .font(.caption)
                            .foregroundColor(.gray)
                        HStack {
                            TextField("选择项目目录", text: $projectPath)
                                .textFieldStyle(.roundedBorder)
                            Button(action: selectProjectPath) {
                                Text("选择").frame(width: 50)
                            }
                        }
                    }
                }
                
                HStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("设备")
                            .font(.caption)
                            .foregroundColor(.gray)
                        Picker("", selection: $selectedAVD) {
                            Text("选择设备").tag(nil as String?)
                            ForEach(avdList, id: \.self) { avd in
                                Text(avd).tag(avd as String?)
                            }
                        }
                        .frame(maxWidth: .infinity)
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("构建类型")
                            .font(.caption)
                            .foregroundColor(.gray)
                        Picker("", selection: $buildType) {
                            Text("Debug").tag("debug")
                            Text("Release").tag("release")
                        }
                        .pickerStyle(.segmented)
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("应用模块")
                            .font(.caption)
                            .foregroundColor(.gray)
                        Picker("", selection: $selectedAppModule) {
                            ForEach(detectedModules.isEmpty ? ["app"] : detectedModules, id: \.self) { module in
                                Text(module).tag(module)
                            }
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
            }
            .padding(16)
            .background(Color(.controlBackgroundColor))
            .border(.gray.opacity(0.3), width: 1)
            
            HStack(spacing: 12) {
                Button(action: refreshAVDList) {
                    HStack {
                        Image(systemName: "arrow.clockwise")
                        Text("刷新设备")
                    }
                }
                
                Button(action: startAVD) {
                    HStack {
                        Image(systemName: emulatorRunning ? "stop.circle.fill" : "play.fill")
                        Text(emulatorRunning ? "关闭模拟器" : "启动模拟器")
                    }
                }
                .disabled(selectedAVD == nil)
                
                Button(action: buildProject) {
                    HStack {
                        Image(systemName: "hammer.fill")
                        Text("编译")
                    }
                }
                .disabled(projectPath.isEmpty || isRunning)
                
                Button(action: buildAndRun) {
                    HStack {
                        Image(systemName: "play.circle.fill")
                        Text("编译并运行")
                    }
                }
                .disabled(projectPath.isEmpty || selectedAVD == nil || isRunning)
                
                Button(action: buildAPK) {
                    HStack {
                        Image(systemName: "shippingbox.fill")
                        Text("编译APK")
                    }
                }
                .disabled(projectPath.isEmpty || isRunning)
                
                Button(action: installAPK) {
                    HStack {
                        Image(systemName: "arrow.down.circle.fill")
                        Text("安装APK")
                    }
                }
                .disabled(projectPath.isEmpty || isRunning)
                
                Spacer()
                
                if isRunning {
                    HStack(spacing: 6) {
                        ProgressView()
                            .scaleEffect(0.8)
                        Text("运行中...")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                } else if let success = lastTaskSuccess {
                    HStack(spacing: 6) {
                        Image(systemName: success ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .foregroundColor(success ? .green : .red)
                            .font(.system(size: 16))
                        Text(success ? "完成" : "失败")
                            .font(.caption)
                            .foregroundColor(success ? .green : .red)
                    }
                }
                
                Button(action: { isCompactMode = true }) {
                    Image(systemName: "sidebar.left")
                }
            }
            .padding(12)
            .background(Color(.controlBackgroundColor))
            .border(.gray.opacity(0.3), width: 1)
            
            LogOutputView(logOutput: $logOutput, scrollToEnd: $scrollToEnd)
        }
    }
    
    var compactView: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Button(action: refreshAVDList) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 14))
                }
                .help("刷新设备")
                
                Button(action: startAVD) {
                    Image(systemName: emulatorRunning ? "stop.circle.fill" : "play.fill")
                        .font(.system(size: 14))
                }
                .disabled(selectedAVD == nil)
                .help(emulatorRunning ? "关闭模拟器" : "启动模拟器")
                
                Button(action: buildProject) {
                    Image(systemName: "hammer.fill")
                        .font(.system(size: 14))
                }
                .disabled(projectPath.isEmpty || isRunning)
                .help("编译")
                
                Button(action: buildAndRun) {
                    Image(systemName: "play.circle.fill")
                        .font(.system(size: 14))
                }
                .disabled(projectPath.isEmpty || selectedAVD == nil || isRunning)
                .help("编译并运行")
                
                Button(action: buildAPK) {
                    Image(systemName: "shippingbox.fill")
                        .font(.system(size: 14))
                }
                .disabled(projectPath.isEmpty || isRunning)
                .help("编译APK")
                
                Button(action: installAPK) {
                    Image(systemName: "arrow.down.circle.fill")
                        .font(.system(size: 14))
                }
                .disabled(projectPath.isEmpty || isRunning)
                .help("安装APK")
                
                Spacer()
                
                if isRunning {
                    ProgressView()
                        .scaleEffect(0.7)
                } else if let success = lastTaskSuccess {
                    Image(systemName: success ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundColor(success ? .green : .red)
                        .font(.system(size: 14))
                        .help(success ? "完成" : "失败")
                }
                
                Picker("", selection: $selectedAVD) {
                    Text("选择").tag(nil as String?)
                    ForEach(avdList, id: \.self) { avd in
                        Text(avd).tag(avd as String?)
                    }
                }
                .font(.caption)
                .frame(width: 100)
                .disabled(isRunning)
                
                Button(action: { isCompactMode = false }) {
                    Image(systemName: "sidebar.right")
                        .font(.system(size: 14))
                }
                .help("展开")
            }
            .padding(8)
        }
    }
    
    struct LogOutputView: View {
        @Binding var logOutput: [LogLine]
        @Binding var scrollToEnd: Bool
        
        @State private var visibleFrames: [UUID: CGRect] = [:]
        @State private var scrollViewSize: CGSize = .zero
        
        var body: some View {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("日志输出 (\(logOutput.count) 行)")
                        .font(.caption)
                        .foregroundColor(.gray)
                    Spacer()
                    Button("复制当前显示内容", action: copyVisibleLogs)
                        .font(.caption)
                    Button("清空", action: { logOutput.removeAll() })
                        .font(.caption)
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
                                withAnimation(.easeOut(duration: 0.2)) {
                                    scrollReader.scrollTo(lastLine.id, anchor: .bottom)
                                }
                            }
                        }
                        .onChange(of: scrollToEnd) {
                            if scrollToEnd, let lastLine = logOutput.last {
                                withAnimation(.easeOut(duration: 0.3)) {
                                    scrollReader.scrollTo(lastLine.id, anchor: .bottom)
                                }
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                    scrollToEnd = false
                                }
                            }
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

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
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
    
    private func selectProjectPath() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.message = "选择 Android 项目根目录"
        
        if panel.runModal() == .OK {
            projectPath = panel.urls.first?.path ?? ""
        }
    }
    
    private func refreshAVDList() {
        avdList.removeAll()

        let emulatorPath = NSHomeDirectory() + "/Library/Android/sdk/emulator/emulator"
        let adbPath = NSHomeDirectory() + "/Library/Android/sdk/platform-tools/adb"
        let androidHome = NSHomeDirectory() + "/Library/Android/sdk"

        let listAVDsCmd = "\(emulatorPath) -list-avds"
        let listDevicesCmd = "\(adbPath) devices | grep -v 'List' | awk '{print $1}'"

        let task = Process()
        task.launchPath = "/bin/bash"
        task.environment = ProcessInfo.processInfo.environment.merging(["ANDROID_HOME": androidHome]) { _, new in new }
        task.arguments = ["-i", "-c", "\(listAVDsCmd); echo; \(listDevicesCmd)"]

        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = pipe

        do {
            try task.run()
            task.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let output = String(data: data, encoding: .utf8) {
                let lines = output.split(separator: "\n").map(String.init).filter { !$0.isEmpty }
                avdList = lines
                if !avdList.isEmpty {
                    if selectedAVD == nil {
                        selectedAVD = avdList[0]
                    }
                    log("✓ 找到设备: \(avdList.joined(separator: ", "))")
                } else {
                    log("⚠️ 未找到任何设备")
                }
            }

            DispatchQueue.global().async {
                let adbPath = NSHomeDirectory() + "/Library/Android/sdk/platform-tools/adb"
                refreshWirelessDevices(adbPath: adbPath)
            }
        } catch {
            log("❌ 错误：\(error.localizedDescription)", type: .error)
        }
    }
    
    private func startAVD() {
        guard let avd = selectedAVD else { return }
        
        if emulatorRunning {
            killEmulator()
        } else {
            launchEmulator(avd)
        }
    }
    
    private func launchEmulator(_ avd: String) {
        isRunning = true
        
        DispatchQueue.global().async {
            let emulatorPath = NSHomeDirectory() + "/Library/Android/sdk/emulator/emulator"
            let androidHome = NSHomeDirectory() + "/Library/Android/sdk"
            
            let task = Process()
            task.launchPath = "/bin/bash"
            task.environment = ProcessInfo.processInfo.environment.merging(["ANDROID_HOME": androidHome]) { _, new in new }
            task.arguments = ["-i", "-c", "\(emulatorPath) -avd \(avd) &"]
            
            do {
                try task.run()
                DispatchQueue.main.async {
                    log("✓ 正在启动模拟器: \(avd)")
                    isRunning = false
                    startEmulatorStatusCheck()
                }
            } catch {
                DispatchQueue.main.async {
                    log("❌ 启动失败：\(error.localizedDescription)", type: .error)
                    isRunning = false
                }
            }
        }
    }
    
    private func killEmulator() {
        isRunning = true
        
        DispatchQueue.global().async {
            let cmd = "pkill -f 'emulator.*-avd'"
            let task = Process()
            task.launchPath = "/bin/bash"
            task.arguments = ["-i", "-c", cmd]
            
            do {
                try task.run()
                task.waitUntilExit()
                DispatchQueue.main.async {
                    log("✓ 已关闭模拟器")
                    isRunning = false
                }
            } catch {
                DispatchQueue.main.async {
                    log("❌ 关闭失败：\(error.localizedDescription)", type: .error)
                    isRunning = false
                }
            }
        }
    }
    
    private func startEmulatorStatusCheck() {
        cleanupTimer()
        
        emulatorCheckTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            checkEmulatorStatus()
        }
        RunLoop.main.add(emulatorCheckTimer!, forMode: .common)
        checkEmulatorStatus()
    }
    
    private func checkEmulatorStatus() {
        DispatchQueue.global().async {
            let task = Process()
            task.launchPath = "/bin/bash"
            let adbPath = NSHomeDirectory() + "/Library/Android/sdk/platform-tools/adb"
            let androidHome = NSHomeDirectory() + "/Library/Android/sdk"
            
            task.environment = ProcessInfo.processInfo.environment.merging(["ANDROID_HOME": androidHome]) { _, new in new }
            task.arguments = ["-i", "-c", "\(adbPath) devices | grep emulator"]
            
            let pipe = Pipe()
            task.standardOutput = pipe
            task.standardError = Pipe()
            
            do {
                try task.run()
                task.waitUntilExit()
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                let output = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                
                DispatchQueue.main.async {
                    let isRunning = !output.isEmpty && output.contains("device") && !output.contains("offline")
                    emulatorRunning = isRunning
                }
            } catch {
                DispatchQueue.main.async {
                    emulatorRunning = false
                }
            }
        }
    }
    
    private func buildProject() {
        guard !projectPath.isEmpty else { return }
        isRunning = true
        
        DispatchQueue.global().async {
            executeCommand("cd \(projectPath) && ./gradlew compileDebugSources", label: "编译")
        }
    }
    
    private func buildAndRun() {
        guard !projectPath.isEmpty else { return }
        isRunning = true
        
        DispatchQueue.global().async {
            if let packageName = getPackageName() {
                let gradleTask = buildType == "debug" ? "installDebug" : "installRelease"
                let mainActivity = getMainActivity() ?? "MainActivity"
                let adbPath = NSHomeDirectory() + "/Library/Android/sdk/platform-tools/adb"
                let cmd = "cd \(projectPath) && ./gradlew \(gradleTask) && sleep 2 && \(adbPath) shell am start -n \(packageName)/.\(mainActivity)"
                executeCommand(cmd, label: "编译并运行")
            } else {
                DispatchQueue.main.async {
                    log("❌ 无法解析包名，请检查 build.gradle", type: .error)
                    isRunning = false
                }
            }
        }
    }
    
    private func buildAPK() {
        guard !projectPath.isEmpty else { return }
        isRunning = true
        
        DispatchQueue.global().async {
            let gradleTask = buildType == "debug" ? "assembleDebug" : "assembleRelease"
            executeCommand("cd \(projectPath) && ./gradlew \(gradleTask)", label: "编译APK")
        }
    }
    
    private func installAPK() {
        guard !projectPath.isEmpty else { return }
        isRunning = true

        DispatchQueue.global().async {
            let adbPath = NSHomeDirectory() + "/Library/Android/sdk/platform-tools/adb"
            let fileManager = FileManager.default

            // 确定 APK 搜索路径
            let apkSearchPath: String
            let buildVariant: String
            
            if buildType == "debug" {
                apkSearchPath = "\(projectPath)/\(selectedAppModule)/build/outputs/apk/debug"
                buildVariant = "debug"
            } else {
                apkSearchPath = "\(projectPath)/\(selectedAppModule)/release"
                buildVariant = "release"
            }

            // 查找最新的 APK 文件
            do {
                guard fileManager.fileExists(atPath: apkSearchPath) else {
                    DispatchQueue.main.async {
                        self.log("❌ APK 目录不存在: \(apkSearchPath)", type: .error)
                        self.log("💡 请先执行「编译APK」", type: .normal)
                        self.isRunning = false
                    }
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
                    DispatchQueue.main.async {
                        self.log("❌ 未找到 \(buildVariant.capitalized) APK", type: .error)
                        self.log("💡 请先执行「编译APK」", type: .normal)
                        self.isRunning = false
                    }
                    return
                }

                let apkPath = "\(apkSearchPath)/\(apkName)"
                DispatchQueue.main.async {
                    self.log("📦 找到 APK：\(apkPath)")
                }
                
                let installCmd = "\(adbPath) install -r \"\(apkPath)\""
                self.executeCommand(installCmd, label: "安装\(buildVariant.capitalized) APK")

            } catch {
                DispatchQueue.main.async {
                    self.log("❌ 无法读取APK目录: \(error.localizedDescription)", type: .error)
                    self.isRunning = false
                }
            }
        }
    }
    
    private func executeCommand(_ command: String, label: String) {
        let androidHome = NSHomeDirectory() + "/Library/Android/sdk"
        let processId = UUID()
        
        lastTaskSuccess = nil
        
        let task = Process()
        task.launchPath = "/bin/bash"
        task.environment = ProcessInfo.processInfo.environment.merging(["ANDROID_HOME": androidHome]) { _, new in new }
        task.arguments = ["-i", "-c", command]
        
        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        task.standardOutput = stdoutPipe
        task.standardError = stderrPipe
        
        let stdoutHandle = stdoutPipe.fileHandleForReading
        let stderrHandle = stderrPipe.fileHandleForReading
        
        DispatchQueue.main.async {
            activeProcesses.insert(processId)
        }
        
        stdoutHandle.readabilityHandler = { handle in
            let data = handle.availableData
            if !data.isEmpty, let output = String(data: data, encoding: .utf8) {
                let lines = output.split(separator: "\n").map(String.init)
                DispatchQueue.main.async {
                    self.appendLogs(lines, type: .normal)
                }
            }
        }
        
        stderrHandle.readabilityHandler = { handle in
            let data = handle.availableData
            if !data.isEmpty, let output = String(data: data, encoding: .utf8) {
                let lines = output.split(separator: "\n").map(String.init)
                DispatchQueue.main.async {
                    self.appendLogs(lines, type: .error)
                }
            }
        }
        
        do {
            try task.run()
            task.terminationHandler = { t in
                stdoutHandle.readabilityHandler = nil
                stderrHandle.readabilityHandler = nil
                
                DispatchQueue.main.async {
                    activeProcesses.remove(processId)
                    
                    let success = t.terminationStatus == 0
                    lastTaskSuccess = success
                    
                    if success {
                        log("✓ \(label) 完成", type: .success)
                    } else {
                        log("✗ \(label) 失败 (代码: \(t.terminationStatus))", type: .error)
                    }
                    isRunning = false
                }
            }
        } catch {
            stdoutHandle.readabilityHandler = nil
            stderrHandle.readabilityHandler = nil
            DispatchQueue.main.async {
                activeProcesses.remove(processId)
                lastTaskSuccess = false
                log("❌ 执行失败：\(error.localizedDescription)", type: .error)
                isRunning = false
            }
        }
    }
    
    private func appendLogs(_ lines: [String], type: LogType = .normal) {
        logOutput.append(contentsOf: lines.map { LogLine(text: $0, type: type) })
        
        if logOutput.count > logTrimThreshold {
            let removeCount = logOutput.count - maxLogLines
            logOutput.removeFirst(removeCount)
        }
    }
    
    private func log(_ message: String, type: LogType = .normal) {
        DispatchQueue.main.async {
            let timestamp = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
            let line = LogLine(text: "[\(timestamp)] \(message)", type: type)
            logOutput.append(line)
            
            if logOutput.count > logTrimThreshold {
                let removeCount = logOutput.count - maxLogLines
                logOutput.removeFirst(removeCount)
            }
        }
    }
    
    private func getPackageName() -> String? {
        let buildGradle = projectPath + "/\(selectedAppModule)/build.gradle"
        let buildGradleKts = projectPath + "/\(selectedAppModule)/build.gradle.kts"
        
        let filePath = FileManager.default.fileExists(atPath: buildGradle) ? buildGradle : buildGradleKts
        
        do {
            let content = try String(contentsOfFile: filePath, encoding: .utf8)
            
            if let match = content.range(of: "namespace\\s*=?\\s*['\\\"]([^'\\\"]+)['\\\"]", options: .regularExpression) {
                let str = String(content[match])
                let components = str.split(separator: "\"")
                if let packageName = components.dropFirst().first {
                    return String(packageName)
                }
            }
            
            if let match = content.range(of: "applicationId\\s*=?\\s*['\\\"]([^'\\\"]+)['\\\"]", options: .regularExpression) {
                let str = String(content[match])
                let components = str.split(separator: "\"")
                if let packageName = components.dropFirst().first {
                    return String(packageName)
                }
            }
        } catch {
            log("❌ 无法读取 build.gradle: \(error.localizedDescription)", type: .error)
        }
        
        return nil
    }
    
    private func getMainActivity() -> String? {
        let manifestPath = projectPath + "/\(selectedAppModule)/src/main/AndroidManifest.xml"
        
        do {
            let content = try String(contentsOfFile: manifestPath, encoding: .utf8)
            if let match = content.range(of: "android:name=\\\"([^\\\"]+\\.MainActivity)\\\"", options: .regularExpression) {
                let nameStr = String(content[match])
                if let activity = nameStr.split(separator: "\"").dropFirst().first {
                    return String(activity)
                }
            }
        } catch {
            return nil
        }
        
        return nil
    }
    
    private func loadSettings() {
        projectPath = defaults.string(forKey: projectPathKey) ?? ""
        buildType = defaults.string(forKey: buildTypeKey) ?? "debug"
        selectedAppModule = defaults.string(forKey: appModuleKey) ?? "app"
    }
    
    private func saveSettings() {
        defaults.set(projectPath, forKey: projectPathKey)
        defaults.set(buildType, forKey: buildTypeKey)
        defaults.set(selectedAppModule, forKey: appModuleKey)
    }
    
    private func detectModules() {
        guard !projectPath.isEmpty else {
            log("⚠️ 项目路径为空，无法扫描模块")
            return
        }

        let fileManager = FileManager.default
        do {
            let projectURL = URL(fileURLWithPath: projectPath)
            let contents = try fileManager.contentsOfDirectory(atPath: projectURL.path)
            var modules: [String] = []

            log("🔍 开始扫描模块目录：\(projectPath)")

            for item in contents {
                let fullURL = projectURL.appendingPathComponent(item)
                var isDir: ObjCBool = false

                if fileManager.fileExists(atPath: fullURL.path, isDirectory: &isDir), isDir.boolValue {
                    let buildGradleURL = fullURL.appendingPathComponent("build.gradle")
                    let buildGradleKtsURL = fullURL.appendingPathComponent("build.gradle.kts")

                    let hasGradle = fileManager.fileExists(atPath: buildGradleURL.path)
                    let hasGradleKts = fileManager.fileExists(atPath: buildGradleKtsURL.path)

                    if hasGradle || hasGradleKts {
                        modules.append(item)
                        log("✓ 发现模块: \(item)")
                    }
                }
            }

            if !modules.isEmpty {
                detectedModules = modules.sorted()
                if !detectedModules.contains(selectedAppModule) {
                    selectedAppModule = detectedModules[0]
                }
            } else {
                log("⚠️ 未找到任何模块")
                detectedModules = []
            }
        } catch {
            log("⚠️ 无法扫描模块: \(error.localizedDescription)")
            detectedModules = []
        }
    }
    
    private func getOfflineWirelessDevices(adbPath: String) -> [String] {
        let task = Process()
        task.launchPath = "/bin/bash"
        task.arguments = ["-c", "\(adbPath) devices | grep 'offline' | awk '{print $1}'"]
        let pipe = Pipe()
        task.standardOutput = pipe
        try? task.run()
        task.waitUntilExit()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return output.split(separator: "\n").map(String.init).filter { !$0.isEmpty }
    }

    private func scanWirelessDevicesWithMDNS(completion: @escaping ([(String, String)]) -> Void) {
        DispatchQueue.global().async {
            let adbPath = NSHomeDirectory() + "/Library/Android/sdk/platform-tools/adb"
            let androidHome = NSHomeDirectory() + "/Library/Android/sdk"
            
            // 启用 Openscreen mDNS (macOS 已有 Bonjour，但 Openscreen 更可靠)
            var environment = ProcessInfo.processInfo.environment
            environment["ANDROID_HOME"] = androidHome
            environment["ADB_MDNS_OPENSCREEN"] = "1"
            
            // 重启 ADB 服务器以应用 mDNS 设置
            let killTask = Process()
            killTask.launchPath = "/bin/bash"
            killTask.environment = environment
            killTask.arguments = ["-c", "\(adbPath) kill-server"]
            killTask.standardOutput = Pipe()
            killTask.standardError = Pipe()
            
            do {
                try killTask.run()
                killTask.waitUntilExit()
                
                // 等待服务器关闭
                Thread.sleep(forTimeInterval: 0.5)
                
                // 启动 ADB 服务器并查询 mDNS 服务
                let mdnsTask = Process()
                mdnsTask.launchPath = "/bin/bash"
                mdnsTask.environment = environment
                mdnsTask.arguments = ["-c", "\(adbPath) start-server && sleep 1 && \(adbPath) mdns services"]
                
                let pipe = Pipe()
                mdnsTask.standardOutput = pipe
                mdnsTask.standardError = Pipe()
                
                try mdnsTask.run()
                mdnsTask.waitUntilExit()
                
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                guard let output = String(data: data, encoding: .utf8), !output.isEmpty else {
                    DispatchQueue.main.async {
                        self.log("⚠️ 未发现 mDNS 服务")
                    }
                    completion([])
                    return
                }
                
                DispatchQueue.main.async {
                    self.log("📡 mDNS 扫描结果：")
                    self.log(output)
                }
                
                // 解析 mDNS 服务列表
                // 格式示例：
                // List of discovered mdns services
                // adb-XXXXXX-YYYYYY _adb-tls-connect._tcp 192.168.1.100:37381
                var devices: [(String, String)] = []
                let lines = output.split(separator: "\n").map(String.init)
                
                for line in lines {
                    // 跳过标题行
                    if line.contains("List of discovered") || line.isEmpty {
                        continue
                    }
                    
                    // 匹配包含 IP:Port 的行
                    let components = line.split(separator: " ").map(String.init)
                    if components.count >= 3 {
                        // 查找 IP:Port 格式的部分
                        for component in components {
                            if component.contains(":") && component.contains(".") {
                                let parts = component.split(separator: ":")
                                if parts.count == 2 {
                                    let ip = String(parts[0])
                                    let port = String(parts[1])
                                    
                                    // 过滤 pairing 服务，只保留 connect 服务
                                    if line.contains("_adb-tls-connect") || line.contains("_adb._tcp") {
                                        devices.append((ip, port))
                                        DispatchQueue.main.async {
                                            self.log("✓ 发现设备: \(ip):\(port)")
                                        }
                                    }
                                }
                                break
                            }
                        }
                    }
                }
                
                DispatchQueue.main.async {
                    if devices.isEmpty {
                        self.log("⚠️ 未找到可连接的无线设备")
                        self.log("💡 提示：请确保设备已启用「无线调试」并已配对")
                    }
                    completion(devices)
                }
                
            } catch {
                DispatchQueue.main.async {
                    self.log("❌ mDNS 扫描失败: \(error.localizedDescription)", type: .error)
                }
                completion([])
            }
        }
    }
    
    private func refreshWirelessDevices(adbPath: String) {
        guard !isScanningWireless else {
            log("⚠️ 正在扫描无线设备，请稍后")
            return
        }
        
        isScanningWireless = true
        log("🔍 使用 mDNS 扫描无线 ADB 设备...")
        
        DispatchQueue.global().async {
            // 清理离线设备
            let disconnectedDevices = self.getOfflineWirelessDevices(adbPath: adbPath)
            
            for ip in disconnectedDevices {
                let disconnectCmd = "\(adbPath) disconnect \(ip)"
                let task = Process()
                task.launchPath = "/bin/bash"
                task.arguments = ["-c", disconnectCmd]
                task.standardOutput = Pipe()
                task.standardError = Pipe()
                try? task.run()
                task.waitUntilExit()
                DispatchQueue.main.async { self.log("⚠️ 已断开离线设备: \(ip)") }
            }
            
            // 使用官方 mDNS 扫描
            self.scanWirelessDevicesWithMDNS { devices in
                guard !devices.isEmpty else {
                    DispatchQueue.main.async {
                        self.log("✓ 扫描完成，未发现新设备")
                        self.isScanningWireless = false
                    }
                    return
                }

                DispatchQueue.main.async {
                    self.log("✓ 发现 \(devices.count) 个潜在无线设备")
                }

                func showNextDevice(_ index: Int) {
                    guard index < devices.count else {
                        DispatchQueue.main.async {
                            self.log("✓ 无线设备扫描完成")
                            self.isScanningWireless = false
                        }
                        return
                    }
                    
                    let (ip, port) = devices[index]
                    
                    DispatchQueue.main.async {
                        let alert = NSAlert()
                        alert.messageText = "发现无线调试设备"
                        alert.informativeText = "检测到设备 \(ip):\(port)\n是否连接此设备？"
                        alert.addButton(withTitle: "连接")
                        alert.addButton(withTitle: "跳过")
                        alert.alertStyle = .informational
                        
                        if let window = NSApplication.shared.windows.first {
                            alert.beginSheetModal(for: window) { response in
                                if response == .alertFirstButtonReturn {
                                    let connectCmd = "\(adbPath) connect \(ip):\(port)"
                                    DispatchQueue.global().async {
                                        let task = Process()
                                        task.launchPath = "/bin/bash"
                                        task.arguments = ["-c", connectCmd]
                                        let pipe = Pipe()
                                        task.standardOutput = pipe
                                        task.standardError = pipe
                                        
                                        do {
                                            try task.run()
                                            task.waitUntilExit()
                                            let output = try pipe.fileHandleForReading.readDataToEndOfFile()
                                            let result = String(data: output, encoding: .utf8) ?? ""
                                            
                                            DispatchQueue.main.async {
                                                if result.contains("connected") {
                                                    self.log("✅ 成功连接 \(ip):\(port)", type: .success)
                                                    self.refreshAVDList()
                                                } else {
                                                    self.log("⚠️ 连接 \(ip):\(port) 失败: \(result)")
                                                }
                                            }
                                        } catch {
                                            DispatchQueue.main.async {
                                                self.log("❌ 连接命令执行失败: \(error.localizedDescription)", type: .error)
                                            }
                                        }
                                    }
                                } else {
                                    DispatchQueue.main.async { self.log("⏭️ 已跳过 \(ip):\(port)") }
                                }
                                showNextDevice(index + 1)
                            }
                        } else {
                            showNextDevice(index + 1)
                        }
                    }
                }

                showNextDevice(0)
            }
        }
    }
}

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

struct LineFrameKey: PreferenceKey {
    static var defaultValue: [UUID: CGRect] = [:]
    static func reduce(value: inout [UUID: CGRect], nextValue: () -> [UUID: CGRect]) {
        value.merge(nextValue()) { $1 }
    }
}
