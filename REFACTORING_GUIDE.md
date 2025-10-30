# 代码重构指南

## 概述

这个项目已经从单文件架构(~2000行)重构为模块化架构,使代码更易于维护和扩展。

## 新的项目结构

```
LightAndroidDevTools/
├── Config/
│   └── AppConfig.swift                 # 集中管理所有配置常量
├── Models/
│   ├── LogLine.swift                   # 日志数据模型
│   └── AppSettings.swift               # 应用设置管理
├── Services/
│   ├── CommandExecutor.swift           # 命令执行服务
│   ├── AndroidService.swift            # Android SDK 操作服务
│   └── LogManager.swift                # 日志管理服务
├── Views/
│   ├── ButtonStyles.swift              # 自定义按钮样式
│   ├── CustomControls.swift            # 自定义UI控件
│   ├── TaskStatusIndicator.swift       # 任务状态指示器
│   └── LogOutputView.swift             # 日志输出视图
├── ViewModels/
│   └── AppViewModel.swift              # 主视图模型(业务逻辑)
├── Extensions/
│   └── WindowManager.swift             # 窗口管理工具
└── LightAndroidDevToolsApp_New.swift  # 重构后的主应用文件
```

## 主要改进

### 1. 配置管理 (Config/AppConfig.swift)

所有硬编码的常量现在集中在 `AppConfig` 结构体中:

```swift
// 窗口尺寸
AppConfig.Window.compactWidth
AppConfig.Window.fullHeight

// UI 尺寸
AppConfig.UI.iconFrameSize
AppConfig.UI.controlHeight

// Android SDK 路径
AppConfig.AndroidSDK.adbPath
AppConfig.AndroidSDK.emulatorPath

// 日志配置
AppConfig.Log.maxLines
AppConfig.Log.trimThreshold

// 时间配置
AppConfig.Timing.emulatorCheckInterval
```

### 2. 模型层分离

- **LogLine**: 日志行数据模型
- **AppSettings**: 自动持久化的应用设置(使用 UserDefaults)

### 3. 服务层解耦

- **CommandExecutor**: 处理所有 shell 命令执行
  - `executeAsync()`: 异步执行并实时输出
  - `executeSync()`: 同步执行并等待结果

- **AndroidService**: 封装 Android SDK 操作
  - AVD 列表获取
  - 模拟器状态检查
  - 项目模块扫描
  - 包名和Activity解析

- **LogManager**: 管理日志输出
  - 自动日志修剪
  - 时间戳添加
  - 类型化日志输出

### 4. 视图组件化

所有 UI 组件已拆分到独立文件:
- 按钮样式(5种不同样式)
- 自定义控件(TextField, Picker, SegmentedPicker)
- 任务状态指示器(Full & Compact版本)
- 日志输出视图

### 5. MVVM架构

- **AppViewModel**: 集中管理所有业务逻辑
  - 发布状态变更
  - 协调服务调用
  - 处理用户操作

## 如何切换到新版本

### 方案 1: 直接替换(推荐用于测试)

1. 重命名原文件:
```bash
mv LightAndroidDevTools/LightAndroidDevToolsApp.swift \
   LightAndroidDevTools/LightAndroidDevToolsApp_Old.swift
```

2. 重命名新文件:
```bash
mv LightAndroidDevTools/LightAndroidDevToolsApp_New.swift \
   LightAndroidDevTools/LightAndroidDevToolsApp.swift
```

3. 在 Xcode 中添加新的文件夹到项目:
   - Config/
   - Models/
   - Services/
   - Views/
   - ViewModels/
   - Extensions/

4. 构建并测试

### 方案 2: 在 Xcode 中逐步迁移

1. 在 Xcode 中打开项目
2. 使用 File > Add Files 添加新的文件夹
3. 保留旧文件作为备份,但从 target 中移除
4. 将新文件添加到 target
5. 构建并测试

## 配置参数化

所有之前硬编码的值现在都可以在 `AppConfig.swift` 中统一修改:

### 修改 Android SDK 路径

```swift
struct AndroidSDK {
    static let homeDirectory: String = "/custom/path/to/sdk"  // 修改这里
    // ...
}
```

### 修改窗口尺寸

```swift
struct Window {
    static let compactWidth: CGFloat = 400    // 修改紧凑模式宽度
    static let compactHeight: CGFloat = 80    // 修改紧凑模式高度
    // ...
}
```

### 修改日志限制

```swift
struct Log {
    static let maxLines: Int = 2000           // 增加最大日志行数
    static let trimThreshold: Int = 2500      // 修改触发修剪的阈值
}
```

### 修改构建工具版本

```swift
struct AndroidSDK {
    static let buildToolsVersion: String = "35.0.0"  // 更改版本
    // buildToolsPath 会自动更新
}
```

## 扩展指南

### 添加新的 Android 操作

1. 在 `AndroidService.swift` 中添加方法
2. 在 `AppViewModel.swift` 中调用服务方法
3. 在视图中绑定到 ViewModel

### 添加新的配置项

1. 在 `AppConfig.swift` 中添加常量
2. 在相应的代码中使用新常量

### 添加新的 UI 组件

1. 在 `Views/` 文件夹创建新的 SwiftUI View
2. 使用 AppConfig 中的常量配置样式
3. 在主视图中引用

## 优势

1. **可维护性**: 代码按功能分离,易于定位和修改
2. **可测试性**: 服务层和ViewModel可以独立测试
3. **可配置性**: 所有常量集中管理,一处修改全局生效
4. **可扩展性**: 添加新功能不需要修改现有代码
5. **可读性**: 每个文件职责单一,代码量适中

## 注意事项

1. 新版本保留了所有原有功能
2. UI 和交互逻辑完全一致
3. UserDefaults 键名保持不变,设置可以无缝迁移
4. 日志管理现在是响应式的,使用 `@Published` 属性

## 遗留功能

以下功能在新版本中需要根据需要实现:

1. **无线设备扫描(mDNS)**:
   - 原代码在 `refreshWirelessDevices()` 和 `scanWirelessDevicesWithMDNS()` 中
   - 可以移植到 `AndroidService` 或创建新的 `WirelessDeviceService`

2. **完整的对话框逻辑**:
   - 所有对话框UI已实现
   - 确保所有边界情况都已处理

## 下一步

1. 测试所有功能确保正常工作
2. 根据需要调整配置参数
3. 考虑添加单元测试
4. 文档化自定义修改

## 回滚方案

如果需要回到原版本:

```bash
mv LightAndroidDevTools/LightAndroidDevToolsApp.swift \
   LightAndroidDevTools/LightAndroidDevToolsApp_Refactored.swift

mv LightAndroidDevTools/LightAndroidDevToolsApp_Old.swift \
   LightAndroidDevTools/LightAndroidDevToolsApp.swift
```

然后在 Xcode 中从 target 移除新添加的文件夹。
