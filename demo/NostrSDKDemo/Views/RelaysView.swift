//
//  RelaysView.swift
//  NostrSDKDemo
//
//  Created by Bryan Montz on 1/1/24.
//

import Foundation
import GnostrSDK
import SwiftUI
import Combine

final class RelayDirectoryStore: ObservableObject {
    @Published var seenRelayURLs: Set<URL> = []
    private var relayPool: RelayPool?
    private var eventsCancellable: AnyCancellable?

    func attach(relayPool: RelayPool) {
        guard self.relayPool !== relayPool else { return }
        self.relayPool = relayPool

        eventsCancellable = relayPool.events
            .receive(on: DispatchQueue.main)
            .sink { [weak self] relayEvent in
                self?.record(seen: relayEvent.event)
            }
    }

    func record(seen relayURLs: [URL]) {
        seenRelayURLs.formUnion(relayURLs)
        deduplicateSeenRelayURLs()
    }

    func record(seen event: NostrEvent) {
        let relayURLs = event.tags
            .filter { $0.name == "relays" || $0.name == "r" }
            .flatMap { relayValues(from: $0) }
            .compactMap { normalizedRelayURL(from: $0) }
        seenRelayURLs.formUnion(relayURLs)
        deduplicateSeenRelayURLs()
    }

    func removeSeen(_ relayURL: URL) {
        seenRelayURLs.remove(relayURL)
    }

    func deduplicateSeenRelayURLs() {
        seenRelayURLs = Set(seenRelayURLs.compactMap { normalizedRelayURL(from: $0.absoluteString) })
    }

    private func normalizedRelayURL(from relayString: String) -> URL? {
        guard let url = URL(string: relayString),
              let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              components.scheme == "ws" || components.scheme == "wss" else {
            return nil
        }
        return url
    }

    private func relayValues(from tag: Tag) -> [String] {
        let rawValues = [tag.value] + tag.otherParameters
        return rawValues.flatMap { relayValues(fromRawValue: $0) }
    }

    private func relayValues(fromRawValue rawValue: String) -> [String] {
        let trimmedValue = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedValue.first == "[",
              let data = trimmedValue.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data),
              let relayStrings = json as? [String] else {
            return [trimmedValue]
        }

        return relayStrings
    }
}

@MainActor
final class RelayInfoLoader: ObservableObject {
    @Published private(set) var relayInfoByURL: [URL: RelayInfo] = [:]
    @Published private(set) var loadingRelayURLs: Set<URL> = []

    private var inFlightTaskURLs: Set<URL> = []

    func refresh(relays: [Relay]) {
        relays.forEach { loadRelayInfo(for: $0.url) }
    }

    func relayInfo(for relayURL: URL) -> RelayInfo? {
        relayInfoByURL[relayURL]
    }

    func isLoading(_ relayURL: URL) -> Bool {
        loadingRelayURLs.contains(relayURL)
    }

    private func loadRelayInfo(for relayURL: URL) {
        guard relayInfoByURL[relayURL] == nil else { return }
        guard let infoURL = relayInfoURL(for: relayURL) else { return }
        guard inFlightTaskURLs.insert(relayURL).inserted else { return }

        loadingRelayURLs.insert(relayURL)

        Task.detached(priority: .utility) { [infoURL, relayURL] in
            defer {
                Task { @MainActor in
                    self.inFlightTaskURLs.remove(relayURL)
                    self.loadingRelayURLs.remove(relayURL)
                }
            }

            do {
                var request = URLRequest(url: infoURL)
                request.setValue("application/nostr+json", forHTTPHeaderField: "Accept")
                let (data, response) = try await URLSession.shared.data(for: request)
                guard let httpResponse = response as? HTTPURLResponse,
                      200..<300 ~= httpResponse.statusCode else {
                    return
                }

                let info = try JSONDecoder().decode(RelayInfo.self, from: data)
                await MainActor.run {
                    self.relayInfoByURL[relayURL] = info
                }
            } catch {
                print("[RelaysView] relay metadata fetch failed url=\(infoURL.absoluteString) error=\(error)")
            }
        }
    }

    private func relayInfoURL(for relayURL: URL) -> URL? {
        guard var components = URLComponents(url: relayURL, resolvingAgainstBaseURL: false) else {
            return nil
        }

        switch components.scheme {
        case "ws":
            components.scheme = "http"
        case "wss":
            components.scheme = "https"
        default:
            return nil
        }

        return components.url
    }
}

extension Relay {
    var statusColor: Color {
        switch state {
        case .connected:
            return .green
        case .connecting:
            return .yellow
        case .notConnected, .error:
            return .red
        }
    }

