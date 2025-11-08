//
//  AndroidService.swift
//  LightAndroidDevTools
//
//  Service for Android-specific operations
//

import Foundation

/// Handles Android SDK operations (ADB, Emulator, etc.)
class AndroidService {

    private let executor = CommandExecutor()

    // MARK: - AVD Management

    /// Convert selected device name to actual device ID
    /// Returns the device ID if found, or the input if it's already a device ID
    func getDeviceId(from selectedDevice: String) -> String? {
        // If it looks like a device ID already (contains "emulator-", ":", or looks like a serial)
        if selectedDevice.contains("emulator-") ||
           selectedDevice.contains(":") ||
           selectedDevice.range(of: "^[A-Z0-9]+$", options: .regularExpression) != nil {
            return selectedDevice
        }

        // Otherwise, it's an AVD name - need to find the corresponding running emulator
        let adbPath = AppConfig.AndroidSDK.adbPath
        let task = Process()
        task.launchPath = AppConfig.Process.shellPath
        task.environment = ProcessInfo.processInfo.environment.merging(
            ["ANDROID_HOME": AppConfig.AndroidSDK.homeDirectory]
        ) { _, new in new }

        // Use adb devices -l to get detailed device list with AVD names
        task.arguments = [AppConfig.Process.shellArgPrefix, AppConfig.Process.shellArgCommand, "\(adbPath) devices -l"]

        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = Pipe()

        do {
            try task.run()
            task.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let output = String(data: data, encoding: .utf8) {
                // Parse output to find device ID matching the AVD name
                // Output format: "emulator-5554  device product:... model:... device:... transport_id:..."
                // or with avd: "emulator-5554  device ... avd:<avd_name>"
                let lines = output.split(separator: "\n")
                for line in lines {
                    let lineStr = String(line)
                    // Check if this line contains our AVD name
                    if lineStr.contains(selectedDevice) {
                        // Extract device ID (first column)
                        if let deviceId = lineStr.split(separator: " ").first {
                            return String(deviceId)
                        }
                    }
                }
            }
        } catch {
            return nil
        }

        return nil
    }

    /// Get list of available AVDs and connected devices
    func getAVDList() -> [String] {
        let emulatorPath = AppConfig.AndroidSDK.emulatorPath
        let adbPath = AppConfig.AndroidSDK.adbPath

        let listAVDsCmd = "\(emulatorPath) -list-avds"
        let listDevicesCmd = "\(adbPath) devices | grep -v 'List' | awk '{print $1}'"

        let task = Process()
        task.launchPath = AppConfig.Process.shellPath
        task.environment = ProcessInfo.processInfo.environment.merging(
            ["ANDROID_HOME": AppConfig.AndroidSDK.homeDirectory]
        ) { _, new in new }
        task.arguments = [AppConfig.Process.shellArgPrefix, AppConfig.Process.shellArgCommand, "\(listAVDsCmd); echo; \(listDevicesCmd)"]

        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = pipe

        do {
            try task.run()
            task.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let output = String(data: data, encoding: .utf8) {
                let lines = output.split(separator: "\n").map(String.init).filter { !$0.isEmpty }
                return lines
            }
        } catch {
            return []
        }

        return []
    }

    /// Check if emulator is running
    func isEmulatorRunning() -> Bool {
        let task = Process()
        task.launchPath = AppConfig.Process.shellPath
        let adbPath = AppConfig.AndroidSDK.adbPath

        task.environment = ProcessInfo.processInfo.environment.merging(
            ["ANDROID_HOME": AppConfig.AndroidSDK.homeDirectory]
        ) { _, new in new }
        task.arguments = [AppConfig.Process.shellArgPrefix, AppConfig.Process.shellArgCommand, "\(adbPath) devices | grep emulator"]

        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = Pipe()

        do {
            try task.run()
            task.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

            return !output.isEmpty && output.contains("device") && !output.contains("offline")
        } catch {
            return false
        }
    }

