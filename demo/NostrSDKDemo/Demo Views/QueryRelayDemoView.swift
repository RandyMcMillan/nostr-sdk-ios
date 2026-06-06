//
//  QueryRelayDemoView.swift
//  NostrSDKDemo
//
//  Created by Joel Klabo on 6/15/23.
//

import SwiftUI
import NostrSDK
import Combine

struct EventRowView: View {
    var event: NostrEvent

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Kind \(event.kind.rawValue)")
                        .font(.headline)
                    Text(event.createdDate.formatted(date: .abbreviated, time: .shortened))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                Text("\(event.tags.count) tags")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Text(event.content.isEmpty ? "No content" : event.content)
                .font(.body)
                .lineLimit(4)

            VStack(alignment: .leading, spacing: 4) {
                Text("Pubkey")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(event.pubkey)
                    .font(.caption.monospaced())
                    .foregroundColor(.secondary)
                    .lineLimit(1)

                Text("ID")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(event.id)
                    .font(.caption.monospaced())
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(.secondarySystemBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color(.separator).opacity(0.15))
        )
    }
}

struct EventDetailView: View {
    var event: NostrEvent

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text(event.content)
                    .font(.body)
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(.systemGray6))
                    .cornerRadius(10)

                VStack(alignment: .leading, spacing: 8) {
                    Text("ID: \(event.id)")
                    Text("Kind: \(event.kind.rawValue)")
                    Text("Pubkey: \(event.pubkey)")
                    Text("Created At: \(event.createdDate.formatted(date: .long, time: .complete))")
                    Text("Signature: \(event.signature ?? "N/A")")
                }
                .font(.caption)
                .foregroundColor(.secondary)

                if !event.tags.isEmpty {
                    VStack(alignment: .leading) {
                        Text("Tags:")
                            .font(.headline)

                        ForEach(event.tags, id: \.self) { tag in
                            Text("• \(tag.name): \(tag.value)")
                                .font(.caption)
                        }
                    }
                }
            }
            .padding()
        }
        .navigationTitle("Event Details")
    }
}

struct EventListView: View {
    @State private var events: [NostrEvent] = []

    var body: some View {
        NavigationView {
            List {
                ForEach(events, id: \.id) { event in
                    NavigationLink(destination: EventDetailView(event: event)) {
                        EventRowView(event: event)
                    }
                }
            }
            .navigationTitle("Nostr Events")
            .onAppear {
                loadMockEvents()
            }
        }
    }

    private func loadMockEvents() {
        let mockEvent1 = try? NostrEvent.Builder(kind: .textNote)
            .content("This is the first mock Nostr event. It's a test of the SwiftUI list view integration!")
            .build(pubkey: "1234567890abcdef...")

        let mockEvent2 = try? NostrEvent.Builder(kind: .textNote)
            .content("A second event to demonstrate the list view with more data.")
            .build(pubkey: "9876543210fedcba...")

        if let event1 = mockEvent1, let event2 = mockEvent2 {
            self.events = [event1, event2]
        }
    }
}

struct QueryRelayDemoView: View {

    @EnvironmentObject var relayPool: RelayPool

    @State private var authorPubkey: String = DemoHelper.validHexPublicKey.wrappedValue
    @State private var events: [NostrEvent] = []
    @State private var eventsCancellable: AnyCancellable?
    @State private var errorString: String?
    @State private var subscriptionId: String?
    // 30617 30618 1617 1621 1630 1631 1632 1633
    private let kindOptions = [
        30617: "Repository announcements",
        30618: "Repository state announcements",
        1617: "Patches",
        1621: "Issues",
        1630: "Status (Open)",
        1631: "Status (Applied / Merged)",
        1632: "Status (Closed)",
        1633: "Status (Draft)"
    ]

    @State private var selectedKind = 30617

    var body: some View {
        Form {
            Section("NIP-0034 Viewer") {
                TextField(text: $authorPubkey) {
                    Text("Author Public Key (HEX)")
                }

                Picker("Kind", selection: $selectedKind) {
                    ForEach(kindOptions.keys.sorted(), id: \.self) { number in
                        if let name = kindOptions[number] {
                            Text("\(name) (\(String(number)))")
                        } else {
                            Text("\(String(number))")
                        }
                    }
                }
            }

            Button {
                updateSubscription()
            } label: {
                Text("Query")
            }

            if !events.isEmpty {
                Section("Results") {
                    if !authorPubkey.isEmpty {
                        Text("Showing events for \(authorPubkey)")
                            .font(.footnote)
                            .foregroundColor(.secondary)
                    }

                    ForEach(events, id: \.id) { event in
                        EventRowView(event: event)
                            .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                    }
                }
            }
        }
        .onChange(of: authorPubkey) { _ in
            events = []
            updateSubscription()
        }
        .onChange(of: selectedKind) { _ in
            events = []
            updateSubscription()
        }
        .onDisappear {
            if let subscriptionId {
                relayPool.closeSubscription(with: subscriptionId)
            }
        }
    }

    private var currentFilter: Filter {
        let authors: [String]?
        if authorPubkey.isEmpty {
            authors = nil
        } else {
            authors = [authorPubkey]
        }
        return Filter(authors: authors, kinds: [selectedKind])!
    }

    private func updateSubscription() {
        if let subscriptionId {
            relayPool.closeSubscription(with: subscriptionId)
        }

        subscriptionId = relayPool.subscribe(with: currentFilter)

        eventsCancellable = relayPool.events
            .receive(on: DispatchQueue.main)
            .map { $0.event }
            .removeDuplicates()
            .sink { event in
                events.insert(event, at: 0)
            }
    }
}

struct QueryRelayView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            QueryRelayDemoView()
        }
    }
}
