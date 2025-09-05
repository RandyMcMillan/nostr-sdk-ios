//
//  QueryRelayDemoView.swift
//  NostrSDKDemo
//
//  Created by Joel Klabo on 6/15/23.
//

import SwiftUI
import NostrSDK
import Combine

struct _1632EventRowView: View {
    var event: NostrEvent

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Display the event content
            Text(event.content)
                .font(.body)
                .lineLimit(3) // Display up to 3 lines of content
                .padding(.bottom, 4)

            Divider()

            // Display other event details in a more compact format
            Group {
                Text("Kind: \(event.kind.rawValue)")
                Text("ID: \(event.id.prefix(8))...") // Shorten the ID for readability
                Text("Pubkey: \(event.pubkey.prefix(8))...") // Shorten the pubkey for readability
                Text("Created: \(event.createdDate.formatted(date: .abbreviated, time: .shortened))")
                Text("Tags: \(event.tags.count)")
            }
            .font(.caption)
            .foregroundColor(.secondary)
        }
        .padding(.vertical, 8)
    }
}

struct _1632EventDetailView: View {
    var event: NostrEvent

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("LINE:46")
                // Main Content
                Text(event.content)
                    .font(.body)
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(.systemGray6))
                    .cornerRadius(10)

                // Event Metadata
                VStack(alignment: .leading, spacing: 8) {
                    Text("ID: \(event.id)")
                    Text("Kind: \(event.kind.rawValue)")
                    Text("Pubkey: \(event.pubkey)")
                    Text("Created At: \(event.createdDate.formatted(date: .long, time: .complete))")
                    Text("Signature: \(event.signature ?? "N/A")")
                }
                .font(.caption)
                .foregroundColor(.secondary)

                // Tags Section
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

struct _1632EventListView: View {
    @State private var events: [NostrEvent] = [] // State property to hold your events

    var body: some View {
        NavigationView {
            List {
                ForEach(events, id: \.id) { event in
                    // Use your custom EventRowView for each item
                    // You can wrap this in a NavigationLink if tapping the row should show a detail view
                    NavigationLink(destination: _1632EventDetailView(event: event)) {
                        _1621EventRowView(event: event)
                    }
                }
            }
            .navigationTitle("Nostr Events")
            .onAppear {
                // This is a placeholder. In a real app, you would fetch
                // events from a Nostr relay here.
                loadMockEvents()
            }
        }
    }

    // A simple function to generate some mock data for the preview
    private func loadMockEvents() {
        let mockEvent1 = try? NostrEvent.Builder(kind: .textNote)
            .content("This is the first mock Nostr event. It's a test of the SwiftUI list view integration!")
            // .appendTags(contentsOf: .init(name: "p"/*, value: "abcdef123..."*/))
            .build(pubkey: "1234567890abcdef...")

        let mockEvent2 = try? NostrEvent.Builder(kind: .textNote)
            .content("A second event to demonstrate the list view with more data.")
            // .appendTags(contentsOf: .init(name: "e"/*, value: "fedcba987..."*/))
            .build(pubkey: "9876543210fedcba...")

        if let event1 = mockEvent1, let event2 = mockEvent2 {
            self.events = [event1, event2]
        }
    }
}

struct _1632QueryRelayDemoView: View {

    @EnvironmentObject var relayPool: RelayPool

    @State private var authorPubkey: String = ""
    @State private var events: [NostrEvent] = []
    @State private var eventsCancellable: AnyCancellable?
    @State private var errorString: String?
    @State private var subscriptionId: String?
// 30617 30618 1617 1621 1630 1631 1632 1633
    private let kindOptions = [
        // 0: "Set Metadata",
        // 1: "Text Note",
        // 3: "Follow List",
        // 6: "Repost",
        // 7: "Reaction",
        // 1984: "Report",
        // 10000: "Mute List",
        // 10003: "Bookmarks List",
        // 30023: "Longform Content",

        // nip-0034

        30617: "Repository announcements",
        30618: "Repository state announcements",
        1617: "Patches",
        1621: "Issues",
        1630: "Status (Open)",
        1631: "Status (Applied / Merged)",
        1632: "Status (Closed)",
        1633: "Status (Draft)"

    ]

