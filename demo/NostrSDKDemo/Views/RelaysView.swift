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
    }

    func record(seen event: NostrEvent) {
        var relayURLs: [URL] = []
        for relayString in event.allValues(forTagName: .webURL) {
            guard let relayURL = normalizedRelayURL(from: relayString) else {
                continue
            }
            relayURLs.append(relayURL)
        }
        seenRelayURLs.formUnion(relayURLs)
    }

    func removeSeen(_ relayURL: URL) {
        seenRelayURLs.remove(relayURL)
    }

    private func normalizedRelayURL(from relayString: String) -> URL? {
        guard let url = URL(string: relayString),
              let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              components.scheme == "ws" || components.scheme == "wss" else {
            return nil
        }
        return url
    }
}

extension Relay {
    var statusImage: some View {
        switch state {
        case .connected: return Image(systemName: "checkmark.circle").foregroundStyle(.green)
        default:        return Image(systemName: "questionmark.circle").foregroundStyle(.yellow)
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
                subtitle: "Connected and seen relay URLs.",
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
                Section("Connected Relays") {
                    ForEach(relays, id: \.url) { relay in
                        HStack(alignment: .center, spacing: 12) {
                            VStack(alignment: .leading, spacing: 6) {
                                Text(relay.url.absoluteString)
                                    .font(.subheadline)
                                    .textSelection(.enabled)
                                Text(relay.state == .connected ? "Connected" : "Not connected")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }

                            Spacer(minLength: 12)

                            relay.statusImage

                            Button(role: .destructive) {
                                pool.remove(relay: relay)
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
                    .onDelete(perform: remove)
                }

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
                                        pool.removeRelay(withURL: relayURL)
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
                                        pool.removeRelay(withURL: relayURL)
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
    
    private var relays: [Relay] {
        pool.relays.sorted()
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
    }
    
    private func remove(at offsets: IndexSet) {
        offsets.map { relays[$0] }.forEach { pool.remove(relay: $0) }
    }
}
