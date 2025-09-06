//
//  ContentView.swift
//  NostrSDKDemo
//
//  Created by Joel Klabo on 6/10/23.
//

import SwiftUI
import NostrSDK
import Combine

struct _30617InitialDetailView: View {
    
    @EnvironmentObject var relayPool: RelayPool

    @State private var authorPubkey: String = ""
    @State private var eventPubkeys: [String] = []
    @State private var events: [NostrEvent] = []
    @State private var eventsCancellable: AnyCancellable?
    @State private var errorString: String?
    @State private var subscriptionId: String?
    
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
        VStack {
            Image("network")
                .font(.system(size: 80))
                .foregroundColor(.accentColor)
                .padding()

            Text("gnostr")
                .font(.largeTitle)
                .padding(.bottom, 5)

            Text("gnostr")
                .font(.body)
                .foregroundColor(.secondary)
        }
        .padding()
        .navigationTitle("Details")
    }
}

struct _30617InitialDetailView_Previews: PreviewProvider {
    static var previews: some View {
        InitialDetailView()
    }
}

struct _30617ContentView: View {
    @State private var relay: Relay?
    @State private var showWelcomeOptions = false

    @State private var relayURLString = "wss://relay.damus.io"
    @State private var relayError: String?
    @State private var state: Relay.State = .notConnected
    @State private var stateCancellable: AnyCancellable?

    // Using NavigationStack and NavigationSplitView is the modern approach
    // and is supported on iOS 16+.
    var body: some View {
        NavigationSplitView {
            List {
                Group {
                    ListOptionView(destinationView: AnyView(InitialDetailView()),
                                   customImageName: "network",
                                   labelText: "NIP-0034 (30617)")
                    ListOptionView(destinationView: AnyView(_30618QueryRelayDemoView()),
                                   customImageName: "network",
                                   labelText: "NIP-0034 (30618)")
                    ListOptionView(destinationView: AnyView(_1633QueryRelayDemoView()),
                                   customImageName: "network",
                                   labelText: "NIP-0034 (1633)")
                    ListOptionView(destinationView: AnyView(_1632QueryRelayDemoView()),
                                   customImageName: "network",
                                   labelText: "NIP-0034 (1632)")
                    ListOptionView(destinationView: AnyView(_1631QueryRelayDemoView()),
                                   customImageName: "network",
                                   labelText: "NIP-0034 (1631)")
                    ListOptionView(destinationView: AnyView(_1630QueryRelayDemoView()),
                                   customImageName: "network",
                                   labelText: "NIP-0034 (1630)")
                    ListOptionView(destinationView: AnyView(_1621QueryRelayDemoView()),
                                   customImageName: "network",
                                   labelText: "NIP-0034 (1621)")
                    ListOptionView(destinationView: AnyView(_1617QueryRelayDemoView()),
                                   customImageName: "network",
                                   labelText: "NIP-0034 (1617)")
                    ListOptionView(destinationView: AnyView(_1632QueryRelayDemoView()),
                                   customImageName: "network",
                                   labelText: "NIP-0034 (1632)")
                    ListOptionView(destinationView: AnyView(ConnectRelayView(relay: $relay)),
                                   customImageName: "network",
                                   labelText: "Connect Relay")
                    ListOptionView(destinationView: AnyView(RelaysView()),
                                   customImageName: "network",
                                   labelText: "Configure Relays")
                }
                Group {
                    ListOptionView(destinationView: AnyView(LegacyDirectMessageDemoView()),
                                   customImageName: "network",
                                   labelText: "NIP-04 Direct Message")
                    ListOptionView(destinationView: AnyView(EncryptMessageDemoView()),
                                   customImageName: "network",
                                   labelText: "NIP-44 Encrypt")
                    ListOptionView(destinationView: AnyView(DecryptMessageDemoView()),
                                   customImageName: "network",
                                   labelText: "NIP-44 Decrypt")
                    ListOptionView(destinationView: AnyView(GenerateKeyDemoView()),
                                   customImageName: "key",
                                   labelText: "Key Generation")
                    ListOptionView(destinationView: AnyView(NIP05VerficationDemoView()),
                                   customImageName: "checkmark.seal",
                                   labelText: "NIP-05")
                }
            }
            .navigationTitle("NostrSDK Demo")
        } detail: {
            InitialDetailView()
        }
    }
}

struct _30617ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}

