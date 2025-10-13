import SwiftUI

@main
struct LightAndroidDevToolsApp: App {
    @State private var isCompactMode = false
    
    var body: some Scene {
        WindowGroup {
            ContentView(isCompactMode: $isCompactMode)
                .onAppear {
                    if let window = NSApplication.shared.windows.first {
                        window.setContentSize(NSSize(width: 900, height: 650))
                        // 添加置顶功能菜单
                        window.level = .normal
                        window.standardWindowButton(.closeButton)?.target = NSApp
                        window.standardWindowButton(.closeButton)?.action = #selector(NSApplication.terminate(_:))
                    }
                }
                .onChange(of: isCompactMode) {
                    if let window = NSApplication.shared.windows.first {
                        if isCompactMode {
                            window.setContentSize(NSSize(width: 400, height: 60))
                            toggleWindowLevel()
                        } else {
                            window.setContentSize(NSSize(width: 900, height: 650))
                            toggleWindowLevel()
                        }
                    }
                }
        }
    }
    
    private func toggleWindowLevel() {
        if let window = NSApplication.shared.windows.first {
            if window.level == .floating {
                window.level = .normal
            } else {
                window.level = .floating
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
    @State private var logOutput: String = "准备就绪\n"
    @State private var selectedAppModule: String = "app"
    @Binding var isCompactMode: Bool
    @State private var detectedModules: [String] = []
    @State private var emulatorRunning = false
    @State private var emulatorCheckTimer: Timer?
    
    private let defaults = UserDefaults.standard
    private let projectPathKey = "projectPath"
    private let buildTypeKey = "buildType"
    private let appModuleKey = "selectedAppModule"
    
    var body: some View {
        if isCompactMode {
            compactView
        } else {
            fullView
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
                        Text("虚拟设备")
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
            
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("日志输出")
                        .font(.caption)
                        .foregroundColor(.gray)
                    Spacer()
                    Button(action: clearLog) {
                        Text("清空")
                            .font(.caption)
                    }
                }
                
                TextEditor(text: $logOutput)
                    .font(.system(.caption, design: .monospaced))
                    .background(Color(.textBackgroundColor))
                    .border(.gray.opacity(0.3), width: 1)
            }
            .padding(16)
        }
        .onAppear {
            loadSettings()
            refreshAVDList()
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
                
                Button(action: { isCompactMode = false }) {
                    Image(systemName: "sidebar.right")
                        .font(.system(size: 14))
                }
                .help("展开")
            }
            .padding(8)
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
        let emulatorPath = NSHomeDirectory() + "/Library/Android/sdk/emulator/emulator"
        let androidHome = NSHomeDirectory() + "/Library/Android/sdk"
        
        let task = Process()
        task.launchPath = "/bin/bash"
        task.environment = ProcessInfo.processInfo.environment.merging(["ANDROID_HOME": androidHome]) { _, new in new }
        task.arguments = ["-i", "-c", "\(emulatorPath) -list-avds"]
        
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = pipe
        
        do {
            try task.run()
            task.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let output = String(data: data, encoding: .utf8) {
                avdList = output.split(separator: "\n").map(String.init).filter { !$0.isEmpty }
                if !avdList.isEmpty {
                    if selectedAVD == nil {
                        selectedAVD = avdList[0]
                    }
                    log("✓ 找到 \(avdList.count) 个虚拟设备: \(avdList.joined(separator: ", "))")
                } else {
                    log("⚠️ 未找到虚拟设备")
                }
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
        checkEmulatorStatus()
        emulatorCheckTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            checkEmulatorStatus()
        }
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
                    if !isRunning {
                        emulatorCheckTimer?.invalidate()
                    }
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
            executeCommand("cd \(projectPath) && ./gradlew build", label: "编译")
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
            let gradleTask = buildType == "debug" ? "installDebug" : "installRelease"
            executeCommand("cd \(projectPath) && ./gradlew \(gradleTask)", label: "安装APK")
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
        
        do {
            try task.run()
            
            let fileHandle = pipe.fileHandleForReading
            var outputData = Data()
            
            while task.isRunning {
                let data = fileHandle.availableData
                if data.count > 0 {
                    outputData.append(data)
                    if let output = String(data: outputData, encoding: .utf8) {
                        DispatchQueue.main.async {
                            logOutput = output
                        }
                    }
                }
                usleep(100000)
            }
            
            task.waitUntilExit()
            
            DispatchQueue.main.async {
                if task.terminationStatus == 0 {
                    log("✓ \(label) 完成")
                } else {
                    log("✗ \(label) 失败 (代码: \(task.terminationStatus))")
                }
                isRunning = false
            }
        } catch {
            DispatchQueue.main.async {
                log("❌ 执行失败：\(error.localizedDescription)")
                isRunning = false
            }
        }
    }
    
    private func log(_ message: String) {
        let timestamp = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
        logOutput.append("[\(timestamp)] \(message)\n")
    }
    
    private func clearLog() {
        logOutput = ""
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
        guard !projectPath.isEmpty else { return }
        
        let fileManager = FileManager.default
        do {
            let contents = try fileManager.contentsOfDirectory(atPath: projectPath)
            var modules: [String] = []
            
            for item in contents {
                let fullPath = projectPath + "/" + item
                var isDir: ObjCBool = false
                
                if fileManager.fileExists(atPath: fullPath, isDirectory: &isDir), isDir.boolValue {
                    let buildGradle = fullPath + "/build.gradle"
                    let buildGradleKts = fullPath + "/build.gradle.kts"
                    
                    if fileManager.fileExists(atPath: buildGradle) || fileManager.fileExists(atPath: buildGradleKts) {
                        modules.append(item)
                    }
                }
            }
            
            if !modules.isEmpty {
                detectedModules = modules.sorted()
                if !detectedModules.contains(selectedAppModule) {
                    selectedAppModule = detectedModules[0]
                }
            }
        } catch {
            log("⚠️ 无法扫描模块: \(error.localizedDescription)")
        }
    }
}

#Preview {
    ContentView(isCompactMode: .constant(false))
}
