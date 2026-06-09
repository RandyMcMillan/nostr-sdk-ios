//
//  DemoGitSettingsStore.swift
//  NostrSDKDemo
//
//  Created by Copilot on 6/9/26.
//

import Foundation
import SwiftUI

final class DemoGitSettingsStore: ObservableObject {
    private enum Keys {
        static let appRepositoriesRootPath = "demo.git.appRepositoriesRootPath"
    }

    @Published var appRepositoriesRootPath: String {
        didSet {
            UserDefaults.standard.set(appRepositoriesRootPath, forKey: Keys.appRepositoriesRootPath)
        }
    }

    init() {
        appRepositoriesRootPath = UserDefaults.standard.string(forKey: Keys.appRepositoriesRootPath)
        ?? Self.defaultRepositoriesRootPath
    }

    var appRepositoriesRootURL: URL {
        let trimmed = appRepositoriesRootPath.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            return Self.defaultRepositoriesRootURL
        }
        return URL(fileURLWithPath: (trimmed as NSString).expandingTildeInPath, isDirectory: true)
    }

    func resetAppRepositoriesRootPath() {
        appRepositoriesRootPath = Self.defaultRepositoriesRootPath
    }

    static var defaultRepositoriesRootURL: URL {
        let baseURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
        ?? FileManager.default.temporaryDirectory

        return baseURL
            .appendingPathComponent("NostrSDKDemo", isDirectory: true)
            .appendingPathComponent("HostedRepos", isDirectory: true)
    }

    static var defaultRepositoriesRootPath: String {
        defaultRepositoriesRootURL.path
    }
}
