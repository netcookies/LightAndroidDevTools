//
//  LightAndroidDevToolsApp.swift
//  LightAndroidDevTools
//
//  Refactored main application file with modular architecture
//

import SwiftUI
import UniformTypeIdentifiers

@main
struct LightAndroidDevToolsApp: App {
    @State private var isCompactMode = UserDefaults.standard.bool(forKey: AppConfig.UserDefaultsKeys.isCompactMode)

    var body: some Scene {
        WindowGroup {
            ContentView(isCompactMode: $isCompactMode)
                .onAppear {
                    configureWindowOnAppear()
                }
                .onChange(of: isCompactMode) {
                    handleCompactModeChange()
                }
        }
    }

    private func configureWindowOnAppear() {
        let compact = UserDefaults.standard.bool(forKey: AppConfig.UserDefaultsKeys.isCompactMode)
        if let window = NSApplication.shared.windows.first,
           let screen = window.screen ?? NSScreen.main {
            if compact {
                WindowManager.configureCompactMode(window: window, screen: screen)
            } else {
                WindowManager.configureFullMode(window: window, screen: screen)
            }
            WindowManager.setupCloseButton(window: window)
        }
    }

    private func handleCompactModeChange() {
        UserDefaults.standard.set(isCompactMode, forKey: AppConfig.UserDefaultsKeys.isCompactMode)

        if let window = NSApplication.shared.windows.first,
           let screen = window.screen ?? NSScreen.main {
            if isCompactMode {
                WindowManager.configureCompactMode(window: window, screen: screen)
            } else {
                WindowManager.configureFullMode(window: window, screen: screen)
            }
        }
    }
}

// MARK: - Main Content View

struct ContentView: View {
    @StateObject private var viewModel = AppViewModel()
    @Binding var isCompactMode: Bool

    var body: some View {
        Group {
            if isCompactMode {
                CompactView(viewModel: viewModel, isCompactMode: $isCompactMode)
            } else {
                FullView(viewModel: viewModel, isCompactMode: $isCompactMode)
            }
        }
        .onAppear {
            viewModel.onAppear()
        }
        .onDisappear {
            viewModel.onDisappear()
        }
        .onChange(of: isCompactMode) {
            viewModel.startEmulatorStatusCheck()
            if !isCompactMode {
                viewModel.scrollToEnd = true
            }
        }
        .onChange(of: viewModel.settings.projectPath) {
            viewModel.onProjectPathChange()
        }
        .sheet(isPresented: $viewModel.showSigningDialog) {
            SigningConfigDialog(viewModel: viewModel)
        }
        .sheet(isPresented: $viewModel.showAuthDialog) {
            AuthDialog(viewModel: viewModel)
        }
    }
}

// MARK: - Full View

struct FullView: View {
    @ObservedObject var viewModel: AppViewModel
    @Binding var isCompactMode: Bool

