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
    @StateObject var repositoryHostStore = DemoRepositoryHostStore()
    
    var body: some Scene {
        WindowGroup {
            AppBootstrapView()
                .environmentObject(relayPool)
                .environmentObject(identityStore)
                .environmentObject(relayDirectory)
                .environmentObject(appPrimeStore)
                .environmentObject(repositoryHostStore)
        }
    }
}

private struct AppBootstrapView: View {
    @EnvironmentObject private var relayPool: RelayPool
    @EnvironmentObject private var identityStore: DemoIdentityStore
    @EnvironmentObject private var appPrimeStore: DemoAppPrimeStore
    @EnvironmentObject private var repositoryHostStore: DemoRepositoryHostStore
    @State private var didBootstrap = false

    var body: some View {
        ContentView()
            .task {
                guard didBootstrap == false else { return }
                didBootstrap = true
                identityStore.attach(relayPool: relayPool)
                appPrimeStore.attach(relayPool: relayPool)
                repositoryHostStore.attach(appPrimeStore: appPrimeStore)
            }
    }
}
