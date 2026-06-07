//
//  QueryRelayDemoView.swift
//  NostrSDKDemo
//
//  Created by Joel Klabo on 6/15/23.
//

import SwiftUI
import NostrSDK
import Combine
import UIKit

private struct TinyWebImageView: UIViewRepresentable {
    let url: URL

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> UIImageView {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        imageView.backgroundColor = .clear
        context.coordinator.load(url: url, into: imageView)
        return imageView
    }

    func updateUIView(_ uiView: UIImageView, context: Context) {
        context.coordinator.load(url: url, into: uiView)
    }

    final class Coordinator {
        private var task: Task<Void, Never>?
        private var currentURL: URL?

        func load(url: URL, into imageView: UIImageView) {
            currentURL = url
            print("[QueryRelayDemo] image load attempt url=\(url.absoluteString)")

            if let cachedImage = RemoteImageLoader.cache.object(forKey: url as NSURL) {
                print("[QueryRelayDemo] image load cache hit url=\(url.absoluteString)")
                imageView.image = cachedImage
                return
            }

            task?.cancel()
            task = Task.detached(priority: .background) { [weak imageView] in
                do {
                    let (data, _) = try await URLSession.shared.data(from: url)
                    guard let loadedImage = UIImage(data: data) else {
                        print("[QueryRelayDemo] image decode failed url=\(url.absoluteString)")
                        return
                    }

                    RemoteImageLoader.cache.setObject(loadedImage, forKey: url as NSURL)

                    await MainActor.run {
                        guard let imageView, self.currentURL == url else { return }
                        imageView.image = loadedImage
                    }
                } catch is CancellationError {
                } catch {
                    print("[QueryRelayDemo] image load failed url=\(url.absoluteString) error=\(error)")
                }
            }
        }
    }
}

private final class RemoteImageLoader {
    static let cache = NSCache<NSURL, UIImage>()
}

private final class RemoteImagePrefetcher {
    static let shared = RemoteImagePrefetcher()

    func prefetch(url: URL?) {
        guard let url else { return }
        guard RemoteImageLoader.cache.object(forKey: url as NSURL) == nil else { return }

        Task.detached(priority: .background) {
            print("[QueryRelayDemo] image prefetch attempt url=\(url.absoluteString)")
            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                guard let loadedImage = UIImage(data: data) else {
                    print("[QueryRelayDemo] image decode failed url=\(url.absoluteString)")
                    return
                }

                RemoteImageLoader.cache.setObject(loadedImage, forKey: url as NSURL)
            } catch {
                print("[QueryRelayDemo] image prefetch failed url=\(url.absoluteString) error=\(error)")
            }
        }
    }
}

private struct EventCardView: View {
    let event: NostrEvent
    let metadata: MetadataEvent?
    @Environment(\.verticalSizeClass) private var verticalSizeClass

    private struct TagItem: Hashable {
        let label: String
        let value: String
    }

    private var title: String? {
        tagValue("name") ?? tagValue("description") ?? tagValue("alt")
    }

    private var subtitle: String? {
        tagValue("description") ?? tagValue("alt")
    }

    private var repoID: String? {
        tagValue("d")
    }

    private var cloneURL: String? {
        tagValue("clone")
    }

    private var webURL: String? {
        tagValue("web")
    }

    private var relaysText: String? {
        values(for: "relays").first
    }

    private var maintainersText: String? {
        values(for: "maintainers").first
    }

    private var cardTags: [TagItem] {
        [
            tagItem(label: "Repo", value: repoID),
            tagItem(label: "Clone", value: shortDisplayValue(cloneURL)),
            tagItem(label: "Web", value: shortDisplayValue(webURL))
        ]
        .compactMap { $0 }
    }

    private var titleFont: Font {
        verticalSizeClass == .regular ? .system(size: 12, weight: .semibold, design: .default) : .headline
    }