    var statusImage: some View {
        switch state {
        case .connected:
            return Image(systemName: "checkmark.circle")
                .foregroundStyle(statusColor)
        case .connecting:
            return Image(systemName: "arrow.triangle.2.circlepath.circle")
                .foregroundStyle(statusColor)
        case .notConnected, .error:
            return Image(systemName: "xmark.circle")
                .foregroundStyle(statusColor)
        }
    }
}

struct RelaysView: View {
    
    @EnvironmentObject var pool: RelayPool
    @EnvironmentObject var relayDirectory: RelayDirectoryStore
    @StateObject private var relayInfoLoader = RelayInfoLoader()
    @State private var expandedRelayURLs: Set<URL> = []
    @State private var relaySortOrder: RelaySortOrder = .urlAscending
    @State private var relayStateRefreshToken = 0
    @State private var relayStateCancellable: AnyCancellable?
    
    var body: some View {
        VStack(spacing: 0) {
            ContextAwareHeaderView(
                title: "Relays",
                subtitle: "Connected, connecting, and disconnected relay URLs.",
                systemImage: "network",
                bannerHeight: 180
            )
            .padding(.horizontal)
            .padding(.top, 8)

            HStack {
                Spacer()
                Menu {
                    ForEach(RelaySortOrder.allCases) { sortOrder in
                        Button {
                            relaySortOrder = sortOrder
                        } label: {
                            if relaySortOrder == sortOrder {
                                Label(sortOrder.title, systemImage: "checkmark")
                            } else {
                                Text(sortOrder.title)
                            }
                        }
                    }
                } label: {
                    Label("Sort", systemImage: "arrow.up.arrow.down")
                }
                .buttonStyle(.borderless)

                EditButton()
            }
            .padding(.horizontal)
            .padding(.bottom, 8)

            List {
                relaySection(title: "Connected", relays: groupedRelays.connected)
                relaySection(title: "Connecting", relays: groupedRelays.connecting)
                relaySection(title: "Disconnected", relays: groupedRelays.disconnected)

                Section {
                    if seenRelays.isEmpty {
                        Text("No seen relays yet.")
                            .foregroundColor(.secondary)
                    } else {
                        ForEach(seenRelays, id: \.self) { relayURL in
                            HStack {
                                Text(relayURL.absoluteString)
                                Spacer()
                                if contains(relayURL) {
                                    Button(role: .destructive) {
                                        disconnect(relayURL)
                                    } label: {
                                        Text("Remove")
                                    }
                                } else {
                                    Button("Add") {
                                        add(relayURL)
                                    }
                                }
                            }
                            .swipeActions(edge: .trailing) {
                                if contains(relayURL) == false {
                                    Button(role: .destructive) {
                                        relayDirectory.removeSeen(relayURL)
                                    } label: {
                                        Label("Remove", systemImage: "trash")
                                    }
                                } else {
                                    Button(role: .destructive) {
                                        disconnect(relayURL)
                                    } label: {
                                        Label("Remove", systemImage: "trash")
                                    }
                                }
                            }
                        }
                    }
                } header: {
                    HStack {
                        Text("Seen Relays")
                        Spacer(minLength: 12)

                        Button("Add All") {
                            addAllSeenRelays()
                        }
                        .buttonStyle(.borderless)

                        Button(role: .destructive) {
                            removeAllSeenRelays()
                        } label: {
                            Text("Remove All")
                        }
                        .buttonStyle(.borderless)
                    }
                }
            }
            .onAppear {
                bindRelayStateUpdates()
                relayInfoLoader.refresh(relays: relays)
            }
            .onReceive(pool.$relays) { _ in
                bindRelayStateUpdates()
                relayInfoLoader.refresh(relays: relays)
                relayStateRefreshToken += 1
            }
        }
    }
    
    private var groupedRelays: (connected: [Relay], connecting: [Relay], disconnected: [Relay]) {
        let sorted = sorted(relays: Array(pool.relays))
        return (
            connected: sorted.filter { $0.state == .connected },
            connecting: sorted.filter { $0.state == .connecting },
            disconnected: sorted.filter {
                switch $0.state {
                case .notConnected, .error:
                    return true
                case .connected, .connecting:
                    return false
                }
            }
        )
    }

    private var relays: [Relay] {
        sorted(relays: Array(pool.relays))
    }

    private func bindRelayStateUpdates() {
        relayStateCancellable = Publishers.MergeMany(
            pool.relays.map { relay in
                relay.$state.map { _ in () }.eraseToAnyPublisher()
            }
        )
        .receive(on: DispatchQueue.main)
        .sink { _ in
            relayStateRefreshToken += 1
        }
    }

