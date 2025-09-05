//
//  ContentView.swift
//  NostrSDKDemo
//
//  Created by Joel Klabo on 6/10/23.
//

import SwiftUI
import NostrSDK

struct ContentView: View {

    @State private var relay: Relay?
    @State private var showOptions = true
    
    var welcome: some View {
            // Your main app content
            Text("Welcome to the App")
                .sheet(isPresented: $showOptions) {
                    // The view you want to present as a sheet
                    //body
                }
        }
    
    var body: some View {
        welcome
        //Text("16:ListOptionView")

        NavigationView {
            //Text("19:ListOptionView")

            //VStack {
              //  Text("22:ListOptionView")
            //}
            VStack {
                Text("25:ListOptionView")
                VStack {
                    Text("27:ListOptionView")
                }
                List {

                    // ListOptionView(destinationView: AnyView(_30618QueryRelayDemoView()),
                    //               imageName: "list.bullet.rectangle.portrait",
                    //               labelText: "NIP-0034 (30618)")

                    // Assuming you have an image file named "network" in your Assets.xcassets
                    ListOptionView(destinationView: AnyView(_30618QueryRelayDemoView()),
                                   customImageName: "network",
                                   labelText: "NIP-0034 (30618)")

                    ListOptionView(destinationView: AnyView(_30617QueryRelayDemoView()),
                                   customImageName: "network",
                                   labelText: "NIP-0034 (30617)")

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

                    ListOptionView(destinationView: AnyView(QueryRelayDemoView()),
                                   customImageName: "network",
                                   labelText: "NIP-0034 Viewer")

                    ListOptionView(destinationView:
                                    AnyView(LegacyDirectMessageDemoView()),
                                   customImageName: "network",
                                   labelText: "NIP-04 Direct Message")

                    ListOptionView(destinationView:
                                    AnyView(EncryptMessageDemoView()),
                                   customImageName: "network",
                                   labelText: "NIP-44 Encrypt")

                    ListOptionView(destinationView:
                                    AnyView(DecryptMessageDemoView()),
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
            .navigationTitle("NIP-0034 Viewer")
            .navigationBarTitleDisplayMode(.inline)
        }
        Text("104:ListOptionView")

    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
