//
//  Helpers.swift
//  NostrSDKDemo
//
//  Created by Joel Klabo on 8/12/23.
//

import SwiftUI
import NostrSDK

struct DemoHelper {
    static var emptyString: Binding<String> {
        Binding.constant("")
    }
    static var previewRelay: Binding<Relay?> {
        let urlString = "wss://relay.damus.io"

        guard let url = URL(string: urlString) else {
            fatalError("Invalid URL: \(urlString)")
        }
        // If the Relay initializer throws an error, replace 'try?' with your error handling.
        let relay = try? Relay(url: url)

        return Binding.constant(relay)
    }
    static var validNpub: Binding<String> {
        Binding.constant("npub15d9enu3v0yxyud4jk0pvxk3kmvrzymjpc6f0eq4ck44vr32qck7smrxq6k")
    }
    /// The Nostr SDK project and its maintainers take no responsibility of events signed with this private key which has been open sourced.
    /// Its purpose is for only testing and demos.
    static var validNsec: Binding<String> {
        Binding.constant("nsec1uwcvgs5clswpfxhm7nyfjmaeysn6us0yvjdexn9yjkv3k7zjhp2sv7rt36")
    }
    static var validHexPublicKey: Binding<String> {
        Binding.constant("a34b99f22c790c4e36b2b3c2c35a36db06226e41c692fc82b8b56ac1c540c5bd")
    }
    /// The Nostr SDK project and its maintainers take no responsibility of events signed with this private key which has been open sourced.
    /// Its purpose is for only testing and demos.
    static var validHexPrivateKey: Binding<String> {
        Binding.constant("e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855")
    }
    static var invalidKey: Binding<String> {
        Binding.constant("not-valid")
    }
}
