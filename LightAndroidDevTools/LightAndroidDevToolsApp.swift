import SwiftUI
internal import UniformTypeIdentifiers

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
                        window.setContentSize(NSSize(width: 650, height: 70))
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
                        let newSize = NSSize(width: 650, height: 70)
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

// MARK: - Button Styles

struct ToolbarButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .frame(minWidth: 32, minHeight: 28)
            .padding(.horizontal, 8)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(configuration.isPressed ? Color(NSColor.controlColor).opacity(0.5) : Color(NSColor.controlBackgroundColor))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(Color(NSColor.separatorColor), lineWidth: 0.5)
            )
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

struct CompactIconButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .frame(width: 28, height: 28)
            .background(
                RoundedRectangle(cornerRadius: 5)
                    .fill(configuration.isPressed ? Color(NSColor.controlColor).opacity(0.5) : Color(NSColor.controlBackgroundColor))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 5)
                    .stroke(Color(NSColor.separatorColor), lineWidth: 0.5)
            )
            .scaleEffect(configuration.isPressed ? 0.92 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.vertical, 7)
            .padding(.horizontal, 16)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.accentColor.opacity(configuration.isPressed ? 0.8 : 1.0))
            )
            .foregroundColor(.white)
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.vertical, 7)
            .padding(.horizontal, 16)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(configuration.isPressed ? Color(NSColor.controlColor).opacity(0.5) : Color(NSColor.controlBackgroundColor))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(Color(NSColor.separatorColor), lineWidth: 0.8)
            )
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

