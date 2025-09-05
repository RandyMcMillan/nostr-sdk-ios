//
//  QueryRelayDemoView.swift
//  NostrSDKDemo
//
//  Created by Joel Klabo on 6/15/23.
//

import SwiftUI
import NostrSDK
import Combine

struct _30618EventRowView: View {
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

struct _30618EventDetailView: View {
    var event: NostrEvent
    var events: [NostrEvent] = []

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

struct _30618EventListView: View {
    @State private var events: [NostrEvent] = [] // State property to hold your events

    var body: some View {
        NavigationView {
            List {
                ForEach(events, id: \.id) { event in
                    // Use your custom EventRowView for each item
                    // You can wrap this in a NavigationLink if tapping the row should show a detail view
                    NavigationLink(destination: _30618EventDetailView(event: event)) {
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

//
struct _30618QueryRelayDemoView: View {

    @EnvironmentObject var relayPool: RelayPool

    @State private var authorPubkey: String = ""
    @State private var eventPubkeys: [String] = []
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

        // 30617: "Repository announcements",
        30618: "Repository state announcements"
        // 1617: "Patches",
        // 1621: "Issues",
        // 1630: "Status (Open)",
        // 1631: "Status (Applied / Merged)",
        // 1632: "Status (Closed)",
        // 1633: "Status (Draft)"

    ]

    @State private var selectedKind = 30618

    var body: some View {
        //Form
        Form {//begin Form
            Section("") {

            //    TextField(text: $authorPubkey) {
            //        Text("Author Public Key (HEX)")
            //    }
            //
            //    Picker("Kind", selection: $selectedKind) {
            //        ForEach(kindOptions.keys.sorted(), id: \.self) { number in
            //            if let name = kindOptions[number] {
            //                Text("\(name) (\(String(number)))")
            //            } else {
            //                Text("\(String(number))")
            //            }
            //        }
            //    }
        }//end Section
            Button/*begin Button*/ {
                updateSubscription()
                for event in events {
                    // Correct syntax to append to the array.
                    print("appending event.pubkey \(event.pubkey)")
                    eventPubkeys.append(event.pubkey)
                }
            }/*end Button*/ label:/*begin label*/ {
                Text("Update")
            }//end label:
            Section(">Results") {
                List(events, id: \.id) { event in
                    ListOptionView(destinationView: AnyView(
                        ScrollView {
                            VStack(alignment: .leading ) {
                                if event.tags.isEmpty {
                                    Text("No tags found for this event.")
                                        .foregroundColor(.secondary)
                                }/*end if events.tag.isEmpty*/ else {
                                    //VStack(/*alignment: .leading*/) {
                                        Text("PublicKey: \(event.pubkey)").bold()
                                            .textSelection(.enabled)
                                        Divider()
                                        Text("Event ID: \(event.id)").bold()
                                            .textSelection(.enabled)
                                        Divider()
                                        //Text("Tag Count: \(event.tags.count)").bold()
                                        //Divider()
                                    //}//end VStack
                                    ForEach(event.tags, id: \.self) { tag in
                                      //  VStack(/*alignment: .leading*/) {
                                            //Divider()
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
                                            }
                                        }
                                        //end VStack
                                    //}
                                    //end ForEach
                                }
                                //end else
                            }
                            //end VStack
                            .navigationTitle(Text("ID: \(event.id)"))
                            .navigationBarTitleDisplayMode(.inline)
                            .padding()
                            //Text("239:Public Key (HEX): \(event.pubkey)").bold().padding(.vertical)
                            //Text("239:Public Key (HEX): \(event.pubkey)").bold().padding()
                            //Text("239:Public Key (HEX): \(event.pubkey)").bold().padding(.vertical)
                            //Text("239:Public Key (HEX): \(event.pubkey)").bold().padding()
                            //Text("239:Public Key (HEX): \(event.pubkey)").bold().padding(.vertical)
                        }
                        //end Section
                        //Text("239:Public Key (HEX): \(event.pubkey)").bold().padding(.horizontal)

                    )
                    /*end AnyView*/,
                                   customImageName: "network",
                                   labelText: String("ID:\(event.id)\nPUBKEY:\(event.pubkey)\nTAGS(\(event.tags.count))")).fontWeight(.bold)
                    if !event.content.isEmpty {
                        ListOptionView(destinationView: AnyView(Text("event.content \(event.content)")),
                                       customImageName: "_network",
                                       labelText: String("\(event.content)"))
                        Text("=======")
                    }// end if !event.content.isEmpty
                }//end List(events, id...
            }//end Section
        }//end Form
        .navigationTitle("FORM:Kind 30618")
        .navigationBarTitleDisplayMode(.large)
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
        .onAppear {
            updateSubscription()
            // This code will run when the view appears on the screen.
            if let subscriptionId = self.subscriptionId {
                updateSubscription() // Assuming updateSubscription takes a parameter
                // Or if updateSubscription uses the property directly:
                updateSubscription()
            }
            for event in events {
                print(event.pubkey)
                if !eventPubkeys.contains(event.pubkey) {
                    eventPubkeys.append(event.pubkey)
                }
            }
        }//End Form.options
    }//end body

    private var currentFilter: Filter {
        let authors: [String]?
        if authorPubkey.isEmpty {
            authors = nil
        } else {
            authors = [authorPubkey]
        }
        return Filter(authors: authors, kinds: [selectedKind])!//
    }// end currentFilter

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
    }//end updateSubscription
}

struct _30618EventListView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            QueryRelayDemoView()
        }
    }
}
