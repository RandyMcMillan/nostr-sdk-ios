//
//  QueryRelayDemoView.swift
//  NostrSDKDemo
//
//  Created by Joel Klabo on 6/15/23.
//

import SwiftUI
import GnostrSDK
import Combine

private struct EventCardView: View {
    let event: NostrEvent
    let metadata: MetadataEvent?
    @Environment(\.verticalSizeClass) private var verticalSizeClass

    private var title: String {
        metadata?.displayName ?? metadata?.name ?? metadata?.nostrAddress ?? event.pubkey
    }

    private var subtitle: String? {
        metadata?.nostrAddress ?? metadata?.name ?? metadata?.about
    }

    private var titleFont: Font {
        verticalSizeClass == .regular ? .system(size: 12, weight: .semibold, design: .default) : .headline
    }

    private var pubkeyFont: Font {
        verticalSizeClass == .regular ? .system(size: 7, weight: .regular, design: .monospaced) : .caption2.monospaced()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                avatar

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(titleFont)

                    if let subtitle {
                        Text(subtitle)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }

                    Text("Kind \(event.kind.rawValue, format: .number.grouping(.never))")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Text(event.createdDate.formatted(date: .abbreviated, time: .omitted) + " " + event.createdDate.formatted(date: .omitted, time: .shortened))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                Text("\(event.tags.count) tags")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Text(event.content.isEmpty ? "No content" : event.content)
                .font(.body)
                .lineLimit(4)

            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text("Pubkey:")
                Text(event.pubkey)
                    .layoutPriority(1)
            }
            .font(pubkeyFont)
            .foregroundColor(.secondary)
            .lineLimit(1)
            .minimumScaleFactor(0.1)
            //.allowsTightening(true)
            .fixedSize(horizontal: true, vertical: false)

            Text("ID: \(event.id)")
                .font(.caption.monospaced())
                .foregroundColor(.secondary)
                .lineLimit(1)
        }
        .padding(16)
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

    @ViewBuilder
    private var avatar: some View {
        if let pictureURL = metadata?.pictureURL {
            AsyncImage(url: pictureURL) { phase in
                switch phase {
                case .empty:
                    avatarPlaceholder
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFill()
                        .frame(width: 44, height: 44)
                        .clipShape(Circle())
                case .failure:
                    avatarPlaceholder
                @unknown default:
                    avatarPlaceholder
                }
            }
        } else {
            avatarPlaceholder
        }
    }

    private var avatarPlaceholder: some View {
        Circle()
            .fill(Color(.tertiarySystemFill))
            .frame(width: 44, height: 44)
            .overlay(
                Text(String(title.prefix(1)).uppercased())
                    .font(.caption)
                    .foregroundColor(.secondary)
            )
    }

    private func shortPubkey(_ pubkey: String) -> String {
        guard pubkey.count > 16 else { return pubkey }
        return "\(pubkey.prefix(8))...\(pubkey.suffix(8))"
    }
}

private struct EventDetailView: View {
    let event: NostrEvent
    let metadata: MetadataEvent?
    @Environment(\.verticalSizeClass) private var verticalSizeClass

    private var title: String {
        metadata?.displayName ?? metadata?.name ?? metadata?.nostrAddress ?? event.pubkey
    }