struct SmallButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.caption)
            .padding(.vertical, 5)
            .padding(.horizontal, 10)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(configuration.isPressed ? Color(NSColor.controlColor).opacity(0.5) : Color(NSColor.controlBackgroundColor))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .stroke(Color(NSColor.separatorColor), lineWidth: 0.5)
            )
            .scaleEffect(configuration.isPressed ? 0.94 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

struct ContentView: View {
    @State private var avdList: [String] = []
    @State private var selectedAVD: String?
    @State private var projectPath: String = ""
    @State private var buildType: String = "release"
    @State private var isRunning = false
    @State private var logOutput: [LogLine] = [LogLine(text: "准备就绪")]
    @State private var selectedAppModule: String = "app"
    @Binding var isCompactMode: Bool
    @State private var detectedModules: [String] = []
    @State private var emulatorRunning = false
    @State private var emulatorCheckTimer: Timer?
    @State private var isScanningWireless = false
    @State private var activeProcesses: Set<UUID> = []
    @State private var currentRunningProcess: Process?
    @State private var lastTaskSuccess: Bool? = nil
    @State private var scrollToEnd = false
    @State private var keystorePath: String = ""
    @State private var keyAlias: String = ""
    @State private var storePassword: String = ""
    @State private var keyPassword: String = ""
    @State private var showSigningDialog: Bool = false
    @State private var showAuthDialog: Bool = false
    @State private var authCode: String = ""
    @State private var taskStartTime: Date?
    @State private var taskDurationTimer: Timer?
    @State private var taskDuration: TimeInterval = 0

    private let maxLogLines = 1000
    private let logTrimThreshold = 1200
    private let iconFrameSize: CGFloat = 14
    private let controlHeight: CGFloat = 28

    private let defaults = UserDefaults.standard
    private let projectPathKey = "projectPath"
    private let buildTypeKey = "buildType"
    private let appModuleKey = "selectedAppModule"
    private let keystorePathKey = "keystorePath"
    private let keyAliasKey = "keyAlias"
    private let storePasswordKey = "storePassword"
    private let keyPasswordKey = "keyPassword"
    
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
        .sheet(isPresented: $showSigningDialog) {
            signingConfigDialog
        }
        .sheet(isPresented: $showAuthDialog) {
            authDialog
        }
    }
    
    private func cleanupTimer() {
        emulatorCheckTimer?.invalidate()
        emulatorCheckTimer = nil
    }

    private func cleanupAllProcesses() {
        activeProcesses.removeAll()
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    private func startTaskTimer() {
        taskStartTime = Date()
        taskDuration = 0
        taskDurationTimer?.invalidate()
        taskDurationTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            if let startTime = taskStartTime {
                taskDuration = Date().timeIntervalSince(startTime)
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
                                Text("选择")
                            }
                            .buttonStyle(SecondaryButtonStyle())
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
                        .frame(width: 325)
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
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.clockwise")
                            .frame(width: iconFrameSize, height: iconFrameSize)
                        Text("刷新设备")
                    }
                }
                .buttonStyle(ToolbarButtonStyle())

                Button(action: startAVD) {
                    HStack(spacing: 4) {
                        Image(systemName: emulatorRunning ? "stop.circle.fill" : "play.fill")
                            .frame(width: iconFrameSize, height: iconFrameSize)
                        Text(emulatorRunning ? "关闭模拟器" : "启动模拟器")
                    }
                }
                .buttonStyle(ToolbarButtonStyle())
                .disabled(selectedAVD == nil)

                Button(action: buildProject) {
                    HStack(spacing: 4) {
                        Image(systemName: "hammer.fill")
                            .frame(width: iconFrameSize, height: iconFrameSize)
                        Text("编译")
                    }
                }
                .buttonStyle(ToolbarButtonStyle())
                .disabled(projectPath.isEmpty || isRunning)

                Button(action: buildAndRun) {
                    HStack(spacing: 4) {
                        Image(systemName: "play.circle.fill")
                            .frame(width: iconFrameSize, height: iconFrameSize)
                        Text("编译并运行")
                    }
                }
                .buttonStyle(ToolbarButtonStyle())
                .disabled(projectPath.isEmpty || selectedAVD == nil || isRunning)

                Button(action: buildAPK) {
                    HStack(spacing: 4) {
                        Image(systemName: "shippingbox.fill")
                            .frame(width: iconFrameSize, height: iconFrameSize)
                        Text("编译APK")
                    }
                }
                .buttonStyle(ToolbarButtonStyle())
                .disabled(projectPath.isEmpty || isRunning)

                Button(action: installAPK) {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.down.circle.fill")
                            .frame(width: iconFrameSize, height: iconFrameSize)
                        Text("安装APK")
                    }
                }
                .buttonStyle(ToolbarButtonStyle())
                .disabled(projectPath.isEmpty || isRunning)

                Button(action: { showAuthDialog = true }) {
                    HStack(spacing: 4) {
                        Image(systemName: "key.fill")
                            .frame(width: iconFrameSize, height: iconFrameSize)
                        Text("授权")
                    }
                }
                .buttonStyle(ToolbarButtonStyle())
                .disabled(isRunning)

                Spacer()

                if isRunning {
                    Button(action: stopCurrentTask) {
                        HStack(spacing: 6) {
                            Text(formatDuration(taskDuration))
                                .font(.system(size: 13, design: .monospaced))
                                .foregroundColor(.secondary)
                            Image(systemName: "stop.circle.fill")
                                .foregroundColor(.red)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Color(.controlBackgroundColor))
                        .cornerRadius(6)
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
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
                }

                Button(action: { isCompactMode = true }) {
                    Image(systemName: "sidebar.left")
                        .frame(width: iconFrameSize, height: iconFrameSize)
                }
                .buttonStyle(CompactIconButtonStyle())
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color(.controlBackgroundColor))
            .border(.gray.opacity(0.3), width: 1)
            
            LogOutputView(logOutput: $logOutput, scrollToEnd: $scrollToEnd)
        }
    }
    
    var compactView: some View {
        VStack(spacing: 6) {
            // 第一行：操作按钮
            HStack(spacing: 8) {
                Button(action: buildProject) {
                    Image(systemName: "hammer.fill")
                        .frame(width: iconFrameSize, height: iconFrameSize)
                }
                .buttonStyle(CompactIconButtonStyle())
                .disabled(projectPath.isEmpty || isRunning)
                .help("编译")

                Button(action: buildAndRun) {
                    Image(systemName: "play.circle.fill")
                        .frame(width: iconFrameSize, height: iconFrameSize)
                }
                .buttonStyle(CompactIconButtonStyle())
                .disabled(projectPath.isEmpty || selectedAVD == nil || isRunning)
                .help("编译并运行")

                Button(action: buildAPK) {
                    Image(systemName: "shippingbox.fill")
                        .frame(width: iconFrameSize, height: iconFrameSize)
                }
                .buttonStyle(CompactIconButtonStyle())
                .disabled(projectPath.isEmpty || isRunning)
                .help("编译APK")

                Button(action: installAPK) {
                    Image(systemName: "arrow.down.circle.fill")
                        .frame(width: iconFrameSize, height: iconFrameSize)
                }
                .buttonStyle(CompactIconButtonStyle())
                .disabled(projectPath.isEmpty || isRunning)
                .help("安装APK")

                Button(action: { showAuthDialog = true }) {
                    Image(systemName: "key.fill")
                        .frame(width: iconFrameSize, height: iconFrameSize)
                }
                .buttonStyle(CompactIconButtonStyle())
                .disabled(isRunning)
                .help("授权")

                Spacer()

                if isRunning {
                    Button(action: stopCurrentTask) {
                        HStack(spacing: 4) {
                            Text(formatDuration(taskDuration))
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundColor(.secondary)
                            Image(systemName: "stop.circle.fill")
                                .font(.system(size: 12))
                                .foregroundColor(.red)
                        }
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
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
                        .font(.system(size: 14))
                        .help(success ? "完成" : "失败")
                }

                Button(action: { isCompactMode = false }) {
                    Image(systemName: "sidebar.right")
                        .frame(width: iconFrameSize, height: iconFrameSize)
                }
                .buttonStyle(CompactIconButtonStyle())
                .help("展开")
            }
            .padding(.horizontal, 16)
            .padding(.top, 6)

            // 第二行：设备选择器
            HStack(spacing: 8) {
                Button(action: refreshAVDList) {
                    Image(systemName: "arrow.clockwise")
                        .frame(width: iconFrameSize, height: iconFrameSize)
                }
                .buttonStyle(CompactIconButtonStyle())
                .help("刷新设备")

                Button(action: startAVD) {
                    Image(systemName: emulatorRunning ? "stop.circle.fill" : "play.fill")
                        .frame(width: iconFrameSize, height: iconFrameSize)
                }
                .buttonStyle(CompactIconButtonStyle())
                .disabled(selectedAVD == nil)
                .help(emulatorRunning ? "关闭模拟器" : "启动模拟器")

                Picker("", selection: $selectedAVD) {
                    Text("选择设备").tag(nil as String?)
                    ForEach(avdList, id: \.self) { avd in
                        Text(avd).tag(avd as String?)
                    }
                }
                .font(.caption)
                .frame(maxWidth: .infinity)
                .disabled(isRunning)

                Picker("", selection: $buildType) {
                    Text("Debug").tag("debug")
                    Text("Release").tag("release")
                }
                .pickerStyle(.segmented)
                .frame(width: 120)
                .disabled(isRunning)
                .help("构建类型")
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 6)
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
    
    var signingConfigDialog: some View {
        VStack(spacing: 20) {
            Text("Release APK 签名配置")
                .font(.headline)

            VStack(alignment: .leading, spacing: 10) {
                Text("Keystore 路径:")
                HStack {
                    TextField("选择 keystore 文件", text: $keystorePath)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                    Button("浏览") {
                        selectKeystoreFile()
                    }
                    .buttonStyle(SecondaryButtonStyle())
                }

                Text("Key Alias:")
                TextField("输入 key alias", text: $keyAlias)
                    .textFieldStyle(RoundedBorderTextFieldStyle())

                Text("Store Password:")
                SecureField("输入 store 密码", text: $storePassword)
                    .textFieldStyle(RoundedBorderTextFieldStyle())

                Text("Key Password:")
                SecureField("输入 key 密码", text: $keyPassword)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
            }

            HStack {
                Button("取消") {
                    showSigningDialog = false
                }
                .buttonStyle(SecondaryButtonStyle())

                Button("开始构建并签名") {
                    showSigningDialog = false
                    saveSettings()
                    buildAndSignRelease()
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(keystorePath.isEmpty || keyAlias.isEmpty ||
                         storePassword.isEmpty || keyPassword.isEmpty)
            }
        }
        .padding()
        .frame(width: 500)
    }

    var authDialog: some View {
        VStack(spacing: 20) {
            Text("ADB 设备授权")
                .font(.headline)

            Text("请在设备上查看授权码，并在下方输入：")
                .font(.caption)
                .foregroundColor(.gray)

            TextField("输入授权码", text: $authCode)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .frame(width: 300)

            HStack {
                Button("取消") {
                    showAuthDialog = false
                    authCode = ""
                }
                .buttonStyle(SecondaryButtonStyle())

                Button("授权") {
                    showAuthDialog = false
                    performAuth(code: authCode)
                    authCode = ""
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(authCode.isEmpty)
            }
        }
        .padding()
        .frame(width: 400)
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

    private func stopCurrentTask() {
        if let process = currentRunningProcess, process.isRunning {
            // 获取进程ID并终止整个进程组
            let pid = process.processIdentifier

            // 使用 pkill 终止进程组中的所有进程
            let killTask = Process()
            killTask.launchPath = "/bin/bash"
            killTask.arguments = ["-c", "pkill -TERM -P \(pid); kill -TERM \(pid)"]
            try? killTask.run()
            killTask.waitUntilExit()

            // 等待一小段时间让进程优雅退出
            Thread.sleep(forTimeInterval: 0.5)

            // 如果进程仍在运行，强制终止
            if process.isRunning {
                process.terminate()
            }

            log("⚠️ 已终止当前任务", type: .error)
            isRunning = false
            lastTaskSuccess = false
            currentRunningProcess = nil
            stopTaskTimer()
        }
    }

    private func performAuth(code: String) {
        isRunning = true

        DispatchQueue.global().async {
            let adbPath = NSHomeDirectory() + "/Library/Android/sdk/platform-tools/adb"
            let command = "\(adbPath) shell input text \(code)"
            executeCommand(command, label: "授权设备")
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
        
        if buildType == "release" {
            // Release 版本先显示签名配置对话框
            showSigningDialog = true
        } else {
            // Debug 版本直接构建
            isRunning = true
            DispatchQueue.global().async {
                executeCommand("cd \(projectPath) && ./gradlew assembleDebug", label: "编译Debug APK")
            }
        }
    }

    private func buildAndSignRelease() {
        isRunning = true
        
        DispatchQueue.global().async {
            // 同步执行构建
            let success = self.executeCommandSync("cd \(self.projectPath) && ./gradlew assembleRelease", label: "编译Release APK")
            
            if success {
                // 构建成功后再签名
                self.signAPK()
            } else {
                DispatchQueue.main.async {
                    self.log("❌ 编译失败，取消签名", type: .error)
                    self.isRunning = false
                }
            }
        }
    }

    private func signAPK() {
        let buildToolsPath = NSHomeDirectory() + "/Library/Android/sdk/build-tools/36.0.0"
        let apkDir = "\(projectPath)/\(selectedAppModule)/build/outputs/apk/release"
        let releasePath = "\(projectPath)/\(selectedAppModule)/release"
        let unsignedAPK = "\(apkDir)/app-release-unsigned.apk"
        let alignedAPK = "\(apkDir)/app-release-aligned.apk"
        let finalAPK = "\(releasePath)/app-release.apk"
        let idsigFile = "\(finalAPK).idsig"

        // 检查未签名的 APK 是否存在
        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: unsignedAPK) else {
            DispatchQueue.main.async {
                self.log("❌ 未找到未签名的APK: \(unsignedAPK)", type: .error)
                self.isRunning = false
            }
            return
        }
        
        DispatchQueue.main.async {
            self.log("✓ 找到未签名APK，开始签名流程")
        }
        
        // 第零步：清理旧文件
        DispatchQueue.main.async {
            self.log("🧹 清理旧的签名文件...")
        }
        
        do {
            // 删除旧的 aligned APK
            if fileManager.fileExists(atPath: alignedAPK) {
                try fileManager.removeItem(atPath: alignedAPK)
                DispatchQueue.main.async {
                    self.log("✓ 已删除旧的对齐文件")
                }
            }
            
            // 删除旧的 signed APK
            if fileManager.fileExists(atPath: finalAPK) {
                try fileManager.removeItem(atPath: finalAPK)
                DispatchQueue.main.async {
                    self.log("✓ 已删除旧的签名文件")
                }
            }
            
            // 删除旧的 signed APK idsig
            if fileManager.fileExists(atPath: idsigFile) {
                try fileManager.removeItem(atPath: idsigFile)
                DispatchQueue.main.async {
                    self.log("✓ 已删除旧的签名临时文件")
                }
            }
        } catch {
            DispatchQueue.main.async {
                self.log("⚠️ 清理旧文件时出错: \(error.localizedDescription)", type: .error)
                // 继续执行，不中断流程
            }
        }
        
        // 第一步：zipalign 对齐
        let zipalignSuccess = executeCommandSync(
            "\(buildToolsPath)/zipalign -v -p 4 \"\(unsignedAPK)\" \"\(alignedAPK)\"",
            label: "对齐APK"
        )
        
        guard zipalignSuccess else {
            DispatchQueue.main.async {
                self.log("❌ APK对齐失败", type: .error)
                self.isRunning = false
            }
            return
        }
        
        // 第二步：签名
        let signSuccess = executeCommandSync(
            "\(buildToolsPath)/apksigner sign --ks \"\(keystorePath)\" --ks-key-alias \"\(keyAlias)\" --ks-pass pass:\(storePassword) --key-pass pass:\(keyPassword) --out \"\(finalAPK)\" \"\(alignedAPK)\"",
            label: "签名APK"
        )
        
        guard signSuccess else {
            DispatchQueue.main.async {
                self.log("❌ APK签名失败", type: .error)
                self.isRunning = false
            }
            return
        }
        
        // 第三步：验证签名
        let verifySuccess = executeCommandSync(
            "\(buildToolsPath)/apksigner verify \"\(finalAPK)\"",
            label: "验证签名"
        )
        
        DispatchQueue.main.async {
            if verifySuccess {
                self.log("✅ APK签名成功!", type: .success)
                self.log("📦 文件位置: \(finalAPK)")

                // 清理中间文件
                do {
                    if fileManager.fileExists(atPath: alignedAPK) {
                        try fileManager.removeItem(atPath: alignedAPK)
                    }
                    if fileManager.fileExists(atPath: unsignedAPK) {
                        try fileManager.removeItem(atPath: unsignedAPK)
                    }
                    self.log("✓ 已清理临时文件")
                } catch {
                    self.log("⚠️ 清理临时文件失败: \(error.localizedDescription)")
                }
                self.lastTaskSuccess = true
            } else {
                self.log("⚠️ 签名验证失败", type: .error)
                self.lastTaskSuccess = false
            }
            self.isRunning = false
        }
    }
    
    private func selectKeystoreFile() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowedContentTypes = [.item]
        panel.message = "选择 Keystore 文件 (.jks 或 .keystore)"
        
        if panel.runModal() == .OK {
            if let url = panel.url {
                keystorePath = url.path
            }
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
            self.activeProcesses.insert(processId)
            self.currentRunningProcess = task
            self.startTaskTimer()
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
                    self.activeProcesses.remove(processId)
                    self.currentRunningProcess = nil
                    self.stopTaskTimer()

                    let success = t.terminationStatus == 0
                    self.lastTaskSuccess = success

                    if t.terminationReason == .exit {
                        if success {
                            self.log("✓ \(label) 完成", type: .success)
                        } else {
                            self.log("✗ \(label) 失败 (代码: \(t.terminationStatus))", type: .error)
                        }
                    } else {
                        self.log("⚠️ \(label) 已被终止", type: .error)
                    }
                    self.isRunning = false
                }
            }
        } catch {
            stdoutHandle.readabilityHandler = nil
            stderrHandle.readabilityHandler = nil
            DispatchQueue.main.async {
                self.activeProcesses.remove(processId)
                self.currentRunningProcess = nil
                self.stopTaskTimer()
                self.lastTaskSuccess = false
                self.log("❌ 执行失败：\(error.localizedDescription)", type: .error)
                self.isRunning = false
            }
        }
    }
    
    private func executeCommandSync(_ command: String, label: String) -> Bool {
        let androidHome = NSHomeDirectory() + "/Library/Android/sdk"
        
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
            self.log("▶️ \(label)...")
        }
        
        // 使用 readabilityHandler 实时读取输出
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
                    // Gradle 的 WARNING 也算正常输出，不用红色
                    self.appendLogs(lines, type: .normal)
                }
            }
        }
        
        do {
            try task.run()
            task.waitUntilExit() // 等待任务完成
            
            // 清理 handler
            stdoutHandle.readabilityHandler = nil
            stderrHandle.readabilityHandler = nil
            
            // 读取可能残留的输出
            let remainingStdout = stdoutHandle.readDataToEndOfFile()
            let remainingStderr = stderrHandle.readDataToEndOfFile()
            
            if !remainingStdout.isEmpty, let output = String(data: remainingStdout, encoding: .utf8) {
                let lines = output.split(separator: "\n").map(String.init)
                DispatchQueue.main.async {
                    self.appendLogs(lines, type: .normal)
                }
            }
            
            if !remainingStderr.isEmpty, let output = String(data: remainingStderr, encoding: .utf8) {
                let lines = output.split(separator: "\n").map(String.init)
                DispatchQueue.main.async {
                    self.appendLogs(lines, type: .normal)
                }
            }
            
            let success = task.terminationStatus == 0
            
            DispatchQueue.main.async {
                if success {
                    self.log("✓ \(label) 完成", type: .success)
                } else {
                    self.log("✗ \(label) 失败 (代码: \(task.terminationStatus))", type: .error)
                }
            }
            
            return success
        } catch {
            stdoutHandle.readabilityHandler = nil
            stderrHandle.readabilityHandler = nil
            
            DispatchQueue.main.async {
                self.log("❌ 执行失败：\(error.localizedDescription)", type: .error)
            }
            return false
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
        buildType = defaults.string(forKey: buildTypeKey) ?? "release"
        selectedAppModule = defaults.string(forKey: appModuleKey) ?? "app"
        keystorePath = defaults.string(forKey: keystorePathKey) ?? ""
        keyAlias = defaults.string(forKey: keyAliasKey) ?? ""
        storePassword = defaults.string(forKey: storePasswordKey) ?? ""
        keyPassword = defaults.string(forKey: keyPasswordKey) ?? ""
    }
    
    private func saveSettings() {
        defaults.set(projectPath, forKey: projectPathKey)
        defaults.set(buildType, forKey: buildTypeKey)
        defaults.set(selectedAppModule, forKey: appModuleKey)
        defaults.set(keystorePath, forKey: keystorePathKey)
        defaults.set(keyAlias, forKey: keyAliasKey)
        defaults.set(storePassword, forKey: storePasswordKey)
        defaults.set(keyPassword, forKey: keyPasswordKey)
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

    private func getConnectedDevices(adbPath: String) -> Set<String> {
        let task = Process()
        task.launchPath = "/bin/bash"
        task.arguments = ["-c", "\(adbPath) devices | grep -v 'List' | grep 'device' | awk '{print $1}'"]
        let pipe = Pipe()
        task.standardOutput = pipe
        try? task.run()
        task.waitUntilExit()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return Set(output.split(separator: "\n").map(String.init).filter { !$0.isEmpty })
    }

    private func scanWirelessDevicesWithMDNS(completion: @escaping ([(String, String)]) -> Void) {
        DispatchQueue.global().async {
            let adbPath = NSHomeDirectory() + "/Library/Android/sdk/platform-tools/adb"
            let androidHome = NSHomeDirectory() + "/Library/Android/sdk"

            // 启用 Openscreen mDNS
            var environment = ProcessInfo.processInfo.environment
            environment["ANDROID_HOME"] = androidHome
            environment["ADB_MDNS_OPENSCREEN"] = "1"

            // 重启 ADB 服务器以应用 mDNS 设置
            DispatchQueue.main.async {
                self.log("🔄 重启 ADB 服务以启用 mDNS...")
            }

            let killTask = Process()
            killTask.launchPath = "/bin/bash"
            killTask.environment = environment
            killTask.arguments = ["-c", "\(adbPath) kill-server"]
            killTask.standardOutput = Pipe()
            killTask.standardError = Pipe()

            do {
                try killTask.run()
                killTask.waitUntilExit()

                // 等待服务器完全关闭
                Thread.sleep(forTimeInterval: 1.0)

                // 启动 ADB 服务器
                let startTask = Process()
                startTask.launchPath = "/bin/bash"
                startTask.environment = environment
                startTask.arguments = ["-c", "\(adbPath) start-server"]
                startTask.standardOutput = Pipe()
                startTask.standardError = Pipe()

                try startTask.run()
                startTask.waitUntilExit()

                // 等待 mDNS 服务初始化
                Thread.sleep(forTimeInterval: 2.0)

                DispatchQueue.main.async {
                    self.log("📡 开始扫描 mDNS 服务...")
                }

                // 查询 mDNS 服务
                let mdnsTask = Process()
                mdnsTask.launchPath = "/bin/bash"
                mdnsTask.environment = environment
                mdnsTask.arguments = ["-c", "\(adbPath) mdns services"]

                let pipe = Pipe()
                mdnsTask.standardOutput = pipe
                mdnsTask.standardError = Pipe()

                try mdnsTask.run()
                mdnsTask.waitUntilExit()

                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                guard let output = String(data: data, encoding: .utf8), !output.isEmpty else {
                    DispatchQueue.main.async {
                        self.log("⚠️ 未发现 mDNS 服务")
                        self.log("💡 提示：请确保设备已开启「无线调试」")
                    }
                    completion([])
                    return
                }

                DispatchQueue.main.async {
                    self.log("📡 mDNS 扫描结果：")
                    for line in output.split(separator: "\n") {
                        self.log(String(line))
                    }
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

                    // 查找包含 IP:Port 的部分（支持更灵活的格式）
                    // 匹配 _adb-tls-connect 或 _adb._tcp 服务
                    if line.contains("_adb-tls-connect") || line.contains("_adb._tcp") {
                        // 使用正则表达式提取 IP:Port
                        if let regex = try? NSRegularExpression(pattern: "(\\d{1,3}\\.\\d{1,3}\\.\\d{1,3}\\.\\d{1,3}):(\\d+)", options: []) {
                            let nsLine = line as NSString
                            let matches = regex.matches(in: line, options: [], range: NSRange(location: 0, length: nsLine.length))

                            for match in matches {
                                if match.numberOfRanges >= 3 {
                                    let ipRange = match.range(at: 1)
                                    let portRange = match.range(at: 2)

                                    let ip = nsLine.substring(with: ipRange)
                                    let port = nsLine.substring(with: portRange)

                                    // 避免重复添加
                                    if !devices.contains(where: { $0.0 == ip && $0.1 == port }) {
                                        devices.append((ip, port))
                                        DispatchQueue.main.async {
                                            self.log("✓ 发现设备: \(ip):\(port)")
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                DispatchQueue.main.async {
                    if devices.isEmpty {
                        self.log("⚠️ 未找到可连接的无线设备")
                        self.log("💡 提示1：请确保设备已启用「无线调试」")
                        self.log("💡 提示2：设备和电脑需要在同一网络")
                        self.log("💡 提示3：某些设备需要先通过配对码配对")
                    } else {
                        self.log("✅ 共发现 \(devices.count) 个设备")
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

            // 获取当前已连接的设备列表
            let connectedDevices = self.getConnectedDevices(adbPath: adbPath)

            // 使用官方 mDNS 扫描
            self.scanWirelessDevicesWithMDNS { devices in
                // 过滤掉已经连接的设备
                let newDevices = devices.filter { (ip, port) in
                    let deviceId = "\(ip):\(port)"
                    return !connectedDevices.contains(deviceId)
                }

                guard !newDevices.isEmpty else {
                    DispatchQueue.main.async {
                        if devices.isEmpty {
                            self.log("✓ 扫描完成，未发现新设备")
                        } else {
                            self.log("✓ 扫描完成，发现的 \(devices.count) 个设备均已连接")
                        }
                        self.isScanningWireless = false
                    }
                    return
                }

                DispatchQueue.main.async {
                    self.log("✓ 发现 \(newDevices.count) 个未连接的无线设备")
                }

                func showNextDevice(_ index: Int) {
                    guard index < newDevices.count else {
                        DispatchQueue.main.async {
                            self.log("✓ 无线设备扫描完成")
                            self.isScanningWireless = false
                        }
                        return
                    }

                    let (ip, port) = newDevices[index]

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
                                            let output = pipe.fileHandleForReading.readDataToEndOfFile()
                                            let result = String(data: output, encoding: .utf8) ?? ""

                                            DispatchQueue.main.async {
                                                if result.contains("connected") {
                                                    self.log("✅ 成功连接 \(ip):\(port)", type: .success)
                                                    // 不再调用 refreshAVDList()，避免死循环
                                                    // 设备列表会在下次手动刷新时更新
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