    var body: some View {
        VStack(spacing: 0) {
            // Settings Section
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("项目路径")
                            .font(.caption)
                            .foregroundColor(.gray)
                        HStack {
                            UnifiedTextField(placeholder: "选择项目目录", text: $viewModel.settings.projectPath)
                            Button(action: {
                                if let path = viewModel.selectProjectPath() {
                                    viewModel.settings.projectPath = path
                                }
                            }) {
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
                        UnifiedPicker(selection: $viewModel.selectedAVD, width: 325) {
                            Text("选择设备").tag(nil as String?)
                            ForEach(viewModel.avdList, id: \.self) { avd in
                                Text(avd).tag(avd as String?)
                            }
                        }
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("构建类型")
                            .font(.caption)
                            .foregroundColor(.gray)
                        UnifiedSegmentedPicker(selection: $viewModel.settings.buildType) {
                            Text("Debug").tag(AppConfig.Build.debugBuildType)
                            Text("Release").tag(AppConfig.Build.releaseBuildType)
                        }
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("应用模块")
                            .font(.caption)
                            .foregroundColor(.gray)
                        UnifiedPicker(selection: $viewModel.settings.selectedAppModule) {
                            ForEach(viewModel.detectedModules.isEmpty ? [AppConfig.Build.defaultModule] : viewModel.detectedModules, id: \.self) { module in
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

            // Toolbar
            HStack(spacing: 12) {
                Button(action: viewModel.refreshAVDList) {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.clockwise")
                            .frame(width: AppConfig.UI.iconFrameSize, height: AppConfig.UI.iconFrameSize)
                        Text("刷新设备")
                    }
                }
                .buttonStyle(ToolbarButtonStyle())

                Button(action: viewModel.startAVD) {
                    HStack(spacing: 4) {
                        Image(systemName: viewModel.emulatorRunning ? "stop.circle.fill" : "play.fill")
                            .frame(width: AppConfig.UI.iconFrameSize, height: AppConfig.UI.iconFrameSize)
                        Text(viewModel.emulatorRunning ? "关闭模拟器" : "启动模拟器")
                    }
                }
                .buttonStyle(ToolbarButtonStyle())
                .disabled(viewModel.selectedAVD == nil)

                Button(action: viewModel.buildProject) {
                    HStack(spacing: 4) {
                        Image(systemName: "hammer.fill")
                            .frame(width: AppConfig.UI.iconFrameSize, height: AppConfig.UI.iconFrameSize)
                        Text("编译")
                    }
                }
                .buttonStyle(ToolbarButtonStyle())
                .disabled(viewModel.settings.projectPath.isEmpty || viewModel.isRunning)

                Button(action: viewModel.buildAndRun) {
                    HStack(spacing: 4) {
                        Image(systemName: "play.circle.fill")
                            .frame(width: AppConfig.UI.iconFrameSize, height: AppConfig.UI.iconFrameSize)
                        Text("编译并运行")
                    }
                }
                .buttonStyle(ToolbarButtonStyle())
                .disabled(viewModel.settings.projectPath.isEmpty || viewModel.selectedAVD == nil || viewModel.isRunning)

                Button(action: viewModel.buildAPK) {
                    HStack(spacing: 4) {
                        Image(systemName: "shippingbox.fill")
                            .frame(width: AppConfig.UI.iconFrameSize, height: AppConfig.UI.iconFrameSize)
                        Text("编译APK")
                    }
                }
                .buttonStyle(ToolbarButtonStyle())
                .disabled(viewModel.settings.projectPath.isEmpty || viewModel.isRunning)

                Button(action: viewModel.installAPK) {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.down.circle.fill")
                            .frame(width: AppConfig.UI.iconFrameSize, height: AppConfig.UI.iconFrameSize)
                        Text("安装APK")
                    }
                }
                .buttonStyle(ToolbarButtonStyle())
                .disabled(viewModel.settings.projectPath.isEmpty || viewModel.isRunning)

                Button(action: { viewModel.showAuthDialog = true }) {
                    HStack(spacing: 4) {
                        Image(systemName: "key.fill")
                            .frame(width: AppConfig.UI.iconFrameSize, height: AppConfig.UI.iconFrameSize)
                        Text("授权")
                    }
                }
                .buttonStyle(ToolbarButtonStyle())
                .disabled(viewModel.isRunning)

                Spacer()

                TaskStatusIndicator(
                    isRunning: viewModel.isRunning,
                    taskDuration: viewModel.taskDuration,
                    lastTaskSuccess: viewModel.lastTaskSuccess,
                    onStop: viewModel.stopCurrentTask
                )

                Button(action: { isCompactMode = true }) {
                    Image(systemName: "sidebar.left")
                        .frame(width: AppConfig.UI.iconFrameSize, height: AppConfig.UI.iconFrameSize)
                }
                .buttonStyle(CompactIconButtonStyle())
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color(.controlBackgroundColor))
            .border(.gray.opacity(0.3), width: 1)

            // Log Output
            LogOutputView(logOutput: $viewModel.logManager.logOutput, scrollToEnd: $viewModel.scrollToEnd)
        }
    }
}

// MARK: - Compact View

struct CompactView: View {
    @ObservedObject var viewModel: AppViewModel
    @Binding var isCompactMode: Bool

    var body: some View {
        VStack(spacing: 6) {
            // Action Buttons
            HStack(spacing: 8) {
                Button(action: viewModel.buildProject) {
                    Image(systemName: "hammer.fill")
                        .frame(width: AppConfig.UI.iconFrameSize, height: AppConfig.UI.iconFrameSize)
                }
                .buttonStyle(CompactIconButtonStyle())
                .disabled(viewModel.settings.projectPath.isEmpty || viewModel.isRunning)
                .help("编译")

                Button(action: viewModel.buildAndRun) {
                    Image(systemName: "play.circle.fill")
                        .frame(width: AppConfig.UI.iconFrameSize, height: AppConfig.UI.iconFrameSize)
                }
                .buttonStyle(CompactIconButtonStyle())
                .disabled(viewModel.settings.projectPath.isEmpty || viewModel.selectedAVD == nil || viewModel.isRunning)
                .help("编译并运行")

                Button(action: viewModel.buildAPK) {
                    Image(systemName: "shippingbox.fill")
                        .frame(width: AppConfig.UI.iconFrameSize, height: AppConfig.UI.iconFrameSize)
                }
                .buttonStyle(CompactIconButtonStyle())
                .disabled(viewModel.settings.projectPath.isEmpty || viewModel.isRunning)
                .help("编译APK")

                Button(action: viewModel.installAPK) {
                    Image(systemName: "arrow.down.circle.fill")
                        .frame(width: AppConfig.UI.iconFrameSize, height: AppConfig.UI.iconFrameSize)
                }
                .buttonStyle(CompactIconButtonStyle())
                .disabled(viewModel.settings.projectPath.isEmpty || viewModel.isRunning)
                .help("安装APK")

                Button(action: { viewModel.showAuthDialog = true }) {
                    Image(systemName: "key.fill")
                        .frame(width: AppConfig.UI.iconFrameSize, height: AppConfig.UI.iconFrameSize)
                }
                .buttonStyle(CompactIconButtonStyle())
                .disabled(viewModel.isRunning)
                .help("授权")

                Spacer()

                CompactTaskStatusIndicator(
                    isRunning: viewModel.isRunning,
                    taskDuration: viewModel.taskDuration,
                    lastTaskSuccess: viewModel.lastTaskSuccess,
                    onStop: viewModel.stopCurrentTask
                )

                Button(action: { isCompactMode = false }) {
                    Image(systemName: "sidebar.right")
                        .frame(width: AppConfig.UI.iconFrameSize, height: AppConfig.UI.iconFrameSize)
                }
                .buttonStyle(CompactIconButtonStyle())
                .help("展开")
            }
            .padding(.horizontal, 16)
            .padding(.top, 6)

            // Device Selector
            HStack(spacing: 8) {
                Button(action: viewModel.refreshAVDList) {
                    Image(systemName: "arrow.clockwise")
                        .frame(width: AppConfig.UI.iconFrameSize, height: AppConfig.UI.iconFrameSize)
                }
                .buttonStyle(CompactIconButtonStyle())
                .help("刷新设备")

                Button(action: viewModel.startAVD) {
                    Image(systemName: viewModel.emulatorRunning ? "stop.circle.fill" : "play.fill")
                        .frame(width: AppConfig.UI.iconFrameSize, height: AppConfig.UI.iconFrameSize)
                }
                .buttonStyle(CompactIconButtonStyle())
                .disabled(viewModel.selectedAVD == nil)
                .help(viewModel.emulatorRunning ? "关闭模拟器" : "启动模拟器")

                UnifiedPicker(selection: $viewModel.selectedAVD) {
                    Text("选择设备").tag(nil as String?)
                    ForEach(viewModel.avdList, id: \.self) { avd in
                        Text(avd).tag(avd as String?)
                    }
                }
                .font(.caption)
                .frame(maxWidth: .infinity)
                .disabled(viewModel.isRunning)

                UnifiedSegmentedPicker(selection: $viewModel.settings.buildType, width: 120) {
                    Text("Debug").tag(AppConfig.Build.debugBuildType)
                    Text("Release").tag(AppConfig.Build.releaseBuildType)
                }
                .disabled(viewModel.isRunning)
                .help("构建类型")
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 6)
        }
    }
}

// MARK: - Signing Config Dialog

struct SigningConfigDialog: View {
    @ObservedObject var viewModel: AppViewModel

    var body: some View {
        VStack(spacing: 20) {
            Text("Release APK 签名配置")
                .font(.headline)

            VStack(alignment: .leading, spacing: 10) {
                Text("Keystore 路径:")
                HStack {
                    TextField("选择 keystore 文件", text: $viewModel.settings.keystorePath)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                    Button("浏览") {
                        if let path = viewModel.selectKeystoreFile() {
                            viewModel.settings.keystorePath = path
                        }
                    }
                    .buttonStyle(SecondaryButtonStyle())
                }

                Text("Key Alias:")
                TextField("输入 key alias", text: $viewModel.settings.keyAlias)
                    .textFieldStyle(RoundedBorderTextFieldStyle())

                Text("Store Password:")
                SecureField("输入 store 密码", text: $viewModel.settings.storePassword)
                    .textFieldStyle(RoundedBorderTextFieldStyle())

                Text("Key Password:")
                SecureField("输入 key 密码", text: $viewModel.settings.keyPassword)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
            }

            HStack {
                Button("取消") {
                    viewModel.showSigningDialog = false
                }
                .buttonStyle(SecondaryButtonStyle())

                Button("开始构建并签名") {
                    viewModel.showSigningDialog = false
                    viewModel.buildAndSignRelease()
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(viewModel.settings.keystorePath.isEmpty || viewModel.settings.keyAlias.isEmpty ||
                         viewModel.settings.storePassword.isEmpty || viewModel.settings.keyPassword.isEmpty)
            }
        }
        .padding()
        .frame(width: AppConfig.Dialog.signingWidth)
    }
}

// MARK: - Auth Dialog

struct AuthDialog: View {
    @ObservedObject var viewModel: AppViewModel

    var body: some View {
        VStack(spacing: 20) {
            Text("ADB 设备授权")
                .font(.headline)

            Text("请在设备上查看授权码，并在下方输入：")
                .font(.caption)
                .foregroundColor(.gray)

            TextField("输入授权码", text: $viewModel.authCode)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .frame(width: AppConfig.Dialog.authTextFieldWidth)

            HStack {
                Button("取消") {
                    viewModel.showAuthDialog = false
                    viewModel.authCode = ""
                }
                .buttonStyle(SecondaryButtonStyle())

                Button("授权") {
                    viewModel.showAuthDialog = false
                    viewModel.performAuth()
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(viewModel.authCode.isEmpty)
            }
        }
        .padding()
        .frame(width: AppConfig.Dialog.authWidth)
    }
}
