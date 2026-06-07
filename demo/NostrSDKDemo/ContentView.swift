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
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @StateObject private var metadataLoader = PubkeyMetadataLoader()

    @State private var privateKeyInput = DemoHelper.validHexPrivateKey.wrappedValue
    @State private var name = "name"
    @State private var displayName = "displayName"
    @State private var about = "about"
    @State private var website = "website"
    @State private var pictureURL = "pictureURL"
    @State private var bannerURL = "bannerURL"
    @State private var nostrAddress = "nostrAddress"
    @State private var isBot = false
    @State private var lud06 = "lud06"
    @State private var lud16 = "lud16"
    @State private var populatedPubkey: String?

    private var privateKey: PrivateKey? {
            let trimmed = privateKeyInput.trimmingCharacters(in: .whitespacesAndNewlines)
            return PrivateKey(nsec: trimmed) ?? PrivateKey(hex: trimmed)
    }

    private var publicKeyHex: String? {
            privateKey.flatMap { Keypair(privateKey: $0)?.publicKey.hex }
    }

    private var titleLineLimit: Int {
        horizontalSizeClass == .compact ? 1 : 2
    }

    var body: some View {
            Form {
                //Section("SettingsView:108:") { //Profile leave blank
                    //Spacer(minLength: 0)
                    //profileCard
                    //profileCard.frame(minHeight: 320)//how to make height greater?

                  //  Spacer(minLength: 0)
                //}

                Section("SettingsView:112:") { //Key leave blank
                    labeledTextField("SettingsView:113:Private Key", text: $privateKeyInput, prompt: "nsec or hex")

                    if let publicKeyHex {
                        labeledValue("SettingsView:116:Public Key", value: publicKeyHex)
                    } else {
                        Text("Enter a valid private key to load profile metadata.")
                            .font(.caption)
                            .foregroundColor(.primary)
                    }
                }
                profileCard.frame(minHeight: 320)//how to make height greater?

                Section("SettingsView:124:User Metadata") {
                    SettingsMetadataEditorView(name: $name,
                                               displayName: $displayName,
                                               about: $about,
                                               website: $website,
                                               pictureURL: $pictureURL,
                                               bannerURL: $bannerURL,
                                               nostrAddress: $nostrAddress,
                                               isBot: $isBot,
                                               lud06: $lud06,
                                               lud16: $lud16)
                }
            }
            //.navigationTitle("SettingsView:137") //leave blank
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
            VStack(alignment: .leading, spacing: 0) {
                //Spacer(minLength: 0)
                PubkeyMetadataPreviewView(metadata: metadataLoader.metadata) //includes banner view
                //Spacer(minLength: 0)
                //SettingsProfileSummaryView(metadata: metadataLoader.metadata,
                //                          publicKeyHex: publicKeyHex,
                //                          titleLineLimit: titleLineLimit)
                //.padding(0)
                //.frame(maxWidth: .infinity, alignment: .leading)
                //.background(
                //    RoundedRectangle(cornerRadius: 16, style: .continuous)
                //        .fill(Color(.secondarySystemBackground))
                //)
                //.overlay(
                //    RoundedRectangle(cornerRadius: 16, style: .continuous)
                //        .stroke(Color(.separator).opacity(0.15))
                //)
            }
            //.padding(.vertical, 4)
    }

    private func refreshMetadata() {
            guard let publicKeyHex else {
                metadataLoader.update(publicKeyInput: privateKeyInput, isValid: false)
                return
            }

            metadataLoader.update(publicKeyInput: publicKeyHex, isValid: true)
    }

    private func apply(metadata: MetadataEvent) {
            name = metadata.name ?? "metadata.name"
            displayName = metadata.displayName ?? "metadata.displayName"
            about = metadata.about ?? "metadata.about"
            website = metadata.websiteURL?.absoluteString ?? "metadata.websiteURL?.absoluteString"
            pictureURL = metadata.pictureURL?.absoluteString ?? "metadata.pictureURL?.absoluteString"
            bannerURL = metadata.bannerPictureURL?.absoluteString ?? "metadata.bannerPictureURL?.absoluteString"
            nostrAddress = metadata.nostrAddress ?? "metadata.nostrAddress"
            isBot = metadata.isBot ?? false
            lud06 = metadata.lightningURLString ?? "metadata.lightningURLString"
            lud16 = metadata.lightningAddress ?? "metadata.lightningAddress"
    }

    private func labeledTextField(_ label: String, text: Binding<String>, prompt: String) -> some View {
            VStack(alignment: .leading, spacing: 4) {
                Text(label)
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.primary)
                if label.contains("Private Key") {
                    SecureField(prompt, text: text)
                        .textFieldStyle(.roundedBorder)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                } else {
                    TextField(prompt, text: text)
                        .textFieldStyle(.roundedBorder)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }
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

private struct SettingsMetadataEditorView: View {
    @Binding var name: String
    @Binding var displayName: String
    @Binding var about: String
    @Binding var website: String
    @Binding var pictureURL: String
    @Binding var bannerURL: String
    @Binding var nostrAddress: String
    @Binding var isBot: Bool
    @Binding var lud06: String
    @Binding var lud16: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ResponsiveTextFieldRow(label: "Name", text: $name, prompt: "name")
            ResponsiveTextFieldRow(label: "Display Name", text: $displayName, prompt: "display name")
            ResponsiveTextEditorRow(label: "About", text: $about, prompt: "about")
            ResponsiveTextFieldRow(label: "Website", text: $website, prompt: "https://...")
            ResponsiveTextFieldRow(label: "Picture URL", text: $pictureURL, prompt: "https://...")
            ResponsiveTextFieldRow(label: "Banner URL", text: $bannerURL, prompt: "https://...")
            ResponsiveTextFieldRow(label: "NIP-05", text: $nostrAddress, prompt: "name@example.com")
            ResponsiveToggleRow(label: "Bot", isOn: $isBot)
            ResponsiveTextFieldRow(label: "LUD-06", text: $lud06, prompt: "lnurl...")
            ResponsiveTextFieldRow(label: "LUD-16", text: $lud16, prompt: "name@domain.com")
        }
    }
}