    private var pubkeyFont: Font {
        verticalSizeClass == .regular ? .system(size: 5, weight: .regular, design: .monospaced) : .caption2.monospaced()
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                banner

                HStack(alignment: .top, spacing: 12) {
                    detailAvatar

                    VStack(alignment: .leading, spacing: 4) {
                        Text(title)
                            .font(.headline)

                        if let nostrAddress = metadata?.nostrAddress {
                            Text(nostrAddress)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        if let about = metadata?.about, !about.isEmpty {
                            Text(about)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }

                Text(event.content.isEmpty ? "No content" : event.content)
                    .font(.body)
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(.systemGray6))
                    .cornerRadius(10)

                VStack(alignment: .leading, spacing: 8) {
                    Text("ID: \(event.id)")
                    Text("Kind: \(event.kind.rawValue)")
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text("Pubkey:")
                        Text(event.pubkey)
                            .layoutPriority(1)
                    }
                    .font(pubkeyFont)
                    .lineLimit(1)
                    .minimumScaleFactor(0.1)
                    //.allowsTightening(true)
                    .fixedSize(horizontal: true, vertical: false)
                    Text("Created At: \(event.createdDate.formatted(date: .long, time: .complete))")
                    Text("Signature: \(event.signature ?? "N/A")")
                }
                .font(.caption)
                .foregroundColor(.secondary)

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

    @ViewBuilder
    private var banner: some View {
        if let bannerURL = metadata?.bannerPictureURL {
            AsyncImage(url: bannerURL) { phase in
                switch phase {
                case .empty:
                    bannerPlaceholder
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFill()
                        .frame(maxWidth: .infinity)
                        .frame(height: 140)
                        .clipped()
                        .cornerRadius(16)
                case .failure:
                    bannerPlaceholder
                @unknown default:
                    bannerPlaceholder
                }
            }
        }
    }

    private var bannerPlaceholder: some View {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
            .fill(Color(.tertiarySystemFill))
            .frame(height: 140)
    }

    @ViewBuilder
    private var detailAvatar: some View {
        if let pictureURL = metadata?.pictureURL {
            AsyncImage(url: pictureURL) { phase in
                switch phase {
                case .empty:
                    detailAvatarPlaceholder
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFill()
                        .frame(width: 72, height: 72)
                        .clipShape(Circle())
                case .failure:
                    detailAvatarPlaceholder
                @unknown default:
                    detailAvatarPlaceholder
                }
            }
        } else {
            detailAvatarPlaceholder
        }
    }

    private var detailAvatarPlaceholder: some View {
        Circle()
            .fill(Color(.tertiarySystemFill))
            .frame(width: 72, height: 72)
            .overlay(
                Text(String(title.prefix(1)).uppercased())
                    .font(.title3)
                    .foregroundColor(.secondary)
            )
    }
}

struct QueryRelayDemoView: View {

    @EnvironmentObject var relayPool: RelayPool

    @State private var authorPubkey: String = DemoHelper.validHexPublicKey.wrappedValue
    @State private var events: [NostrEvent] = []
    @State private var metadataByPubkey: [String: MetadataEvent] = [:]
    @State private var eventsCancellable: AnyCancellable?
    @State private var errorString: String?
    @State private var subscriptionId: String?
    @State private var metadataSubscriptionId: String?
    @State private var trackedMetadataPubkeys: Set<String> = []

    private let kindOptions = [
        30617: "Repository announcements",
        30618: "Repository state announcements",
        1617: "Patches",
        1621: "Issues",
        1630: "Status (Open)",
        1631: "Status (Applied / Merged)",
        1632: "Status (Closed)",
        1633: "Status (Draft)"
    ]

    @State private var selectedKind = 30617

    var body: some View {
        Form {
            Section("NIP-0034 Viewer") {
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
                Section("Results") {
                    if !authorPubkey.isEmpty {
                        Text("Showing events for \(authorPubkey)")
                            .font(.footnote)
                            .foregroundColor(.secondary)
                    }

                    ForEach(events, id: \.id) { event in
                        NavigationLink(destination: EventDetailView(event: event, metadata: metadataByPubkey[event.pubkey])) {
                            EventCardView(event: event, metadata: metadataByPubkey[event.pubkey])
                        }
                        .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                    }
                }
            }
        }
        .onAppear {
            updateSubscription()
            updateMetadataSubscription()
        }
        .onChange(of: authorPubkey) { _ in
            events = []
            updateSubscription()
            updateMetadataSubscription()
        }
        .onChange(of: selectedKind) { _ in
            events = []
            updateSubscription()
            updateMetadataSubscription()
        }
        .onDisappear {
            if let subscriptionId {
                relayPool.closeSubscription(with: subscriptionId)
            }
            if let metadataSubscriptionId {
                relayPool.closeSubscription(with: metadataSubscriptionId)
            }
        }
    }

    private var currentFilter: Filter {
        let authors: [String]?
        if authorPubkey.isEmpty {
            authors = nil
        } else {
            authors = [authorPubkey]
        }
        return Filter(authors: authors, kinds: [selectedKind])!
    }

    private func updateSubscription() {
        if let subscriptionId {
            relayPool.closeSubscription(with: subscriptionId)
        }

        subscriptionId = relayPool.subscribe(with: currentFilter)

        eventsCancellable = relayPool.events
            .receive(on: DispatchQueue.main)
            .map { $0.event }
            .removeDuplicates()
            .sink { event in
                if let metadataEvent = event as? MetadataEvent {
                    if metadataByPubkey[metadataEvent.pubkey]?.createdAt ?? 0 <= metadataEvent.createdAt {
                        metadataByPubkey[metadataEvent.pubkey] = metadataEvent
                    }
                    return
                }

                events.insert(event, at: 0)
                updateMetadataSubscription()
            }
    }

    private func updateMetadataSubscription() {
        var pubkeys = Set(events.map(\.pubkey))
        if authorPubkey.isEmpty == false {
            pubkeys.insert(authorPubkey)
        }

        guard pubkeys != trackedMetadataPubkeys else {
            return
        }

        trackedMetadataPubkeys = pubkeys

        if let metadataSubscriptionId {
            relayPool.closeSubscription(with: metadataSubscriptionId)
        }

        guard pubkeys.isEmpty == false, let filter = Filter(authors: Array(pubkeys), kinds: [EventKind.metadata.rawValue]) else {
            metadataSubscriptionId = nil
            return
        }

        metadataSubscriptionId = relayPool.subscribe(with: filter)
    }
}

struct QueryRelayView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            QueryRelayDemoView()
        }
    }
}
