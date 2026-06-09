//
//  DemoRepositoryHostStore.swift
//  NostrSDKDemo
//
//  Created by Copilot on 6/9/26.
//

import Combine
import Foundation
import SwiftGitX
import SwiftUI

@MainActor
final class DemoRepositoryHostStore: ObservableObject {
    struct HostedRepository: Identifiable, Hashable {
        let remoteURL: URL
        let localURL: URL

        var id: String { remoteURL.absoluteString }

        var displayName: String {
            if let host = remoteURL.host, let lastPathComponent = remoteURL.path.split(separator: "/").last, lastPathComponent.isEmpty == false {
                return "\(host)/\(lastPathComponent)"
            }
            if let host = remoteURL.host {
                return host
            }
            return remoteURL.absoluteString
        }
    }

    @Published private(set) var repositories: [HostedRepository] = []
    @Published private(set) var cloningRemoteURLs: Set<URL> = []
    @Published private(set) var lastErrorMessage: String?

    func isCloning(_ remoteURL: URL) -> Bool {
        cloningRemoteURLs.contains(remoteURL)
    }

    func cloneRepository(from remoteURL: URL) {
        guard cloningRemoteURLs.insert(remoteURL).inserted else { return }

        Task.detached(priority: .userInitiated) { [weak self] in
            guard let self else { return }
            defer {
                Task { @MainActor in
                    self.cloningRemoteURLs.remove(remoteURL)
                }
            }

            do {
                let localURL = try self.localCloneURL(for: remoteURL)

                if FileManager.default.fileExists(atPath: localURL.path) {
                    _ = try Repository.open(at: localURL)
                    await self.record(remoteURL: remoteURL, localURL: localURL)
                    return
                }

                let repository = try await Repository.clone(from: remoteURL, to: localURL)
                let workingDirectory = try repository.workingDirectory
                await self.record(remoteURL: remoteURL, localURL: workingDirectory)
            } catch {
                await MainActor.run {
                    self.lastErrorMessage = error.localizedDescription
                }
            }
        }
    }

    private func record(remoteURL: URL, localURL: URL) async {
        await MainActor.run {
            let hostedRepository = HostedRepository(remoteURL: remoteURL, localURL: localURL)
            repositories.removeAll { $0.remoteURL == remoteURL }
            repositories.insert(hostedRepository, at: 0)
            lastErrorMessage = nil
        }
    }

    nonisolated private func localCloneURL(for remoteURL: URL) throws -> URL {
        let rootURL = try cloneRootURL()
        return rootURL.appendingPathComponent(safeDirectoryName(for: remoteURL), isDirectory: true)
    }

    nonisolated private func cloneRootURL() throws -> URL {
        guard let baseURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            throw NSError(domain: "DemoRepositoryHostStore", code: 1, userInfo: [NSLocalizedDescriptionKey: "Application Support directory not available"])
        }

        let rootURL = baseURL
            .appendingPathComponent("NostrSDKDemo", isDirectory: true)
            .appendingPathComponent("HostedRepos", isDirectory: true)

        try FileManager.default.createDirectory(at: rootURL, withIntermediateDirectories: true)
        return rootURL
    }

    nonisolated private func safeDirectoryName(for remoteURL: URL) -> String {
        let candidate = [remoteURL.host, remoteURL.path]
            .compactMap { $0 }
            .joined(separator: "-")
        let sanitized = candidate.replacingOccurrences(of: #"[^A-Za-z0-9._-]+"#, with: "-", options: .regularExpression)
        let trimmed = sanitized.trimmingCharacters(in: CharacterSet(charactersIn: "-"))
        return trimmed.isEmpty ? "repository" : trimmed
    }
}

struct HostedRepositoriesView: View {
    @EnvironmentObject private var repositoryHostStore: DemoRepositoryHostStore

    var body: some View {
        List {
            if let lastErrorMessage = repositoryHostStore.lastErrorMessage {
                Section {
                    Text(lastErrorMessage)
                        .foregroundColor(.red)
                }
            }

            Section("Hosted Repositories") {
                if repositoryHostStore.repositories.isEmpty {
                    Text("No hosted repositories yet.")
                        .foregroundColor(.secondary)
                } else {
                    ForEach(repositoryHostStore.repositories) { repository in
                        VStack(alignment: .leading, spacing: 6) {
                            Text(repository.displayName)
                                .font(.headline)
                            Text(repository.remoteURL.absoluteString)
                                .font(.caption.monospaced())
                                .foregroundColor(.secondary)
                                .lineLimit(2)
                            Text(repository.localURL.path)
                                .font(.caption2.monospaced())
                                .foregroundColor(.secondary)
                                .lineLimit(2)
                        }
                    }
                }
            }
        }
        .navigationTitle("Hosted Repos")
    }
}