    /// Launch emulator with given AVD name
    func launchEmulator(_ avd: String) -> Process? {
        let emulatorPath = AppConfig.AndroidSDK.emulatorPath

        let task = Process()
        task.launchPath = AppConfig.Process.shellPath
        task.environment = ProcessInfo.processInfo.environment.merging(
            ["ANDROID_HOME": AppConfig.AndroidSDK.homeDirectory]
        ) { _, new in new }
        task.arguments = [AppConfig.Process.shellArgPrefix, AppConfig.Process.shellArgCommand, "\(emulatorPath) -avd \(avd) &"]

        do {
            try task.run()
            return task
        } catch {
            return nil
        }
    }

    /// Kill all running emulators
    func killEmulator() -> Bool {
        let cmd = "pkill -f 'emulator.*-avd'"
        let task = Process()
        task.launchPath = AppConfig.Process.shellPath
        task.arguments = [AppConfig.Process.shellArgPrefix, AppConfig.Process.shellArgCommand, cmd]

        do {
            try task.run()
            task.waitUntilExit()
            return task.terminationStatus == 0
        } catch {
            return false
        }
    }

    // MARK: - Project Analysis

    /// Get package name from build.gradle file
    func getPackageName(projectPath: String, module: String) -> String? {
        let buildGradle = projectPath + "/\(module)/build.gradle"
        let buildGradleKts = projectPath + "/\(module)/build.gradle.kts"

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
            return nil
        }

