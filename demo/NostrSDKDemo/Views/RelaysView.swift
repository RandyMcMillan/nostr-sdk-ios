//
//  RelaysView.swift
//  NostrSDKDemo
//
//  Created by Bryan Montz on 1/1/24.
//

import Foundation
import NostrSDK
import SwiftUI

extension Relay {
    var statusImage: some View {
        switch state {
        case .connected: return Image(systemName: "checkmark.circle").foregroundStyle(.green)
        default:        return Image(systemName: "questionmark.circle").foregroundStyle(.yellow)
        }
    }
}

struct RelaysView: View {

    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var pool: RelayPool
    @State private var newRelayURLString: String = ""

    var body: some View {

            Section(header: Text("Add New Relay URL")) {
                TextField("wss://relay.example.com", text: $newRelayURLString)
                    .textInputAutocapitalization(.never)
                    .keyboardType(.URL)
            }

        List {
            ForEach(relays, id: \.url) { relay in
                HStack {
                    Text(relay.url.absoluteString)
                    Spacer()
                    relay.statusImage
                }
            }
            .onDelete(perform: remove)
        }
        .navigationTitle("Relays")
        .toolbar {

            Button("Add") {
                if let relayURL = URL(string: newRelayURLString.lowercased()) {
                    do {
                        let newRelay = try Relay(url: relayURL)
                        pool.add(relay: newRelay)
                    } catch {
                        print("Error creating relay from URL: \(error.localizedDescription)")
                    }
                }
            }
            .disabled(newRelayURLString.isEmpty)

            EditButton()
        }
    }

    private var relays: [Relay] {
        pool.relays.sorted()
    }

    private func remove(at offsets: IndexSet) {
        guard let index = offsets.first else {
            return
        }
        let relay = relays[index]
        pool.remove(relay: relay)
    }
    private func add(relay: Relay) {
        pool.remove(relay: relay)
    }
}
