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
            emulatorCheckTimer?.invalidate()
            emulatorCheckTimer = nil
        }
        .onChange(of: isCompactMode) {
            startEmulatorStatusCheck()
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
                .disabled(selectedAVD == nil || isRunning)
                
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
                }
                
                Button(action: { isCompactMode = true }) {
                    Image(systemName: "sidebar.left")
                }
            }
            .padding(12)
            .background(Color(.controlBackgroundColor))
            .border(.gray.opacity(0.3), width: 1)
            
            LogOutputView(logOutput: $logOutput)
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
                .disabled(selectedAVD == nil || isRunning)
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
        
        @State private var visibleFrames: [UUID: CGRect] = [:]
        @State private var scrollViewSize: CGSize = .zero
        @State private var contentSize: CGSize = .zero
        @State private var scrollOffset: CGPoint = .zero
        
        var body: some View {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("日志输出")
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
                            VStack(alignment: .leading, spacing: 2) {
                                ForEach(logOutput) { line in
                                    Text(line.text)
                                        .font(.system(size: 14, weight: .regular, design: .monospaced))
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
                                        .id(line.id)  // ✅ 添加 id 以便滚动
                                }
                            }
                            .background(
                                GeometryReader { geo in
                                    Color.clear.preference(
                                        key: ContentSizeKey.self,
                                        value: geo.size
                                    )
                                }
                            )
                        }
                        .coordinateSpace(name: "scrollView")
                        .onPreferenceChange(LineFrameKey.self) { visibleFrames = $0 }
                        .onPreferenceChange(ContentSizeKey.self) { contentSize = $0 }
                        .onChange(of: logOutput.count) { _ in
                            // ✅ 日志更新时自动滚动到底部
                            if let lastLine = logOutput.last {
                                withAnimation {
                                    scrollReader.scrollTo(lastLine.id, anchor: .bottom)
                                }
                            }
                        }
                        .background(
                            GeometryReader { geo in
                                let currentSize = geo.size
                                Color.clear
                                    .onAppear {
                                        scrollViewSize = currentSize
                                    }
                                    .onChange(of: currentSize) { newSize in
                                        scrollViewSize = newSize
                                        // ✅ 窗口大小改变时，强制刷新 frame 计算
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                            // 触发视图重新布局，确保 visibleFrames 更新
                                        }
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
        
        private func copyVisibleLogs() {
            NSApplication.shared.activate(ignoringOtherApps: true)
            NSApp.mainWindow?.makeKeyAndOrderFront(nil)

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                // ✅ 使用最新的 scrollViewSize 构造可见区域
                let visibleRect = CGRect(
                    x: 0,
                    y: 0,
                    width: scrollViewSize.width,
                    height: scrollViewSize.height
                )
                
                print("📐 可见区域: \(visibleRect)")
                print("📦 Frame 数据: \(visibleFrames.count) 条")
                
                let visibleLines = logOutput.filter { line in
                    if let frame = visibleFrames[line.id] {
                        let isVisible = visibleRect.intersects(frame)
                        if isVisible {
                            print("✅ 可见: \(line.text.prefix(50)) - Frame: \(frame)")
                        }
                        return isVisible
                    }
                    return false
                }

                let textToCopy = visibleLines.map(\.text).joined(separator: "\n")
                guard !textToCopy.isEmpty else {
                    print("⚠️ 没有可见内容被捕获，复制中止")
                    print("   scrollViewSize: \(scrollViewSize)")
                    print("   visibleFrames count: \(visibleFrames.count)")
                    return
                }

                let pb = NSPasteboard.general
                pb.clearContents()
                let ok = pb.setString(textToCopy, forType: NSPasteboard.PasteboardType.string)
                print("✂️ 剪贴板写入结果: \(ok ? "成功" : "失败")")
                print("📋 复制了 \(visibleLines.count) 行，共 \(logOutput.count) 行")
            }
        }
    }

    // ✅ 新增 PreferenceKey
    struct ContentSizeKey: PreferenceKey {
        static var defaultValue: CGSize = .zero
        static func reduce(value: inout CGSize, nextValue: () -> CGSize) {
            value = nextValue()
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
            log("❌ 错误：\(error.localizedDescription)")
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
                    log("❌ 启动失败：\(error.localizedDescription)")
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
                    log("❌ 关闭失败：\(error.localizedDescription)")
                    isRunning = false
                }
            }
        }
    }
    
    private func startEmulatorStatusCheck() {
        emulatorCheckTimer?.invalidate()
        emulatorCheckTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            self.checkEmulatorStatus()
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
                    log("❌ 无法解析包名，请检查 build.gradle")
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

            if buildType == "debug" {
                let gradleTask = "installDebug"
                executeCommand("cd \(projectPath) && ./gradlew \(gradleTask)", label: "安装Debug APK")
                return
            }

            let releaseApkDir = "\(projectPath)/\(selectedAppModule)/build/outputs/apk/release"
            let cleanReleaseCmd = "rm -f \(releaseApkDir)/*.apk"
            executeCommand(cleanReleaseCmd, label: "清理旧APK")
            let assembleCmd = "cd \(projectPath) && ./gradlew :\(selectedAppModule):assembleRelease"
            log("⚙️ 开始编译 Release APK...")
            executeCommand(assembleCmd, label: "编译Release APK")

            let fileManager = FileManager.default

            do {
                let files = try fileManager.contentsOfDirectory(atPath: releaseApkDir)
                    .filter { $0.hasSuffix(".apk") }
                    .sorted { a, b in
                        let aTime = (try? fileManager.attributesOfItem(atPath: "\(releaseApkDir)/\(a)")[.modificationDate] as? Date) ?? .distantPast
                        let bTime = (try? fileManager.attributesOfItem(atPath: "\(releaseApkDir)/\(b)")[.modificationDate] as? Date) ?? .distantPast
                        return aTime > bTime
                    }

                guard let apkName = files.first else {
                    DispatchQueue.main.async {
                        log("❌ 未找到 Release APK，请检查是否编译成功")
                        isRunning = false
                    }
                    return
                }

                let apkPath = "\(releaseApkDir)/\(apkName)"
                log("📦 找到 APK：\(apkPath)")
                let installCmd = "\(adbPath) install -r \"\(apkPath)\""
                executeCommand(installCmd, label: "安装Release APK")

            } catch {
                DispatchQueue.main.async {
                    log("❌ 无法读取APK目录: \(error.localizedDescription)")
                    isRunning = false
                }
            }
        }
    }

    
    private func executeCommand(_ command: String, label: String) {
        let androidHome = NSHomeDirectory() + "/Library/Android/sdk"
        
        let task = Process()
        task.launchPath = "/bin/bash"
        task.environment = ProcessInfo.processInfo.environment.merging(["ANDROID_HOME": androidHome]) { _, new in new }
        task.arguments = ["-i", "-c", command]
        
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = pipe
        
        // 使用 readabilityHandler 替代轮询
        pipe.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            if !data.isEmpty, let output = String(data: data, encoding: .utf8) {
                let lines = output.split(separator: "\n").map(String.init)
                DispatchQueue.main.async {
                    logOutput.append(contentsOf: lines.map { LogLine(text: $0) })
                    if logOutput.count > 3000 {
                        logOutput.removeFirst(logOutput.count - 3000)
                    }
                }
            }
        }
        
        do {
            try task.run()
            task.terminationHandler = { t in
                DispatchQueue.main.async {
                    if t.terminationStatus == 0 {
                        log("✓ \(label) 完成")
                    } else {
                        log("✗ \(label) 失败 (代码: \(t.terminationStatus))")
                    }
                    isRunning = false
                }
                pipe.fileHandleForReading.readabilityHandler = nil
            }
        } catch {
            DispatchQueue.main.async {
                log("❌ 执行失败：\(error.localizedDescription)")
                isRunning = false
            }
        }
    }


    
    private func log(_ message: String) {
        DispatchQueue.main.async {
            let timestamp = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
            let line = LogLine(text: "[\(timestamp)] \(message)")
            logOutput.append(line)
            if logOutput.count > 3000 {
                logOutput.removeFirst(logOutput.count - 3000)
            }
        }
    }

    
    private func clearLog() {
        logOutput.removeAll()
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
            log("❌ 无法读取 build.gradle: \(error.localizedDescription)")
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

                    print("\(item): build.gradle=\(hasGradle), build.gradle.kts=\(hasGradleKts)")

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
    
    // 获取离线的无线设备 IP
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

    // 修改 scanWirelessDevices 版本，带回调返回新设备列表
    private func scanWirelessDevices(completion: @escaping ([(String, String)]) -> Void) {
        DispatchQueue.global().async {
            let ipTask = Process()
            ipTask.launchPath = "/bin/bash"
            ipTask.arguments = ["-c", "ipconfig getifaddr en0 || ipconfig getifaddr en1 || ipconfig getifaddr en2"]
            let ipPipe = Pipe()
            ipTask.standardOutput = ipPipe
            try? ipTask.run()
            ipTask.waitUntilExit()

            guard let data = try? ipPipe.fileHandleForReading.readToEnd(),
                  let ip = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !ip.isEmpty else {
                DispatchQueue.main.async { log("❌ 无法获取本地 IP") }
                return
            }

            let prefix = ip.split(separator: ".").dropLast().joined(separator: ".")
            let nmapCmd = "nmap -p 37000-49000 --open --min-rate 5000 --max-retries 2 --host-timeout 5s -oG - \(prefix).0/24 | awk '/open/{print $2, $5}'"
            let nmapTask = Process()
            nmapTask.launchPath = "/bin/bash"
            nmapTask.arguments = ["-c", nmapCmd]
            let pipe = Pipe()
            nmapTask.standardOutput = pipe
            nmapTask.standardError = pipe
            try? nmapTask.run()
            nmapTask.waitUntilExit()

            guard let output = try? pipe.fileHandleForReading.readToEnd(),
                  let text = String(data: output, encoding: .utf8),
                  !text.isEmpty else {
                DispatchQueue.main.async { log("❌ 未发现开放的无线调试端口") }
                completion([])
                return
            }

            let lines = text.split(separator: "\n")
            var devices: [(String, String)] = []
            for line in lines {
                let parts = line.split(separator: " ")
                if parts.count == 2 {
                    let ip = String(parts[0])
                    let port = parts[1].replacingOccurrences(of: "/open/tcp//", with: "")
                    devices.append((ip, port))
                }
            }

            DispatchQueue.main.async { completion(devices) }
        }
    }
    
    private func refreshWirelessDevices(adbPath: String) {
        guard !isScanningWireless else {
            log("⚠️ 正在扫描无线设备，请稍后")
            return
        }
        
        isScanningWireless = true
        
        DispatchQueue.global().async {
            let disconnectedDevices = getOfflineWirelessDevices(adbPath: adbPath)
            
            // 断开 offline 设备
            for ip in disconnectedDevices {
                let disconnectCmd = "\(adbPath) disconnect \(ip)"
                _ = try? Process.run(URL(fileURLWithPath: "/bin/bash"), arguments: ["-c", disconnectCmd])
                DispatchQueue.main.async { log("⚠️ 已断开离线设备: \(ip)") }
            }
            
            // 扫描新无线设备
            scanWirelessDevices { devices in
                guard !devices.isEmpty else {
                    DispatchQueue.main.async { self.isScanningWireless = false }
                    return
                }

                // 依次弹出非阻塞选择
                func showNextDevice(_ index: Int) {
                    guard index < devices.count else {
                        self.isScanningWireless = false
                        return
                    }
                    
                    let (ip, port) = devices[index]
                    
                    DispatchQueue.main.async {
                        let alert = NSAlert()
                        alert.messageText = "发现新无线设备"
                        alert.informativeText = "是否连接 \(ip):\(port)？"
                        alert.addButton(withTitle: "连接")
                        alert.addButton(withTitle: "取消")
                        
                        // 非阻塞显示
                        if let window = NSApplication.shared.windows.first {
                            alert.beginSheetModal(for: window) { response in
                                if response == .alertFirstButtonReturn {
                                    let connectCmd = "\(adbPath) connect \(ip):\(port)"
                                    DispatchQueue.global().async {
                                        _ = try? Process.run(URL(fileURLWithPath: "/bin/bash"), arguments: ["-c", connectCmd])
                                        DispatchQueue.main.async { log("✅ 已连接 \(ip):\(port)") }
                                    }
                                } else {
                                    DispatchQueue.main.async { log("⚠️ 忽略 \(ip):\(port)") }
                                }
                                // 弹出下一个
                                showNextDevice(index + 1)
                            }
                        } else {
                            // 如果没有 window，直接跳过
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
    
    // ✅ 实现 Hashable
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

// ✅ 新增 PreferenceKey
struct ContentSizeKey: PreferenceKey {
    static var defaultValue: CGSize = .zero
    static func reduce(value: inout CGSize, nextValue: () -> CGSize) {
        value = nextValue()
    }
}

#Preview {
    ContentView(isCompactMode: .constant(false))
}
