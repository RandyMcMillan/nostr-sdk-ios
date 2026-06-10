import Foundation
import GnostrSDK
import SwiftUI

public enum ContextAwareSortOrder: String, CaseIterable, Identifiable {
    case urlAscending
    case urlDescending

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .urlAscending:
            return "URL A-Z"
        case .urlDescending:
            return "URL Z-A"
        }
    }

    public var toggled: Self {
        switch self {
        case .urlAscending:
            return .urlDescending
        case .urlDescending:
            return .urlAscending
        }
    }

    public var toggleTitle: String {
        switch self {
        case .urlAscending:
            return "A-Z"
        case .urlDescending:
            return "Z-A"
        }
    }

    public func sort(urls: [URL]) -> [URL] {
        switch self {
        case .urlAscending:
            return urls.sorted { $0.absoluteString < $1.absoluteString }
        case .urlDescending:
            return urls.sorted { $0.absoluteString > $1.absoluteString }
        }
    }
}

public struct ContextAwareSortChipButton: View {
    private let title: String
    private let isSelected: Bool
    private let action: () -> Void

    public init(title: String, isSelected: Bool, action: @escaping () -> Void) {
        self.title = title
        self.isSelected = isSelected
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            Text(title)
                .font(.caption.weight(.semibold))
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 999, style: .continuous)
                        .fill(isSelected ? Color.accentColor.opacity(0.16) : Color(.tertiarySystemFill))
                )
        }
        .buttonStyle(.plain)
    }
}

public struct ContextAwareSortToggleChip<Selection: Equatable>: View {
    @Binding private var selection: Selection
    private let ascending: Selection
    private let descending: Selection
    private let ascendingTitle: String
    private let descendingTitle: String

    public init(selection: Binding<Selection>, ascending: Selection, descending: Selection, ascendingTitle: String, descendingTitle: String) {
        _selection = selection
        self.ascending = ascending
        self.descending = descending
        self.ascendingTitle = ascendingTitle
        self.descendingTitle = descendingTitle
    }

    private var currentTitle: String {
        selection == descending ? descendingTitle : ascendingTitle
    }

    private var isSelected: Bool {
        selection == ascending || selection == descending
    }

    public var body: some View {
        ContextAwareSortChipButton(title: currentTitle, isSelected: isSelected) {
            selection = selection == ascending ? descending : ascending
        }
    }
}

public enum RelaySortOption: String, CaseIterable, Identifiable {
    case urlAscending
    case urlDescending
    case pingAscending
    case pingDescending

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .urlAscending:
            return "URL A-Z"
        case .urlDescending:
            return "URL Z-A"
        case .pingAscending:
            return "Ping ↑"
        case .pingDescending:
            return "Ping ↓"
        }
    }

    public var shortTitle: String {
        switch self {
        case .urlAscending:
            return "URL A-Z"
        case .urlDescending:
            return "URL Z-A"
        case .pingAscending:
            return "Ping ↑"
        case .pingDescending:
            return "Ping ↓"
        }
    }

    public func sort(relays: [Relay]) -> [Relay] {
        relays.sorted { lhs, rhs in
            let leftRank = stateRank(for: lhs)
            let rightRank = stateRank(for: rhs)
            if leftRank != rightRank {
                return leftRank < rightRank
            }

            switch self {
            case .urlAscending:
                return lhs.url.absoluteString < rhs.url.absoluteString
            case .urlDescending:
                return lhs.url.absoluteString > rhs.url.absoluteString
            case .pingAscending:
                return pingSortComparison(lhs, rhs, ascending: true)
            case .pingDescending:
                return pingSortComparison(lhs, rhs, ascending: false)
            }
        }
    }

    private func pingSortComparison(_ lhs: Relay, _ rhs: Relay, ascending: Bool) -> Bool {
        let leftPing = lhs.connectionLatency
        let rightPing = rhs.connectionLatency
        switch (leftPing, rightPing) {
        case let (left?, right?):
            if left != right {
                return ascending ? left < right : left > right
            }
        case (.some, .none):
            return true
        case (.none, .some):
            return false
        case (.none, .none):
            break
        }

        if ascending {
            return lhs.url.absoluteString < rhs.url.absoluteString
        } else {
            return lhs.url.absoluteString > rhs.url.absoluteString
        }
    }

    private func stateRank(for relay: Relay) -> Int {
        switch relay.state {
        case .connected:
            return 0
        case .connecting:
            return 1
        case .notConnected, .error:
            return 2
        }
    }
}
