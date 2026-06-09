//
//  NostrSDKDemoApp.swift
//  NostrSDKDemo
//
//  Created by Honk on 6/10/23.
//

import GnostrSDK
import SwiftUI

@main
struct NostrSDKDemoApp: App {
    // swiftlint:disable:next force_try
    @StateObject var relayPool = try! RelayPool(relayURLs: [
        URL(string: "wss://nos.lol")!,
        URL(string: "wss://relay.snort.social")!,
        URL(string: "ws://127.0.0.1:8080")!
    ])
    @StateObject var identityStore = DemoIdentityStore()
    @StateObject var relayDirectory = RelayDirectoryStore()
    @StateObject var appPrimeStore = DemoAppPrimeStore()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(relayPool)
                .environmentObject(identityStore)
                .environmentObject(relayDirectory)
                .environmentObject(appPrimeStore)
        }
    }
}