    private var pubkeyFont: Font {
        verticalSizeClass == .regular ? .system(size: 7, weight: .regular, design: .monospaced) : .caption2.monospaced()
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            avatar
                .frame(width: 72)
                .frame(maxHeight: .infinity, alignment: .top)

            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text("ID: \(event.id)")
                        .font(.system(size: 13, weight: .semibold, design: .monospaced))
                        .foregroundColor(.primary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                        .allowsTightening(true)
                        .layoutPriority(1)
                }

                if let title {
                    Text(title)
                        .font(titleFont)
                }

                if let subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.primary)
                        .lineLimit(2)
                }

                if let repoID {
                    Text(repoID)
                        .font(.caption.monospaced())
                        .foregroundColor(.primary)
                        .lineLimit(1)
                }

                HStack(spacing: 8) {
                    Text("Kind \(event.kind.rawValue, format: .number.grouping(.never))")
                    Text("•")
                    Text(event.createdDate.formatted(date: .abbreviated, time: .shortened))
                }
                .font(.caption)
                .foregroundColor(.primary)

                if !event.content.isEmpty {
                    Text(event.content)
                        .font(.body)
                        .lineLimit(4)
                }

                if let cloneURL {
                    Text(cloneURL)
                        .font(.caption)
                        .foregroundColor(.primary)
                        .lineLimit(1)
                }

                if cardTags.isEmpty == false {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(cardTags, id: \.self) { item in
                            TagChipView(label: item.label, value: item.value)
                        }
                    }
                }
            }

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
    private var profileImage: some View {
        if let pictureURL = metadata?.pictureURL {
            TinyWebImageView(url: pictureURL)
                .frame(maxWidth: .infinity)
                .frame(height: 180)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
    }

    @ViewBuilder
    private var avatar: some View {
        if let pictureURL = metadata?.pictureURL {
            TinyWebImageView(url: pictureURL)
                .frame(width: 72, height: 72)
                .clipShape(Circle())
                .overlay(Circle().stroke(Color(.separator).opacity(0.2), lineWidth: 1))
        } else {
            avatarPlaceholder
        }
    }

    private var avatarPlaceholder: some View {
        ZStack {
            Circle()
                .fill(Color(.tertiarySystemFill))
            Image("GnostrIcon")
                .resizable()
                .scaledToFit()
                .padding(12)
        }
        .frame(width: 72, height: 72)
    }

    private func shortPubkey(_ pubkey: String) -> String {
        guard pubkey.count > 16 else { return pubkey }
        return "\(pubkey.prefix(8))...\(pubkey.suffix(8))"
    }

    private func tagValue(_ name: String) -> String? {
        event.tags.first(where: { $0.name == name })?.value
    }

    private func values(for name: String) -> [String] {
        event.tags.filter { $0.name == name }.map(\.value)
    }

    private func shortDisplayValue(_ value: String?) -> String? {
        guard let value, value.isEmpty == false else { return nil }
        if let url = URL(string: value), let host = url.host {
            return host
        }
        return value
    }

    private func tagItem(label: String, value: String?) -> TagItem? {
        guard let value, value.isEmpty == false else { return nil }
        return TagItem(label: label, value: value)
    }
}

private struct EventDetailView: View {
    let event: NostrEvent
    let metadata: MetadataEvent?
    @Environment(\.verticalSizeClass) private var verticalSizeClass

    private struct TagItem: Hashable {
        let label: String
        let value: String
    }

    private var title: String {
        tagValue("name") ?? tagValue("description") ?? tagValue("alt") ?? event.pubkey
    }

    private var pubkeyFont: Font {
        verticalSizeClass == .regular ? .system(size: 7, weight: .regular, design: .monospaced) : .caption2.monospaced()
    }

    private var repoID: String? {
        tagValue("d")
    }

    private var cloneURL: String? {
        tagValue("clone")
    }

    private var webURL: String? {
        tagValue("web")
    }

    private var relaysText: String? {
        values(for: "relays").first
    }

    private var maintainersText: String? {
        values(for: "maintainers").first
    }

    private var detailTags: [TagItem] {
        [
            tagItem(label: "Repo", value: repoID),
            tagItem(label: "Name", value: tagValue("name")),
            tagItem(label: "Description", value: tagValue("description")),
            tagItem(label: "Alt", value: tagValue("alt")),
            tagItem(label: "Clone", value: shortDisplayValue(cloneURL)),
            tagItem(label: "Web", value: shortDisplayValue(webURL)),
            tagItem(label: "Relays", value: relaysText),
            tagItem(label: "Maintainers", value: maintainersText)
        ]
        .compactMap { $0 }
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
                                .foregroundColor(.primary)
                        }