    @ViewBuilder
    private func relaySection(title: String, relays: [Relay]) -> some View {
        Section(title) {
            if relays.isEmpty {
                Text("No \(title.lowercased()) relays.")
                    .foregroundColor(.secondary)
            } else {
                ForEach(relays, id: \.url) { relay in
                    DisclosureGroup(isExpanded: binding(for: relay.url)) {
                        relayMetadataDetails(for: relay)
                            .padding(.top, 10)
                    } label: {
                        HStack(alignment: .center, spacing: 12) {
                            VStack(alignment: .leading, spacing: 6) {
                                Text(relay.url.absoluteString)
                                    .font(.subheadline)
                                    .textSelection(.enabled)
                            }

                            Spacer(minLength: 12)

                            relay.statusImage

                            Button(role: .destructive) {
                                disconnect(relay)
                            } label: {
                                Label("Disconnect", systemImage: "xmark.circle.fill")
                            }
                            .buttonStyle(.borderless)
                        }
                    }
                    .padding(.vertical, 6)
                    .padding(.horizontal, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color(.secondarySystemBackground))
                    )
                    .onAppear {
                        relayInfoLoader.refresh(relays: [relay])
                    }
                }
                .onDelete { offsets in
                    remove(relays: relays, at: offsets)
                }
            }
        }
    }

    @ViewBuilder
    private func relayMetadataDetails(for relay: Relay) -> some View {
        let info = relayInfoLoader.relayInfo(for: relay.url)

        VStack(alignment: .leading, spacing: 10) {
            if relayInfoLoader.isLoading(relay.url) && info == nil {
                ProgressView("Loading relay metadata...")
                    .font(.caption)
            } else if let info {
                RelayMetadataDetailView(info: info,
                                        connectedRelays: connectedRelays,
                                        relayInfoLoader: relayInfoLoader)
            } else {
                Text("No relay metadata available.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var seenRelays: [URL] {
        sorted(relayURLs: Array(relayDirectory.seenRelayURLs.filter { contains($0) == false }))
    }

    private var connectedRelays: [Relay] {
        relays.filter { $0.state == .connected }
    }

    private func contains(_ relayURL: URL) -> Bool {
        relays.contains(where: { $0.url == relayURL })
    }

    private func add(_ relayURL: URL) {
        guard contains(relayURL) == false, let relay = try? Relay(url: relayURL) else {
            return
        }
        pool.add(relay: relay)
        relayDirectory.removeSeen(relayURL)
        relayDirectory.deduplicateSeenRelayURLs()
    }

    private func addAllSeenRelays() {
        seenRelays.forEach { add($0) }
    }

    private func removeAllSeenRelays() {
        seenRelays.forEach { relayDirectory.removeSeen($0) }
        relayDirectory.deduplicateSeenRelayURLs()
    }

    private func disconnect(_ relay: Relay) {
        relayDirectory.record(seen: [relay.url])
        pool.remove(relay: relay)
        relayDirectory.deduplicateSeenRelayURLs()
    }

    private func disconnect(_ relayURL: URL) {
        relayDirectory.record(seen: [relayURL])
        pool.removeRelay(withURL: relayURL)
        relayDirectory.deduplicateSeenRelayURLs()
    }
    
    private func remove(relays: [Relay], at offsets: IndexSet) {
        offsets.map { relays[$0] }.forEach { disconnect($0) }
    }

    private func binding(for relayURL: URL) -> Binding<Bool> {
        Binding(
            get: { expandedRelayURLs.contains(relayURL) },
            set: { isExpanded in
                if isExpanded {
                    expandedRelayURLs.insert(relayURL)
                    relayInfoLoader.refresh(relays: relays.filter { $0.url == relayURL })
                } else {
                    expandedRelayURLs.remove(relayURL)
                }
            }
        )
    }

    private func sorted(relays: [Relay]) -> [Relay] {
        switch relaySortOrder {
        case .urlAscending:
            return relays.sorted { $0.url.absoluteString < $1.url.absoluteString }
        case .urlDescending:
            return relays.sorted { $0.url.absoluteString > $1.url.absoluteString }
        }
    }

    private func sorted(relayURLs: [URL]) -> [URL] {
        switch relaySortOrder {
        case .urlAscending:
            return relayURLs.sorted { $0.absoluteString < $1.absoluteString }
        case .urlDescending:
            return relayURLs.sorted { $0.absoluteString > $1.absoluteString }
        }
    }
}

private enum RelaySortOrder: String, CaseIterable, Identifiable {
    case urlAscending
    case urlDescending

    var id: String { rawValue }

    var title: String {
        switch self {
        case .urlAscending:
            return "URL A-Z"
        case .urlDescending:
            return "URL Z-A"
        }
    }
}

private struct RelayMetadataDetailView: View {
    let info: RelayInfo
    let connectedRelays: [Relay]
    @ObservedObject var relayInfoLoader: RelayInfoLoader

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let name = info.name, name.isEmpty == false {
                detailRow(title: "Name", value: name)
            }
            if let description = info.description, description.isEmpty == false {
                detailRow(title: "Description", value: description)
            }
            if let software = info.software, software.isEmpty == false {
                detailRow(title: "Software", value: software)
            }
            if let version = info.version, version.isEmpty == false {
                detailRow(title: "Version", value: version)
            }
            if let contact = info.contactPubkey, contact.isEmpty == false {
                detailRow(title: "Contact Pubkey", value: contact)
            } else if let alternativeContact = info.alternativeContact, alternativeContact.isEmpty == false {
                detailRow(title: "Contact", value: alternativeContact)
            }
            if let supportedNIPs = info.supportedNIPs, supportedNIPs.isEmpty == false {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Supported NIPs")
                        .font(.caption2.weight(.semibold))
                        .foregroundColor(.secondary)

                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 88), alignment: .leading)], alignment: .leading, spacing: 8) {
                        ForEach(supportedNIPs, id: \.self) { nip in
                            NavigationLink {
                                RelayNIPConnectedRelaysView(nip: nip,
                                                            connectedRelays: connectedRelays,
                                                            relayInfoLoader: relayInfoLoader)
                            } label: {
                                Text("NIP-\(nip)")
                                    .font(.caption.weight(.semibold))
                                    .foregroundColor(.primary)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .frame(maxWidth: .infinity)
                                    .background(
                                        RoundedRectangle(cornerRadius: 999, style: .continuous)
                                            .fill(Color(.tertiarySystemFill))
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            if let relayCountries = info.relayCountries, relayCountries.isEmpty == false {
                detailRow(title: "Countries", value: relayCountries.joined(separator: ", "))
            }
            if let languageTags = info.languageTags, languageTags.isEmpty == false {
                detailRow(title: "Languages", value: languageTags.joined(separator: ", "))
            }
            if let tags = info.tags, tags.isEmpty == false {
                detailRow(title: "Tags", value: tags.joined(separator: ", "))
            }

            if let limits = info.limitations {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Limitations")
                        .font(.caption.weight(.semibold))
                    if let maxSubscriptions = limits.maxSubscriptions {
                        detailRow(title: "Max subscriptions", value: String(maxSubscriptions))
                    }
                    if let maxFilters = limits.maxFilters {
                        detailRow(title: "Max filters", value: String(maxFilters))
                    }
                    if let maxLimit = limits.maxLimit {
                        detailRow(title: "Max limit", value: String(maxLimit))
                    }
                    if let maxMessageLength = limits.maxMessageLength {
                        detailRow(title: "Max message length", value: String(maxMessageLength))
                    }
                    if let maxEventTags = limits.maxEventTags {
                        detailRow(title: "Max event tags", value: String(maxEventTags))
                    }
                    if let authRequired = limits.isAuthenticationRequired {
                        detailRow(title: "Auth required", value: authRequired ? "Yes" : "No")
                    }
                    if let restrictedWrites = limits.isWriteRestricted {
                        detailRow(title: "Write restricted", value: restrictedWrites ? "Yes" : "No")
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private func detailRow(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption2.weight(.semibold))
                .foregroundColor(.secondary)
            Text(value)
                .font(.caption)
                .foregroundColor(.primary)
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

private struct RelayNIPConnectedRelaysView: View {
    let nip: Int
    let connectedRelays: [Relay]
    @ObservedObject var relayInfoLoader: RelayInfoLoader

    private var relaysSupportingNIP: [Relay] {
        connectedRelays.filter { relay in
            relayInfoLoader.relayInfo(for: relay.url)?.supportedNIPs?.contains(nip) == true
        }
    }

    var body: some View {
        List {
            if relaysSupportingNIP.isEmpty {
                Text("No connected relays support NIP-\(nip).")
                    .foregroundColor(.secondary)
            } else {
                ForEach(relaysSupportingNIP, id: \.url) { relay in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(alignment: .center, spacing: 12) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(relay.url.absoluteString)
                                    .font(.subheadline)
                                    .textSelection(.enabled)
                                Text("Connected")
                                    .font(.caption)
                                    .foregroundColor(.green)
                            }

                            Spacer(minLength: 12)

                            relay.statusImage
                        }

                        if let info = relayInfoLoader.relayInfo(for: relay.url) {
                            RelayMetadataCompactView(info: info)
                        }
                    }
                    .padding(.vertical, 6)
                }
            }
        }
        .navigationTitle("NIP-\(nip) relays")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct RelayMetadataCompactView: View {
    let info: RelayInfo

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if let name = info.name, name.isEmpty == false {
                Text(name)
                    .font(.caption.weight(.semibold))
            }
            if let description = info.description, description.isEmpty == false {
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(3)
            }
        }
    }
}
