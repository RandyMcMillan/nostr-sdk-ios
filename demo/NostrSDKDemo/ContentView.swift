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

    var body: some View {
        NavigationView {
            VStack {
                List {

                    ListOptionView(destinationView: AnyView(_30618QueryRelayDemoView()),
                                   imageName: "list.bullet.rectangle.portrait",
                                   labelText: "NIP-0034 (30618)")
                    
                    ListOptionView(destinationView: AnyView(_30617QueryRelayDemoView()),
                                   imageName: "list.bullet.rectangle.portrait",
                                   labelText: "NIP-0034 (30617)")
                    
                    ListOptionView(destinationView: AnyView(_1633QueryRelayDemoView()),
                                   imageName: "list.bullet.rectangle.portrait",
                                   labelText: "NIP-0034 (1633)")

                    ListOptionView(destinationView: AnyView(_1632QueryRelayDemoView()),
                                   imageName: "list.bullet.rectangle.portrait",
                                   labelText: "NIP-0034 (1632)")

                    ListOptionView(destinationView: AnyView(_1631QueryRelayDemoView()),
                                   imageName: "list.bullet.rectangle.portrait",
                                   labelText: "NIP-0034 (1631)")

                    ListOptionView(destinationView: AnyView(_1630QueryRelayDemoView()),
                                   imageName: "list.bullet.rectangle.portrait",
                                   labelText: "NIP-0034 (1630)")

                    ListOptionView(destinationView: AnyView(_1621QueryRelayDemoView()),
                                   imageName: "list.bullet.rectangle.portrait",
                                   labelText: "NIP-0034 (1621)")

                    ListOptionView(destinationView: AnyView(_1617QueryRelayDemoView()),
                                   imageName: "list.bullet.rectangle.portrait",
                                   labelText: "NIP-0034 (1617)")

                    ListOptionView(destinationView: AnyView(_1632QueryRelayDemoView()),
                                   imageName: "list.bullet.rectangle.portrait",
                                   labelText: "NIP-0034 (1632)")

                    ListOptionView(destinationView: AnyView(ConnectRelayView(relay: $relay)),
                                   imageName: "network",
                                   labelText: "Connect Relay")
                    ListOptionView(destinationView: AnyView(RelaysView()),
                                   imageName: "network",
                                   labelText: "Configure Relays")
                    ListOptionView(destinationView: AnyView(QueryRelayDemoView()),
                                   imageName: "list.bullet.rectangle.portrait",
                                   labelText: "NIP-0034 Viewer")
                    ListOptionView(destinationView:
                                    AnyView(LegacyDirectMessageDemoView()),
                                   imageName: "list.bullet",
                                   labelText: "NIP-04 Direct Message")
                    ListOptionView(destinationView:
                                    AnyView(EncryptMessageDemoView()),
                                   imageName: "list.bullet",
                                   labelText: "NIP-44 Encrypt")
                    ListOptionView(destinationView:
                                    AnyView(DecryptMessageDemoView()),
                                   imageName: "list.bullet",
                                   labelText: "NIP-44 Decrypt")
                    ListOptionView(destinationView: AnyView(GenerateKeyDemoView()),
                                   imageName: "key",
                                   labelText: "Key Generation")
                    ListOptionView(destinationView: AnyView(NIP05VerficationDemoView()),
                                   imageName: "checkmark.seal",
                                   labelText: "NIP-05")
                }
            }
            .navigationTitle("NIP-0034 Viewer")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
