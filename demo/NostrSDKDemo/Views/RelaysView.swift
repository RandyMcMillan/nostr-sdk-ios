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
                EditButton()
            }
            .padding(.horizontal)
            .padding(.bottom, 8)

            List {
                relaySection(title: "Connected", relays: groupedRelays.connected)
                relaySection(title: "Connecting", relays: groupedRelays.connecting)
                relaySection(title: "Disconnected", relays: groupedRelays.disconnected)

                Section("Seen Relays") {
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
                }
            }
        }
    }
    
    private var groupedRelays: (connected: [Relay], connecting: [Relay], disconnected: [Relay]) {
        let sorted = pool.relays.sorted()
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
        pool.relays.sorted()
    }

    @ViewBuilder
    private func relaySection(title: String, relays: [Relay]) -> some View {
        Section(title) {
            if relays.isEmpty {
                Text("No \(title.lowercased()) relays.")
                    .foregroundColor(.secondary)
            } else {
                ForEach(relays, id: \.url) { relay in
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
                    .padding(.vertical, 6)
                    .padding(.horizontal, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color(.secondarySystemBackground))
                    )
                }
                .onDelete { offsets in
                    remove(relays: relays, at: offsets)
                }
            }
        }
    }

    private var seenRelays: [URL] {
        relayDirectory.seenRelayURLs
            .filter { contains($0) == false }
            .sorted { $0.absoluteString < $1.absoluteString }
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
}
