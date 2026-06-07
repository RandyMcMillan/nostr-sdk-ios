//
//  ContentView.swift
//  NostrSDKDemo
//
//  Created by Joel Klabo on 6/10/23.
//

import SwiftUI
import GnostrSDK 

struct ContentView: View {

    @State private var relay: Relay?

    var body: some View {
        NavigationView {
            VStack {
                List {
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
                NavigationLink(destination: SettingsView()) {
                    Label("Settings", systemImage: "gearshape")
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                }
                .buttonStyle(.plain)
                .background(Color(.secondarySystemBackground))
                .overlay(
                    Rectangle()
                        .frame(height: 1)
                        .foregroundColor(Color(.separator).opacity(0.15)),
                    alignment: .top
                )
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

private struct SettingsView: View {
    @EnvironmentObject private var relayPool: RelayPool
    @StateObject private var metadataLoader = PubkeyMetadataLoader()

    @State private var privateKeyInput = DemoHelper.validHexPrivateKey.wrappedValue
    @State private var name = ""
    @State private var displayName = ""
    @State private var about = ""
    @State private var website = ""
    @State private var pictureURL = ""
    @State private var bannerURL = ""
    @State private var nostrAddress = ""
    @State private var isBot = false
    @State private var lud06 = ""
    @State private var lud16 = ""
    @State private var populatedPubkey: String?

    private var privateKey: PrivateKey? {
            let trimmed = privateKeyInput.trimmingCharacters(in: .whitespacesAndNewlines)
            return PrivateKey(nsec: trimmed) ?? PrivateKey(hex: trimmed)
    }

    private var publicKeyHex: String? {
            privateKey.flatMap { Keypair(privateKey: $0)?.publicKey.hex }
    }

    var body: some View {
            Form {
                Section("Profile") {
                    profileCard
                }

                Section("Key") {
                    labeledTextField("Private Key", text: $privateKeyInput, prompt: "nsec or hex")

                    if let publicKeyHex {
                        labeledValue("Public Key", value: publicKeyHex)
                    } else {
                        Text("Enter a valid private key to load profile metadata.")
                            .font(.caption)
                            .foregroundColor(.primary)
                    }
                }

                Section("User Metadata") {
                    labeledTextField("Name", text: $name, prompt: "name")
                    labeledTextField("Display Name", text: $displayName, prompt: "display name")
                    labeledTextEditor("About", text: $about, prompt: "about")
                    labeledTextField("Website", text: $website, prompt: "https://...")
                    labeledTextField("Picture URL", text: $pictureURL, prompt: "https://...")
                    labeledTextField("Banner URL", text: $bannerURL, prompt: "https://...")
                    labeledTextField("NIP-05", text: $nostrAddress, prompt: "name@example.com")
                    Toggle("Bot", isOn: $isBot)
                        .tint(.accentColor)
                        .foregroundColor(.primary)
                    labeledTextField("LUD-06", text: $lud06, prompt: "lnurl...")
                    labeledTextField("LUD-16", text: $lud16, prompt: "name@domain.com")
                }
            }
            .navigationTitle("Settings")
            .onAppear {
                metadataLoader.attach(relayPool: relayPool)
                refreshMetadata()
            }
            .onChange(of: privateKeyInput) { _ in
                populatedPubkey = nil
                refreshMetadata()
            }
            .onReceive(metadataLoader.$metadata) { metadata in
                guard let metadata, let publicKeyHex else { return }
                guard populatedPubkey != publicKeyHex else { return }
                populatedPubkey = publicKeyHex
                apply(metadata: metadata)
            }
    }

    private var profileCard: some View {
            VStack(alignment: .leading, spacing: 14) {
                PubkeyMetadataPreviewView(metadata: metadataLoader.metadata)

                VStack(alignment: .leading, spacing: 10) {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text("Public Key")
                            .font(.caption2.weight(.bold))
                            .foregroundColor(.primary)
                        Spacer(minLength: 0)
                        if let publicKeyHex {
                            Text(publicKeyHex)
                                .font(.caption.monospaced())
                                .foregroundColor(.primary)
                                .lineLimit(1)
                                .minimumScaleFactor(0.6)
                                .allowsTightening(true)
                        } else {
                            Text("Enter a valid private key")
                                .font(.caption)
                                .foregroundColor(.primary)
                        }
                    }

                    if let metadata = metadataLoader.metadata {
                        if let title = metadata.displayName ?? metadata.name ?? metadata.nostrAddress {
                            Text(title)
                                .font(.headline)
                                .foregroundColor(.primary)
                        }

                        if let nostrAddress = metadata.nostrAddress {
                            Text(nostrAddress)
                                .font(.caption)
                                .foregroundColor(.primary)
                        }

                        if let about = metadata.about, !about.isEmpty {
                            Text(about)
                                .font(.caption)
                                .foregroundColor(.primary)
                                .lineLimit(3)
                        }

                        if let website = metadata.websiteURL?.absoluteString {
                            Text(website)
                                .font(.caption.monospaced())
                                .foregroundColor(.primary)
                                .lineLimit(1)
                                .minimumScaleFactor(0.6)
                                .allowsTightening(true)
                        }
                    } else {
                        Text("Profile preview appears after a valid private key is entered.")
                            .font(.caption)
                            .foregroundColor(.primary)
                    }
                }
                .padding(14)
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
            .padding(.vertical, 4)
    }

    private func refreshMetadata() {
            guard let publicKeyHex else {
                metadataLoader.update(publicKeyInput: privateKeyInput, isValid: false)
                return
            }

            metadataLoader.update(publicKeyInput: publicKeyHex, isValid: true)
    }

    private func apply(metadata: MetadataEvent) {
            name = metadata.name ?? ""
            displayName = metadata.displayName ?? ""
            about = metadata.about ?? ""
            website = metadata.websiteURL?.absoluteString ?? ""
            pictureURL = metadata.pictureURL?.absoluteString ?? ""
            bannerURL = metadata.bannerPictureURL?.absoluteString ?? ""
            nostrAddress = metadata.nostrAddress ?? ""
            isBot = metadata.isBot ?? false
            lud06 = metadata.lightningURLString ?? ""
            lud16 = metadata.lightningAddress ?? ""
    }

    private func labeledTextField(_ label: String, text: Binding<String>, prompt: String) -> some View {
            VStack(alignment: .leading, spacing: 4) {
                Text(label)
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.primary)
                TextField(prompt, text: text)
                    .textFieldStyle(.roundedBorder)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            }
    }

    private func labeledTextEditor(_ label: String, text: Binding<String>, prompt: String) -> some View {
            VStack(alignment: .leading, spacing: 4) {
                Text(label)
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.primary)
                TextEditor(text: text)
                    .frame(minHeight: 88)
                    .padding(6)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(Color(.separator).opacity(0.15))
                    )
                    .overlay(
                        Group {
                            if text.wrappedValue.isEmpty {
                                Text(prompt)
                                    .foregroundColor(.primary)
                                    .padding(.leading, 12)
                                    .padding(.top, 14)
                            }
                        },
                        alignment: .topLeading
                    )
            }
    }

    private func labeledValue(_ label: String, value: String) -> some View {
            VStack(alignment: .leading, spacing: 4) {
                Text(label)
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.primary)
                Text(value)
                    .font(.caption.monospaced())
                    .foregroundColor(.primary)
                    .textSelection(.enabled)
            }
    }
}
