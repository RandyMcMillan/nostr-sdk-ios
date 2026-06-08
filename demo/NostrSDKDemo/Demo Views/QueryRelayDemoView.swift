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

    private var isPatch: Bool {
        event.kind.rawValue == 1617
    }

    private var cardTags: [TagItem] {
        let primaryTags: [TagItem?] = [
            tagItem(label: "Repo", value: repoID),
            tagItem(label: "Name", value: tagValue("name")),
            tagItem(label: "Description", value: tagValue("description")),
            tagItem(label: "Clone", value: shortDisplayValue(cloneURL)),
            tagItem(label: "Web", value: shortDisplayValue(webURL)),
            tagItem(label: "Relays", value: relaysText),
            tagItem(label: "Maintainers", value: maintainersText),
            tagItem(label: "Alt", value: tagValue("alt"))
        ]

        let primaryLabels = Set(primaryTags.compactMap { $0?.label.lowercased() })
        let extraTags = event.tags.compactMap { tag -> TagItem? in
            let label = tag.name.capitalized
            guard primaryLabels.contains(label.lowercased()) == false else { return nil }
            return tagItem(label: label, value: tag.value)
        }

        return (primaryTags.compactMap { $0 } + extraTags).prefix(8).map { $0 }
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

            VStack(alignment: .leading, spacing: 10) {
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
                        .padding(.top, 1)
                }

                if isPatch {
                    Text("PATCH")
                        .font(.caption2.weight(.bold))
                        .foregroundColor(.primary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            Capsule(style: .continuous)
                                .fill(Color.accentColor.opacity(0.18))
                        )
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

                HStack(alignment: .center, spacing: 8) {
                    Text("Kind \(event.kind.rawValue, format: .number.grouping(.never))")
                        .font(.caption2.weight(.bold))
                        .foregroundColor(.primary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            Capsule(style: .continuous)
                                .fill(Color.accentColor.opacity(0.12))
                        )
                    Text(event.createdDate.formatted(date: .abbreviated, time: .shortened))
                        .font(.caption)
                        .foregroundColor(.primary)
                    Spacer(minLength: 0)
                }

                if !event.content.isEmpty {
                    Text(event.content)
                        .font(.callout.monospaced())
                        .padding(10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(Color(.tertiarySystemFill))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(Color(.separator).opacity(0.12))
                        )
                        .lineLimit(6)
                }

                if let cloneURL {
                    Text(cloneURL)
                        .font(.caption)
                        .foregroundColor(.primary)
                        .lineLimit(1)
                }

                if cardTags.isEmpty == false {
                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(cardTags, id: \.self) { item in
                            TagChipView(label: item.label, value: item.value)
                        }
                    }
                    .padding(.top, 2)
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

private enum AuthorSource {
    case selfPubkey
    case followed
    case seen
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

    private var isPatch: Bool {
        event.kind.rawValue == 1617
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

                        if isPatch {
                            Text("PATCH")
                                .font(.caption2.weight(.bold))
                                .foregroundColor(.primary)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(
                                    Capsule(style: .continuous)
                                        .fill(Color.accentColor.opacity(0.18))
                                )
                        }

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

                VStack(alignment: .leading, spacing: 12) {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text("ID")
                            .font(.caption2.weight(.bold))
                            .foregroundColor(.primary)
                        Text(event.id)
                            .font(.caption.monospaced())
                            .foregroundColor(.primary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.6)
                            .allowsTightening(true)
                    }

                    HStack(alignment: .center, spacing: 8) {
                        Text("Kind \(event.kind.rawValue, format: .number.grouping(.never))")
                            .font(.caption2.weight(.bold))
                            .foregroundColor(.primary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(
                                Capsule(style: .continuous)
                                    .fill(Color.accentColor.opacity(0.12))
                            )
                        Text(event.createdDate.formatted(date: .long, time: .shortened))
                            .font(.caption)
                            .foregroundColor(.primary)
                        Spacer(minLength: 0)
                    }

                    if let repoID {
                        Text("Repository: \(repoID)")
                            .font(.body.monospaced())
                            .foregroundColor(.primary)
                    }

                    if !event.content.isEmpty {
                        Text(event.content)
                            .font(.callout.monospaced())
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(Color(.tertiarySystemFill))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .stroke(Color(.separator).opacity(0.12))
                            )
                    }

                    if let cloneURL {
                        Text("Clone: \(cloneURL)")
                            .font(.body.monospaced())
                            .foregroundColor(.primary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.5)
                            .allowsTightening(true)
                    }
                    if let webURL {
                        Text("Web: \(webURL)")
                            .font(.body)
                            .foregroundColor(.primary)
                    }
                    if let relaysText {
                        Text("Relays: \(relaysText)")
                            .font(.body)
                            .foregroundColor(.primary)
                    }
                    if let maintainersText {
                        Text("Maintainers: \(maintainersText)")
                            .font(.body)
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
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
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
    @EnvironmentObject private var identityStore: DemoIdentityStore

    @State private var selectedFollowedAuthorPubkey: String = ""
    @State private var selectedSeenAuthorPubkey: String = ""
    @State private var selectedAuthorSource: AuthorSource = .selfPubkey
    @State private var events: [NostrEvent] = []
    @State private var metadataByPubkey: [String: MetadataEvent] = [:]
    @State private var eventsCancellable: AnyCancellable?
    @State private var errorString: String?
    @State private var subscriptionId: String?
    @State private var seenPrimeSubscriptionId: String?
    @State private var metadataSubscriptionId: String?
    @State private var trackedMetadataPubkeys: Set<String> = []
    @State private var seenAuthorEventIDsByPubkey: [String: [Int: Set<String>]] = [:]

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
                HStack(alignment: .top, spacing: 12) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Followed Author")
                            .font(.caption.weight(.semibold))
                            .foregroundColor(.primary)
                        Menu {
                            Button("Select self") {
                                selectedFollowedAuthorPubkey = ""
                                selectedAuthorSource = .selfPubkey
                                events = []
                                updateSubscription()
                                updateMetadataSubscription()
                            }
                            ForEach(identityStore.followedPubkeys, id: \.self) { pubkey in
                                Button(pubkey) {
                                    selectedFollowedAuthorPubkey = pubkey
                                    selectedSeenAuthorPubkey = ""
                                    selectedAuthorSource = .followed
                                    events = []
                                    updateSubscription()
                                    updateMetadataSubscription()
                                }
                            }
                        } label: {
                            HStack {
                                Text(selectedFollowedAuthorPubkey.isEmpty ? "Select followed author" : selectedFollowedAuthorPubkey)
                                Spacer(minLength: 0)
                                Image(systemName: "chevron.down")
                            }
                            .padding(.vertical, 8)
                        }
                        .disabled(identityStore.followedPubkeys.isEmpty)
                        if identityStore.followedPubkeys.isEmpty {
                            Text("Enter a valid private key in Settings to load followed public keys.")
                                .font(.caption)
                                .foregroundColor(.primary)
                        }
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        Text("Seen Author")
                            .font(.caption.weight(.semibold))
                            .foregroundColor(.primary)
                        Menu {
                            Button("Select self") {
                                selectedSeenAuthorPubkey = ""
                                selectedAuthorSource = .selfPubkey
                                events = []
                                updateSubscription()
                                updateMetadataSubscription()
                            }
                            ForEach(seenAuthorPubkeys, id: \.self) { pubkey in
                                Button(seenAuthorLabel(for: pubkey)) {
                                    selectedSeenAuthorPubkey = pubkey
                                    selectedFollowedAuthorPubkey = ""
                                    selectedAuthorSource = .seen
                                    events = []
                                    updateSubscription()
                                    updateMetadataSubscription()
                                }
                            }
                        } label: {
                            HStack {
                                Text(selectedSeenAuthorPubkey.isEmpty ? "Select seen author" : seenAuthorLabel(for: selectedSeenAuthorPubkey))
                                Spacer(minLength: 0)
                                Image(systemName: "chevron.down")
                            }
                            .padding(.vertical, 8)
                        }
                        .disabled(seenAuthorPubkeys.isEmpty)
                        if seenAuthorPubkeys.isEmpty {
                            Text("Seen authors appear after NIP-34 events load.")
                                .font(.caption)
                                .foregroundColor(.primary)
                        }
                    }
                }

                HStack(alignment: .center, spacing: 12) {
                    Button {
                        updateSubscription()
                    } label: {
                        Text("Query")
                            .frame(minWidth: 72)
                    }
                    .buttonStyle(.borderedProminent)

                    Spacer(minLength: 0)

                    Picker("Kind", selection: $selectedKind) {
                        ForEach(kindOptions.keys.sorted(), id: \.self) { number in
                            if let name = kindOptions[number] {
                                Text(kindLabel(for: number, name: name))
                            } else {
                                Text("\(String(number))")
                            }
                        }
                    }
                    .pickerStyle(.menu)
                }
            }
            .padding(.horizontal)
            .padding(.top, 4)

            Divider()

            List {
                if !events.isEmpty {
                    if !currentAuthorPubkey.isEmpty {
                        Text("Showing events for \(currentAuthorPubkey)")
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
            sanitizeSelectedAuthors()
            primeSeenAuthors()
            updateSubscription()
            updateMetadataSubscription()
        }
        .onChange(of: identityStore.followedPubkeys) { _ in
            sanitizeSelectedAuthors()
        }
        .onChange(of: identityStore.publicKeyHex) { _ in
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
            if let seenPrimeSubscriptionId {
                relayPool.closeSubscription(with: seenPrimeSubscriptionId)
            }
            if let metadataSubscriptionId {
                relayPool.closeSubscription(with: metadataSubscriptionId)
            }
        }
    }

    private var currentFilter: Filter {
        let authors: [String]?
        if currentAuthorPubkey.isEmpty {
            authors = nil
        } else {
            authors = [currentAuthorPubkey]
        }
        return Filter(authors: authors, kinds: [selectedKind])!
    }

    private var currentAuthorPubkey: String {
        switch selectedAuthorSource {
        case .followed:
            return selectedFollowedAuthorPubkey
        case .seen:
            return selectedSeenAuthorPubkey
        case .selfPubkey:
            return identityStore.publicKeyHex ?? ""
        }
    }

    private var seenAuthorPubkeys: [String] {
        seenAuthorEventIDsByPubkey.keys.sorted { lhs, rhs in
            let lhsCount = seenAuthorCounts(for: lhs).reduce(0, +)
            let rhsCount = seenAuthorCounts(for: rhs).reduce(0, +)
            if lhsCount != rhsCount { return lhsCount > rhsCount }
            return lhs < rhs
        }
    }

    private func seenAuthorLabel(for pubkey: String) -> String {
        let counts = seenAuthorCounts(for: pubkey).map(String.init).joined(separator: ",")
        return "\(pubkey) (\(counts))"
    }

    private func seenAuthorCounts(for pubkey: String) -> [Int] {
        kindOptions.keys.sorted().map { kind in
            seenAuthorEventIDsByPubkey[pubkey]?[kind]?.count ?? 0
        }
    }

    private func kindLabel(for kind: Int, name: String) -> String {
        let count: Int
        switch selectedAuthorSource {
        case .followed:
            count = seenAuthorEventIDsByPubkey[selectedFollowedAuthorPubkey]?[kind]?.count ?? 0
        case .seen:
            count = seenAuthorEventIDsByPubkey[selectedSeenAuthorPubkey]?[kind]?.count ?? 0
        case .selfPubkey:
            count = seenAuthorEventIDsByPubkey.values.reduce(0) { partial, kindsByPubkey in
                partial + (kindsByPubkey[kind]?.count ?? 0)
            }
        }
        return "\(name) (\(kind)) (\(count))"
    }

    private func sanitizeSelectedAuthors() {
        if selectedFollowedAuthorPubkey.isEmpty == false,
           identityStore.followedPubkeys.contains(selectedFollowedAuthorPubkey) == false {
            selectedFollowedAuthorPubkey = ""
            if selectedAuthorSource == .followed {
                selectedAuthorSource = .selfPubkey
            }
        }

        if selectedSeenAuthorPubkey.isEmpty == false,
           seenAuthorEventIDsByPubkey[selectedSeenAuthorPubkey] == nil {
            selectedSeenAuthorPubkey = ""
            if selectedAuthorSource == .seen {
                selectedAuthorSource = .selfPubkey
            }
        }
    }

    private func recordSeenEvent(_ event: NostrEvent) {
        var kindsByPubkey = seenAuthorEventIDsByPubkey[event.pubkey] ?? [:]
        var eventIDs = kindsByPubkey[event.kind.rawValue] ?? []
        eventIDs.insert(event.id)
        kindsByPubkey[event.kind.rawValue] = eventIDs
        seenAuthorEventIDsByPubkey[event.pubkey] = kindsByPubkey
    }

    private func updateSubscription() {
        if let subscriptionId {
            relayPool.closeSubscription(with: subscriptionId)
        }

        subscriptionId = relayPool.subscribe(with: currentFilter)

        eventsCancellable = relayPool.events
            .receive(on: DispatchQueue.main)
            .sink { relayEvent in
                guard relayEvent.subscriptionId == subscriptionId || relayEvent.subscriptionId == seenPrimeSubscriptionId else {
                    return
                }

                let event = relayEvent.event

                if relayEvent.subscriptionId == seenPrimeSubscriptionId {
                    recordSeenEvent(event)
                    return
                }

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

                recordSeenEvent(event)
                if events.contains(where: { $0.id == event.id }) == false {
                    events.insert(event, at: 0)
                }
                updateMetadataSubscription()
            }
    }

    private func primeSeenAuthors() {
        if let seenPrimeSubscriptionId {
            relayPool.closeSubscription(with: seenPrimeSubscriptionId)
        }

        guard let filter = Filter(kinds: Array(kindOptions.keys.sorted())) else {
            seenPrimeSubscriptionId = nil
            return
        }

        seenPrimeSubscriptionId = relayPool.subscribe(with: filter)
    }

    private func updateMetadataSubscription() {
        var pubkeys = Set(events.map(\.pubkey))
        if currentAuthorPubkey.isEmpty == false {
            pubkeys.insert(currentAuthorPubkey)
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
        .environmentObject(RelayPool(relays: []))
        .environmentObject(DemoIdentityStore())
    }
}
