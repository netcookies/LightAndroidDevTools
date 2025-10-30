//
//  AppSettings.swift
//  LightAndroidDevTools
//
//  Application settings persistence
//

import Foundation
import Combine

/// Manages application settings using UserDefaults
class AppSettings: ObservableObject {
    private let defaults = UserDefaults.standard

    @Published var projectPath: String {
        didSet { save(projectPath, forKey: AppConfig.UserDefaultsKeys.projectPath) }
    }

    @Published var buildType: String {
        didSet { save(buildType, forKey: AppConfig.UserDefaultsKeys.buildType) }
    }

    @Published var selectedAppModule: String {
        didSet { save(selectedAppModule, forKey: AppConfig.UserDefaultsKeys.selectedAppModule) }
    }

    @Published var keystorePath: String {
        didSet { save(keystorePath, forKey: AppConfig.UserDefaultsKeys.keystorePath) }
    }

    @Published var keyAlias: String {
        didSet { save(keyAlias, forKey: AppConfig.UserDefaultsKeys.keyAlias) }
    }

    @Published var storePassword: String {
        didSet { save(storePassword, forKey: AppConfig.UserDefaultsKeys.storePassword) }
    }

    @Published var keyPassword: String {
        didSet { save(keyPassword, forKey: AppConfig.UserDefaultsKeys.keyPassword) }
    }

    init() {
        self.projectPath = defaults.string(forKey: AppConfig.UserDefaultsKeys.projectPath) ?? ""
        self.buildType = defaults.string(forKey: AppConfig.UserDefaultsKeys.buildType) ?? AppConfig.Build.releaseBuildType
        self.selectedAppModule = defaults.string(forKey: AppConfig.UserDefaultsKeys.selectedAppModule) ?? AppConfig.Build.defaultModule
        self.keystorePath = defaults.string(forKey: AppConfig.UserDefaultsKeys.keystorePath) ?? ""
        self.keyAlias = defaults.string(forKey: AppConfig.UserDefaultsKeys.keyAlias) ?? ""
        self.storePassword = defaults.string(forKey: AppConfig.UserDefaultsKeys.storePassword) ?? ""
        self.keyPassword = defaults.string(forKey: AppConfig.UserDefaultsKeys.keyPassword) ?? ""
    }

    private func save(_ value: String, forKey key: String) {
        defaults.set(value, forKey: key)
    }
}