        return nil
    }

    /// Get main activity name from AndroidManifest.xml
    func getMainActivity(projectPath: String, module: String) -> String? {
        let manifestPath = projectPath + "/\(module)/src/main/AndroidManifest.xml"

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

    /// Detect Android modules in project
    func detectModules(projectPath: String) -> [String] {
        guard !projectPath.isEmpty else { return [] }

        let fileManager = FileManager.default
        do {
            let projectURL = URL(fileURLWithPath: projectPath)
            let contents = try fileManager.contentsOfDirectory(atPath: projectURL.path)
            var modules: [String] = []

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
                    }
                }
            }

            return modules.sorted()
        } catch {
            return []
        }
    }

    // MARK: - Wireless Devices

    /// Get offline wireless devices
    func getOfflineWirelessDevices() -> [String] {
        let adbPath = AppConfig.AndroidSDK.adbPath
        let task = Process()
        task.launchPath = AppConfig.Process.shellPath
        task.arguments = [AppConfig.Process.shellArgCommand, "\(adbPath) devices | grep 'offline' | awk '{print $1}'"]
        let pipe = Pipe()
        task.standardOutput = pipe
        try? task.run()
        task.waitUntilExit()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return output.split(separator: "\n").map(String.init).filter { !$0.isEmpty }
    }

    /// Get connected devices
    func getConnectedDevices() -> Set<String> {
        let adbPath = AppConfig.AndroidSDK.adbPath
        let task = Process()
        task.launchPath = AppConfig.Process.shellPath
        task.arguments = [AppConfig.Process.shellArgCommand, "\(adbPath) devices | grep -v 'List' | grep 'device' | awk '{print $1}'"]
        let pipe = Pipe()
        task.standardOutput = pipe
        try? task.run()
        task.waitUntilExit()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return Set(output.split(separator: "\n").map(String.init).filter { !$0.isEmpty })
    }

    // MARK: - mDNS Wireless Discovery

    /// Restart ADB server with mDNS support enabled
    func restartADBWithMDNS() async -> Bool {
        let adbPath = AppConfig.AndroidSDK.adbPath

        // First, kill the ADB server
        let killTask = Process()
        killTask.launchPath = AppConfig.Process.shellPath
        killTask.environment = ProcessInfo.processInfo.environment.merging(
            ["ANDROID_HOME": AppConfig.AndroidSDK.homeDirectory]
        ) { _, new in new }
        killTask.arguments = [AppConfig.Process.shellArgPrefix, AppConfig.Process.shellArgCommand, "\(adbPath) kill-server"]

        do {
            try killTask.run()
            killTask.waitUntilExit()
        } catch {
            return false
        }

        // Wait a bit for server to fully stop (non-blocking)
        try? await Task.sleep(nanoseconds: UInt64(AppConfig.Timing.adbRestartDelay * 1_000_000_000))

        // Start ADB server with mDNS enabled
        let startTask = Process()
        startTask.launchPath = AppConfig.Process.shellPath
        startTask.environment = ProcessInfo.processInfo.environment.merging([
            "ANDROID_HOME": AppConfig.AndroidSDK.homeDirectory,
            "ADB_MDNS_OPENSCREEN": "1"
        ]) { _, new in new }
        startTask.arguments = [AppConfig.Process.shellArgPrefix, AppConfig.Process.shellArgCommand, "\(adbPath) start-server"]

        do {
            try startTask.run()
            startTask.waitUntilExit()

            // Wait for mDNS to initialize (non-blocking)
            try? await Task.sleep(nanoseconds: UInt64(AppConfig.Timing.mdnsInitDelay * 1_000_000_000))

            return startTask.terminationStatus == 0
        } catch {
            return false
        }
    }

    /// Discover wireless devices using mDNS
    /// Returns array of device info strings (e.g., ["Device Name (192.168.1.100:5555)"])
    func discoverMDNSDevices() async -> [String] {
        let adbPath = AppConfig.AndroidSDK.adbPath
        let task = Process()
        task.launchPath = AppConfig.Process.shellPath
        task.environment = ProcessInfo.processInfo.environment.merging([
            "ANDROID_HOME": AppConfig.AndroidSDK.homeDirectory,
            "ADB_MDNS_OPENSCREEN": "1"
        ]) { _, new in new }
        task.arguments = [AppConfig.Process.shellArgPrefix, AppConfig.Process.shellArgCommand, "\(adbPath) mdns services"]

        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = Pipe()

        do {
            try task.run()
            task.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()

            guard let output = String(data: data, encoding: .utf8) else {
                return []
            }

            // Parse mDNS output
            // Expected format varies, but typically contains service names and addresses
            var devices: [String] = []
            let lines = output.split(separator: "\n").map(String.init)

            for line in lines {
                // Look for lines containing IP addresses and ports
                // Common patterns: "192.168.x.x:5555" or similar
                if let regex = try? NSRegularExpression(pattern: "([0-9]{1,3}\\.[0-9]{1,3}\\.[0-9]{1,3}\\.[0-9]{1,3}):([0-9]+)", options: []) {
                    let nsString = line as NSString
                    let matches = regex.matches(in: line, options: [], range: NSRange(location: 0, length: nsString.length))

                    for match in matches {
                        if match.numberOfRanges >= 1 {
                            let deviceAddress = nsString.substring(with: match.range)
                            if !devices.contains(deviceAddress) {
                                devices.append(deviceAddress)
                            }
                        }
                    }
                }
            }

            return devices
        } catch {
            return []
        }
    }

    /// Connect to a wireless device
    func connectToWirelessDevice(address: String) -> Bool {
        let adbPath = AppConfig.AndroidSDK.adbPath
        let task = Process()
        task.launchPath = AppConfig.Process.shellPath
        task.environment = ProcessInfo.processInfo.environment.merging(
            ["ANDROID_HOME": AppConfig.AndroidSDK.homeDirectory]
        ) { _, new in new }
        task.arguments = [AppConfig.Process.shellArgPrefix, AppConfig.Process.shellArgCommand, "\(adbPath) connect \(address)"]

        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = pipe

        do {
            try task.run()
            task.waitUntilExit()

            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let output = String(data: data, encoding: .utf8) {
                // Check if connection was successful
                return output.contains("connected") && !output.contains("failed")
            }

            return task.terminationStatus == 0
        } catch {
            return false
        }
    }

    /// Disconnect offline wireless devices
    func disconnectOfflineDevices() -> Int {
        let offlineDevices = getOfflineWirelessDevices()
        var disconnectedCount = 0

        for device in offlineDevices {
            let adbPath = AppConfig.AndroidSDK.adbPath
            let task = Process()
            task.launchPath = AppConfig.Process.shellPath
            task.environment = ProcessInfo.processInfo.environment.merging(
                ["ANDROID_HOME": AppConfig.AndroidSDK.homeDirectory]
            ) { _, new in new }
            task.arguments = [AppConfig.Process.shellArgPrefix, AppConfig.Process.shellArgCommand, "\(adbPath) disconnect \(device)"]

            do {
                try task.run()
                task.waitUntilExit()
                if task.terminationStatus == 0 {
                    disconnectedCount += 1
                }
            } catch {
                continue
            }
        }

        return disconnectedCount
    }
}