                        if let about = metadata?.about, !about.isEmpty {
                            Text(about)
                                .font(.caption)
                                .foregroundColor(.primary)
                        }
                    }
                }

                if !event.content.isEmpty {
                    Text(event.content)
                        .font(.body)
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(.systemGray6))
                        .cornerRadius(10)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("ID: \(event.id)")
                        .font(.system(size: 14, weight: .semibold, design: .monospaced))
                    Text("Kind: \(event.kind.rawValue)")
                    if let repoID {
                        Text("Repository: \(repoID)")
                    }
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text("Clone:")
                        Text(cloneURL ?? "—")
                            .layoutPriority(1)
                    }
                    .font(.body.monospaced())
                    .foregroundColor(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                    .allowsTightening(true)
                    .fixedSize(horizontal: true, vertical: false)
                    if let webURL {
                        Text("Web: \(webURL)")
                    }
                    if let relaysText {
                        Text("Relays: \(relaysText)")
                    }
                    if let maintainersText {
                        Text("Maintainers: \(maintainersText)")
                    }
                    Text("Created At: \(event.createdDate.formatted(date: .long, time: .complete))")
                }
                .font(.body)
                .foregroundColor(.primary)

                if detailTags.isEmpty == false {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Tags")
                            .font(.headline)

                        VStack(alignment: .leading, spacing: 8) {
                            ForEach(detailTags, id: \.self) { item in
                                TagChipView(label: item.label, value: item.value)
                            }
                        }
                    }
                }
            }
            .padding()
        }
        .navigationTitle("Event Details")
        .safeAreaInset(edge: .bottom) {
            Text("Signature: \(event.signature ?? "N/A")")
                .font(.caption.monospaced())
                .foregroundColor(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal)
                .padding(.vertical, 8)
                .background(.ultraThinMaterial)
        }
    }

    private func tagValue(_ name: String) -> String? {
        event.tags.first(where: { $0.name == name })?.value
    }

    private func values(for name: String) -> [String] {
        event.tags.filter { $0.name == name }.map(\.value)
    }

    private func shortDisplayValue(_ value: String?) -> String? {
        guard let value, value.isEmpty == false else { return nil }
        if let url = URL(string: value), let host = url.host {
            return host
        }
        return value
    }

    private func tagItem(label: String, value: String?) -> TagItem? {
        guard let value, value.isEmpty == false else { return nil }
        return TagItem(label: label, value: value)
    }

    @ViewBuilder
    private var banner: some View {
        if let bannerURL = metadata?.bannerPictureURL {
            TinyWebImageView(url: bannerURL)
                .frame(maxWidth: .infinity)
                .frame(height: 140)
                .cornerRadius(16)
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
            TinyWebImageView(url: pictureURL)
                .frame(width: 96, height: 96)
                .clipShape(Circle())
                .overlay(Circle().stroke(Color(.separator).opacity(0.2), lineWidth: 1))
        } else {
            detailAvatarPlaceholder
        }
    }

    private var detailAvatarPlaceholder: some View {
        ZStack {
            Circle()
                .fill(Color(.tertiarySystemFill))
            Image("GnostrIcon")
                .resizable()
                .scaledToFit()
                .padding(16)
        }
        .frame(width: 96, height: 96)
    }
}

private struct TagChipView: View {
    let label: String
    let value: String

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text("\(label):")
                    .font(.caption2.weight(.semibold))
                    .foregroundColor(.primary)

                Text(value)
                    .font(.caption.monospaced())
                    .foregroundColor(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .allowsTightening(true)
                    .layoutPriority(1)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("\(label):")
                    .font(.caption2.weight(.semibold))
                    .foregroundColor(.primary)
                Text(value)
                    .font(.caption.monospaced())
                    .foregroundColor(.primary)
                    .fixedSize(horizontal: false, vertical: true)
                    .multilineTextAlignment(.leading)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color(.tertiarySystemFill))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(Color(.separator).opacity(0.12))
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
        VStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 10) {
                Text("Author Public Key")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.primary)
                TextField(text: $authorPubkey) {
                    Text("Author Public Key (HEX)")
                }
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()

                Picker("Kind", selection: $selectedKind) {
                    ForEach(kindOptions.keys.sorted(), id: \.self) { number in
                        if let name = kindOptions[number] {
                            Text("\(name) (\(String(number)))")
                        } else {
                            Text("\(String(number))")
                        }
                    }
                }
                .pickerStyle(.menu)

                Button {
                    updateSubscription()
                } label: {
                    Text("Query")
                }
                .buttonStyle(.borderedProminent)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal)
            .padding(.top, 4)

            Divider()

            List {
                if !events.isEmpty {
                    if !authorPubkey.isEmpty {
                        Text("Showing events for \(authorPubkey)")
                            .font(.footnote)
                            .foregroundColor(.primary)
                            .listRowBackground(Color.clear)
                            .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 0, trailing: 16))
                            .listRowSeparator(.hidden)
                    }

                    ForEach(events, id: \.id) { event in
                        NavigationLink(destination: EventDetailView(event: event, metadata: metadataByPubkey[event.pubkey])) {
                            EventCardView(event: event, metadata: metadataByPubkey[event.pubkey])
                        }
                        .buttonStyle(.plain)
                        .listRowInsets(EdgeInsets(top: 4, leading: 8, bottom: 4, trailing: 8))
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                    }
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
        }
        .navigationTitle("NIP-0034 Viewer")
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
                    print("[QueryRelayDemo] metadata event pubkey=\(metadataEvent.pubkey) createdAt=\(metadataEvent.createdAt) displayName=\(metadataEvent.displayName ?? "nil") name=\(metadataEvent.name ?? "nil") pictureURL=\(metadataEvent.pictureURL?.absoluteString ?? "nil") bannerURL=\(metadataEvent.bannerPictureURL?.absoluteString ?? "nil")")
                    if metadataByPubkey[metadataEvent.pubkey]?.createdAt ?? 0 <= metadataEvent.createdAt {
                        metadataByPubkey[metadataEvent.pubkey] = metadataEvent
                        print("[QueryRelayDemo] cached metadata pubkey=\(metadataEvent.pubkey)")
                        RemoteImagePrefetcher.shared.prefetch(url: metadataEvent.pictureURL)
                        RemoteImagePrefetcher.shared.prefetch(url: metadataEvent.bannerPictureURL)
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
