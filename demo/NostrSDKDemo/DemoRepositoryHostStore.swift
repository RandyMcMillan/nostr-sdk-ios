//
//  DemoRepositoryHostStore.swift
//  NostrSDKDemo
//
//  Created by Copilot on 6/9/26.
//

import Combine
import Foundation
import GnostrSDK
import SwiftGitX
import SwiftUI
import Darwin

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

    enum RepositoryAvailability: Equatable {
        case checking
        case available
        case unavailable
    }

    @Published private(set) var repositories: [HostedRepository] = []
    @Published private(set) var seenRepositoryURLs: Set<URL> = []
    @Published private(set) var cloningRemoteURLs: Set<URL> = []
    @Published private(set) var failedRepositoryURLs: Set<URL> = []
    @Published private(set) var repositoryAvailabilityByURL: [URL: RepositoryAvailability] = [:]
    @Published private(set) var checkingRepositoryURLs: Set<URL> = []
    @Published private(set) var lastErrorMessage: String?

    private var cancellables = Set<AnyCancellable>()
    private var gitSettingsStore: DemoGitSettingsStore?
    private var availabilityRefreshTask: Task<Void, Never>?
    private var repositoryDiscoveryTask: Task<Void, Never>?

    func attach(gitSettingsStore: DemoGitSettingsStore) {
        self.gitSettingsStore = gitSettingsStore
        gitSettingsStore.registerRepositoryRootPath(gitSettingsStore.appRepositoriesRootPath)
        refreshHostedRepositories(in: gitSettingsStore.repositoryRootURLs)

        gitSettingsStore.$repositoryRootPaths
            .receive(on: DispatchQueue.main)
            .sink { [weak self, weak gitSettingsStore] _ in
                guard let self, let gitSettingsStore else { return }
                self.refreshHostedRepositories(in: gitSettingsStore.repositoryRootURLs)
            }
            .store(in: &cancellables)
    }

    deinit {
        availabilityRefreshTask?.cancel()
        repositoryDiscoveryTask?.cancel()
    }

    func isCloning(_ remoteURL: URL) -> Bool {
        cloningRemoteURLs.contains(remoteURL)
    }

    func attach(appPrimeStore: DemoAppPrimeStore) {
        updateSeenRepositories(from: appPrimeStore.repositoryEventByRepoIDAndKind)
        record(seen: Array(appPrimeStore.seenRepositoryURLs))
        refreshAvailability(for: seenRepositoryURLs, force: true)
        startAvailabilityRefreshLoop()

        appPrimeStore.$repositoryEventByRepoIDAndKind
            .receive(on: DispatchQueue.main)
            .sink { [weak self] repositoryEventByRepoIDAndKind in
                self?.updateSeenRepositories(from: repositoryEventByRepoIDAndKind)
            }
            .store(in: &cancellables)

        appPrimeStore.$seenRepositoryURLs
            .receive(on: DispatchQueue.main)
            .sink { [weak self] repositoryURLs in
                self?.record(seen: Array(repositoryURLs))
                self?.refreshAvailability(for: repositoryURLs, force: true)
            }
            .store(in: &cancellables)
    }

    func record(seen repositoryURLs: [URL]) {
        seenRepositoryURLs.formUnion(repositoryURLs)
    }

    func removeSeen(_ repositoryURL: URL) {
        seenRepositoryURLs.remove(repositoryURL)
        failedRepositoryURLs.remove(repositoryURL)
        repositoryAvailabilityByURL.removeValue(forKey: repositoryURL)
        checkingRepositoryURLs.remove(repositoryURL)
    }

    func removeHostedRepository(_ repositoryURL: URL) {
        repositories.removeAll { $0.remoteURL == repositoryURL }
    }

#if DEBUG
    nonisolated static func createRepositoryFixture(at repositoryURL: URL, remoteURL: URL) throws {
        let repository = try Repository.create(at: repositoryURL)
        _ = try repository.remote.add(named: "origin", at: remoteURL)
    }