private struct ResponsiveTextFieldRow: View {
    let label: String
    @Binding var text: String
    let prompt: String

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                    Text(label)
                        .font(.caption.weight(.semibold))
                        .foregroundColor(.primary)
                        .frame(width: 120, alignment: .leading)
                    TextField(prompt, text: $text)
                        .textFieldStyle(.roundedBorder)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
            }

            VStack(alignment: .leading, spacing: 4) {
                    Text(label)
                        .font(.caption.weight(.semibold))
                        .foregroundColor(.primary)
                    TextField(prompt, text: $text)
                        .textFieldStyle(.roundedBorder)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
            }
        }
    }
}

private struct ResponsiveTextEditorRow: View {
    let label: String
    @Binding var text: String
    let prompt: String

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .top, spacing: 12) {
                    Text(label)
                        .font(.caption.weight(.semibold))
                        .foregroundColor(.primary)
                        .frame(width: 120, alignment: .leading)
                    editor
            }

            VStack(alignment: .leading, spacing: 4) {
                    Text(label)
                        .font(.caption.weight(.semibold))
                        .foregroundColor(.primary)
                    editor
            }
        }
    }

    private var editor: some View {
        TextEditor(text: $text)
            .frame(minHeight: 88)
            .padding(6)
            .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(Color(.separator).opacity(0.15))
            )
            .overlay(
                    Group {
                        if text.isEmpty {
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

private struct ResponsiveToggleRow: View {
    let label: String
    @Binding var isOn: Bool

    var body: some View {
        HStack {
            Text(label)
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.primary)
            Spacer(minLength: 0)
            Toggle("", isOn: $isOn)
                    .labelsHidden()
                    .tint(.accentColor)
        }
    }
}

private struct SettingsProfileSummaryView: View {
    let metadata: MetadataEvent?
    let publicKeyHex: String?
    let titleLineLimit: Int

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    private var aboutLineLimit: Int {
        horizontalSizeClass == .compact ? 2 : 3
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Spacer(minLength: 0)
            //HStack(alignment: .firstTextBaseline, spacing: 8) {
            //        Text("383:Public Key")
            //            .font(.caption2.weight(.bold))
            //            .foregroundColor(.primary)
            //        Spacer(minLength: 0)
            //        if let publicKeyHex {
            //            Text(publicKeyHex)
            //                .font(.caption.monospaced())
            //                .foregroundColor(.primary)
            //                .lineLimit(1)
            //                .minimumScaleFactor(0.6)
            //                .allowsTightening(true)
            //        } else {
            //            Text("Enter a valid private key")
            //                .font(.caption)
            //                .foregroundColor(.primary)
            //        }
            //}

            if let metadata {
                    if let title = metadata.displayName ?? metadata.name ?? metadata.nostrAddress {
                        Text(title)
                            .font(.headline)
                            .foregroundColor(.primary)
                            .lineLimit(titleLineLimit)
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
                            .lineLimit(aboutLineLimit)
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
    }
}