    @State private var selectedKind = 1632

    var body: some View {

        Form {
            Section("LINE:199:NIP-0034 Viewer") {

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
                // Section("Results") {
                  //  if !authorPubkey.isEmpty {
                    //    Text("Note: send an event from this account and see it appear here.")
                      //      .foregroundColor(.gray)
                        //    .font(.footnote)
                    // }
                    //

                    // NavigationView {
                        // VStack {
                Section(">Results") {
                    List(events, id: \.id) { event in
                        // Section(">EVENT") {
                            //
                            if !event.content.isEmpty {
                                // Section(">>EVENT") {

                                    // Section(">>>EVENT") {

                                        // TODO meta author view
                                        ListOptionView(destinationView: AnyView(

                                            Section {
                                            // Text("event.pubkey \(event.pubkey)")
                                            VStack(alignment: .leading) {
                                                if event.tags.isEmpty {
                                                    Text("No tags found for this event.")
                                                        .foregroundColor(.secondary)
                                                } else {
                                                    TextField(text: $authorPubkey) {
                                                        // Text(">>Author Public Key (HEX)")
                                                        // }
                                                        Text(">>event.id \(event.id) \(event.tags.count)")
                                                    }
                                                        ForEach(event.tags, id: \.self) { tag in
                                                        VStack(alignment: .leading) {
                                                            Divider()
                                                            Text("Name: \(tag.name)")
                                                                .font(.subheadline)
                                                                .fontWeight(.bold)
                                                            Text("Value: \(tag.value)")
                                                                .font(.body)
                                                            if !tag.otherParameters.isEmpty {
                                                                ForEach(tag.otherParameters, id: \.self) { para in
                                                                    Divider()
                                                                    Text("\(para)")
                                                                        .bold()

                                                                }

                                                                // Text(">>Parameters: \(tag.otherParameters.joined(separator: ", "))")
                                                                    // .font(.subheadline)
                                                                    // .foregroundColor(.secondary)
                                                            }
                                                        }
                                                    }
                                                }
                                            }
                                            .padding()

                                            // Text("event.pubkey \(event.pubkey)")
                                            }

                                        ),
                                                       customImageName: "network",
                                                       labelText:

                                                        String("\(event.id) tags(\(event.tags.count))")).fontWeight(.bold)

                                    // }
                                    // Section(">>>>EVENT") {

                                        ListOptionView(destinationView: AnyView(Text("event.pubkey \(event.pubkey)")),
                                                       customImageName: "network",
                                                       labelText: String("\(event.pubkey)"))
                                    // }
                                    // Section(">>>>>EVENT") {
                                    //    ListOptionView(destinationView: AnyView(
                                    //        VStack {
                                    //            Divider()
                                    //            Section(String("TODO:221:\(event.tags)")) {
                                    //                Divider()
                                    //                VStack {
                                    //                    Divider()
                                    //                    Text("TODO:222:\(event.tags)")
                                    //                }
                                    //            }
                                    //        }
                                    //    ),
                                    //                   customImageName: "network",
                                    //                   labelText: String("TODO::226:\(event.tags)"))
                                    // }
                                    // Section(">>>>>>EVENT") {
                                    //    // Text("")
                                    //    //
                                    //    // ListOptionView(destinationView: AnyView(Text("event.kind //\(event.kind)")),
                                    //    //               customImageName: "network",
                                    //    //               labelText: "event.kind")
                                    //    // Text("")
//
                                    //
                                    //    VStack(alignment: .leading) {
                                    //        if event.tags.isEmpty {
                                    //            Text("No tags found for this event.")
                                    //                .foregroundColor(.secondary)
                                    //        } else {
                                    //            ForEach(event.tags, id: \.self) { tag in
                                    //                VStack(alignment: .leading) {
                                    //                    Divider()
                                    //                    Text("Name: \(tag.name)")
                                    //                        .font(.subheadline)
                                    //                        .fontWeight(.bold)
                                    //                    Text("Value: \(tag.value)")
                                    //                        .font(.body)
                                    //                    if !tag.otherParameters.isEmpty {
                                    //                        Text("Parameters: \(tag.otherParameters.joined(separator: ", "))")
                                    //                            .font(.footnote)
                                    //                            .foregroundColor(.secondary)
                                    //                    }
                                    //                }
                                    //            }
                                    //        }
                                    //    }
                                    //    .padding()
                                    //
                                    //    ListOptionView(
                                    //        destinationView: AnyView(
                                    //            VStack(alignment: .leading) {
                                    //                if event.tags.isEmpty {
                                    //                    Text("No tags found for this event.")
                                    //                        .foregroundColor(.secondary)
                                    //                } else {
                                    //                    ForEach(event.tags, id: \.self) { tag in
                                    //                        VStack(alignment: .leading) {
                                    //                            Divider()
                                    //                            Text("Name: \(tag.name)")
                                    //                                .font(.subheadline)
                                    //                                .fontWeight(.bold)
                                    //                            Text("Value: \(tag.value)")
                                    //                                .font(.body)
                                    //                            if !tag.otherParameters.isEmpty {
                                    //                                Text("Parameters: \(tag.otherParameters.joined(separator: ", "))")
                                    //                                    .font(.footnote)
                                    //                                    .foregroundColor(.secondary)
                                    //                            }
                                    //                        }
                                    //                    }
                                    //                }
                                    //            }
                                    //            .padding()
                                    //        ),
                                    //        customImageName: "network",
                                    //        labelText: "Tags (\(event.tags.count))"
                                    //    )
//
                                    // }
                                    // Section(">>>>>>>EVENT") {
                                        ListOptionView(destinationView: AnyView(Text("event.content \(event.content)")),
                                                       customImageName: "_network",
                                                       labelText: String("\(event.content)"))
                                        Text("=======")
                                    // }
                                // }
                            } else {
                                ListOptionView(destinationView: AnyView(Text("event.pubkey \(event.pubkey)")),
                                               customImageName: "network",
                                               labelText: String("\(event.content)"))
                                // Text("")
                                //
                                //    ListOptionView(destinationView: AnyView(Text("event.id //\(event.id)")),
                                //                   customImageName: "network",
                                //                   labelText: "event.id")
                                // Text("")
                                //
                                // ListOptionView(destinationView: AnyView(Text("event.kind //\(event.kind)")),
                                //               customImageName: "network",
                                //               labelText: "event.kind")
                                // Text("")
                                //
                                // ListOptionView(destinationView: AnyView(Text("event.tags //\(event.tags)")),
                                //               customImageName: "network",
                                //               labelText: "event.tags")
                                // Text("")

                                // ListOptionView(destinationView: AnyView(Text("event.kind //\(event.kind)")),
                                //               customImageName: "network",
                                //               labelText: "event.kind")
                                // Text("")
                                //// Text("\(event.content)")
                            }
                        // }
                    }
                }
               // }
            }
        }
        .navigationTitle("Kind 1621")
        .navigationBarTitleDisplayMode(.inline)
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
        }// end body
    }// end View

    private var currentFilter: Filter {
        let authors: [String]?
        if authorPubkey.isEmpty {
            authors = nil
        } else {
            authors = [authorPubkey]
        }
        return Filter(authors: authors, kinds: [selectedKind])!//
    }

    private func updateSubscription() {
        if let subscriptionId {
            relayPool.closeSubscription(with: subscriptionId)
        }

        subscriptionId = relayPool.subscribe(with: currentFilter)

        eventsCancellable = relayPool.events
            .receive(on: DispatchQueue.main)
            .map {
                $0.event
            }
            .removeDuplicates()
            .sink { event in
                events.insert(event, at: 0)
            }
    }
}

struct _1632QueryRelayView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            QueryRelayDemoView()
        }
    }
}