#endif

    func refreshHostedRepositories(in rootURLs: [URL]) {
        repositoryDiscoveryTask?.cancel()

        repositoryDiscoveryTask = Task.detached(priority: .background) { [weak self] in
            let discoveredRepositories = Self.discoverHostedRepositories(in: rootURLs)
            guard let self else { return }
            await MainActor.run {
                for repository in discoveredRepositories {
                    self.repositories.removeAll { $0.remoteURL == repository.remoteURL }
                    self.repositories.insert(repository, at: 0)
                    self.repositoryAvailabilityByURL[repository.remoteURL] = .available
                    self.failedRepositoryURLs.remove(repository.remoteURL)
                    self.checkingRepositoryURLs.remove(repository.remoteURL)
                }
            }
        }
    }

    func cloneRepository(from remoteURL: URL) {
        guard cloningRemoteURLs.insert(remoteURL).inserted else { return }
        let rootURL = gitSettingsStore?.appRepositoriesRootURL ?? DemoGitSettingsStore.defaultRepositoriesRootURL

        Task.detached(priority: .userInitiated) { [weak self] in
            guard let self else { return }
            defer {
                Task { @MainActor in
                    self.cloningRemoteURLs.remove(remoteURL)
                }
            }

            do {
                let localURL = Self.localCloneURL(for: remoteURL, rootURL: rootURL)

                if FileManager.default.fileExists(atPath: localURL.path) {
                    _ = try Repository.open(at: localURL)
                    await self.record(remoteURL: remoteURL, localURL: localURL)
                    await MainActor.run {
                        self.removeSeen(remoteURL)
                    }
                    return
                }

                let repository = try await Repository.clone(from: remoteURL, to: localURL)
                let workingDirectory = try repository.workingDirectory
                await self.record(remoteURL: remoteURL, localURL: workingDirectory)
                await MainActor.run {
                    self.removeSeen(remoteURL)
                }
            } catch {
                await MainActor.run {
                    self.failedRepositoryURLs.insert(remoteURL)
                    self.repositoryAvailabilityByURL[remoteURL] = .unavailable
                    self.checkingRepositoryURLs.remove(remoteURL)
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
            failedRepositoryURLs.remove(remoteURL)
            repositoryAvailabilityByURL[remoteURL] = .available
            checkingRepositoryURLs.remove(remoteURL)
            lastErrorMessage = nil
        }
    }

    nonisolated private static func localCloneURL(for remoteURL: URL, rootURL: URL) -> URL {
        return rootURL.appendingPathComponent(safeDirectoryName(for: remoteURL), isDirectory: true)
    }

    nonisolated private static func safeDirectoryName(for remoteURL: URL) -> String {
        let candidate = [remoteURL.host, remoteURL.path]
            .compactMap { $0 }
            .joined(separator: "-")
        let sanitized = candidate.replacingOccurrences(of: #"[^A-Za-z0-9._-]+"#, with: "-", options: .regularExpression)
        let trimmed = sanitized.trimmingCharacters(in: CharacterSet(charactersIn: "-"))
        return trimmed.isEmpty ? "repository" : trimmed
    }

    nonisolated static func normalizedRepositoryCloneURL(from value: String) -> URL? {
        let trimmedValue = value.trimmingCharacters(in: .whitespacesAndNewlines)

        if let url = URL(string: trimmedValue), url.scheme != nil {
            return url
        }

        guard trimmedValue.contains("@"), trimmedValue.contains(":"), trimmedValue.contains("://") == false else {
            return nil
        }

        let components = trimmedValue.split(separator: ":", maxSplits: 1, omittingEmptySubsequences: false)
        guard components.count == 2 else { return nil }
        return URL(string: "ssh://\(components[0])/\(components[1])")
    }

    private func updateSeenRepositories(from repositoryEventByRepoIDAndKind: [String: [Int: NostrEvent]]) {
        let repositoryURLs = repositoryEventByRepoIDAndKind.values
            .flatMap { $0.values }
            .flatMap { event in
                event.tags.compactMap { tag -> URL? in
                    guard tag.name == "clone" else { return nil }
                    return DemoRepositoryHostStore.normalizedRepositoryCloneURL(from: tag.value)
                }
            }

        record(seen: repositoryURLs)
        refreshAvailability(for: Set(repositoryURLs), force: false)
    }

    private func refreshAvailability(for repositoryURLs: Set<URL>, force: Bool) {
        let repositoryURLsToCheck = repositoryURLs.filter { checkingRepositoryURLs.contains($0) == false && (force || repositoryAvailabilityByURL[$0] == nil) }
        guard repositoryURLsToCheck.isEmpty == false else { return }

        checkingRepositoryURLs.formUnion(repositoryURLsToCheck)
        for repositoryURL in repositoryURLsToCheck {
            repositoryAvailabilityByURL[repositoryURL] = .checking
            Task.detached(priority: .background) { [weak self] in
                let isAvailable = Self.isRepositoryAvailable(repositoryURL)
                guard let self else { return }
                await MainActor.run {
                    self.checkingRepositoryURLs.remove(repositoryURL)
                    self.repositoryAvailabilityByURL[repositoryURL] = isAvailable ? .available : .unavailable
                    if isAvailable {
                        self.failedRepositoryURLs.remove(repositoryURL)
                    }
                }
            }
        }
    }

    private func startAvailabilityRefreshLoop() {
        guard availabilityRefreshTask == nil else { return }

        availabilityRefreshTask = Task.detached(priority: .background) { [weak self] in
            while Task.isCancelled == false {
                try? await Task.sleep(for: .seconds(60))
                guard let self else { return }
                await MainActor.run {
                    self.refreshAvailability(for: self.seenRepositoryURLs, force: true)
                }
            }
        }
    }

    nonisolated private static func discoverHostedRepositories(in rootURLs: [URL]) -> [HostedRepository] {
        var discoveredRepositories: [HostedRepository] = []
        var seenRemoteURLs = Set<URL>()

        for rootURL in rootURLs {
            let rootPath = rootURL.path
            guard FileManager.default.fileExists(atPath: rootPath) else { continue }

            let contents = (try? FileManager.default.contentsOfDirectory(
                at: rootURL,
                includingPropertiesForKeys: [.isDirectoryKey],
                options: [.skipsHiddenFiles]
            )) ?? []

            for candidateURL in contents {
                guard isDirectory(candidateURL) else { continue }
                guard let repository = try? Repository.open(at: candidateURL) else { continue }
                guard let remote = repository.remote["origin"] else { continue }
                guard seenRemoteURLs.insert(remote.url).inserted else { continue }

                let localURL = (try? repository.workingDirectory) ?? candidateURL
                discoveredRepositories.append(HostedRepository(remoteURL: remote.url, localURL: localURL))
            }
        }

        return discoveredRepositories.sorted { $0.remoteURL.absoluteString < $1.remoteURL.absoluteString }
    }

    nonisolated private static func isDirectory(_ url: URL) -> Bool {
        (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true
    }

    nonisolated private static func isRepositoryAvailable(_ repositoryURL: URL) -> Bool {
        var pid = pid_t()
        let arguments = [
            "git",
            "ls-remote",
            "--exit-code",
            repositoryURL.absoluteString,
            "HEAD"
        ]

        let executable = "/usr/bin/git"
        let argv = arguments.map { strdup($0) }
        defer { argv.forEach { free($0) } }

        var cArguments: [UnsafeMutablePointer<CChar>?] = argv
        cArguments.append(nil)

        let spawnStatus = cArguments.withUnsafeMutableBufferPointer { buffer in
            posix_spawn(&pid, executable, nil, nil, buffer.baseAddress, environ)
        }

        guard spawnStatus == 0 else {
            return false
        }

        var waitStatus: Int32 = 0
        guard waitpid(pid, &waitStatus, 0) != -1 else {
            return false
        }

        return (waitStatus >> 8) == 0
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
                        HStack(alignment: .top, spacing: 12) {
                            NavigationLink(destination: RepoView(repository: repository)) {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text(repository.displayName)
                                        .font(.headline)
                                    Text(repository.remoteURL.absoluteString)
                                        .font(.caption.monospaced())
                                        .foregroundColor(.secondary)
                                        .lineLimit(2)
                                        .textSelection(.enabled)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            Spacer(minLength: 12)
                            Button {
                                repositoryHostStore.removeHostedRepository(repository.remoteURL)
                            } label: {
                                Image(systemName: "trash")
                                    .foregroundStyle(.red)
                                    .padding(8)
                                    .background(.red.opacity(0.12), in: Circle())
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Remove repository")
                        }
                        .padding(.vertical, 4)
                    }
                }
            }

            Section("Seen Repositories") {
                if seenRepositories.isEmpty {
                    Text("No seen repositories yet.")
                        .foregroundColor(.secondary)
                } else {
                    if availableSeenRepositories.isEmpty == false {
                        Section("Available") {
                            ForEach(availableSeenRepositories, id: \.self) { repositoryURL in
                                seenRepositoryRow(for: repositoryURL)
                            }
                        }
                    }

                    if unavailableSeenRepositories.isEmpty == false {
                        Section("Unavailable") {
                            ForEach(unavailableSeenRepositories, id: \.self) { repositoryURL in
                                seenRepositoryRow(for: repositoryURL)
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("Hosted Repos")
    }

    private var seenRepositories: [URL] {
        repositoryHostStore.seenRepositoryURLs
            .filter { hasHostedRepository($0) == false }
            .sorted { $0.absoluteString < $1.absoluteString }
    }

    private var availableSeenRepositories: [URL] {
        seenRepositories.filter { availability(for: $0) == .available }
    }

    private var unavailableSeenRepositories: [URL] {
        seenRepositories.filter { availability(for: $0) != .available }
    }

    private func hasHostedRepository(_ repositoryURL: URL) -> Bool {
        repositoryHostStore.repositories.contains(where: { $0.remoteURL == repositoryURL })
    }

    private func add(_ repositoryURL: URL) {
        guard hasHostedRepository(repositoryURL) == false else { return }
        repositoryHostStore.cloneRepository(from: repositoryURL)
    }

    @ViewBuilder
    private func seenRepositoryRow(for repositoryURL: URL) -> some View {
        HStack {
            availabilityIcon(for: repositoryURL)
            Text(repositoryURL.absoluteString)
                .foregroundColor(rowColor(for: repositoryURL))
                .textSelection(.enabled)
            Spacer()
            if hasHostedRepository(repositoryURL) {
                Button(role: .destructive) {
                    repositoryHostStore.removeHostedRepository(repositoryURL)
                } label: {
                    Text("Remove")
                }
            } else {
                Button("Add") {
                    add(repositoryURL)
                }
            }
        }
        .swipeActions(edge: .trailing) {
            if hasHostedRepository(repositoryURL) {
                Button(role: .destructive) {
                    repositoryHostStore.removeHostedRepository(repositoryURL)
                } label: {
                    Label("Remove", systemImage: "trash")
                }
            } else {
                Button(role: .destructive) {
                    repositoryHostStore.removeSeen(repositoryURL)
                } label: {
                    Label("Remove", systemImage: "trash")
                }
            }
        }
    }

    private func availability(for repositoryURL: URL) -> DemoRepositoryHostStore.RepositoryAvailability {
        if repositoryHostStore.checkingRepositoryURLs.contains(repositoryURL) {
            return .checking
        }

        return repositoryHostStore.repositoryAvailabilityByURL[repositoryURL] ?? .checking
    }

    private func rowColor(for repositoryURL: URL) -> Color {
        .primary
    }

    @ViewBuilder
    private func availabilityIcon(for repositoryURL: URL) -> some View {
        switch availability(for: repositoryURL) {
        case .available:
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
        case .checking:
            Image(systemName: "questionmark.circle.fill")
                .foregroundStyle(.yellow)
        case .unavailable:
            Image(systemName: "xmark.circle.fill")
                .foregroundStyle(.red)
        }
    }
}

struct RepoView: View {
    let repository: DemoRepositoryHostStore.HostedRepository

    var body: some View {
        Form {
            Section("Repository") {
                LabeledContent("Name") {
                    Text(repository.displayName)
                }
                LabeledContent("Remote") {
                    Text(repository.remoteURL.absoluteString)
                        .multilineTextAlignment(.trailing)
                        .textSelection(.enabled)
                }
                LabeledContent("Local") {
                    Text(repository.localURL.path)
                        .multilineTextAlignment(.trailing)
                }
            }
        }
        .navigationTitle(repository.displayName)
    }
}
