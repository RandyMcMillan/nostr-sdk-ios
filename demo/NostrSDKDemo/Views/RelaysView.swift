//
//  RelaysView.swift
//  NostrSDKDemo
//
//  Created by Bryan Montz on 1/1/24.
//

import Foundation
import GnostrSDK
import SwiftUI

final class RelayDirectoryStore: ObservableObject {
    @Published var seenRelayURLs: Set<URL> = []

    func record(seen relayURLs: [URL]) {
        seenRelayURLs.formUnion(relayURLs)
    }

    func removeSeen(_ relayURL: URL) {
        seenRelayURLs.remove(relayURL)
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
        List {
            Section("Connected Relays") {
                ForEach(relays, id: \.url) { relay in
                    HStack {
                        Text(relay.url.absoluteString)
                        Spacer()
                        relay.statusImage
                    }
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
        .navigationTitle("Relays")
        .toolbar {
            EditButton()
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
