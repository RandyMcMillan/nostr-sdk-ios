import Foundation
@testable import NostrSDK
@testable import NostrSDKDemo
import XCTest

final class NostrSDKDemoSmokeTests: XCTestCase {
    func testPrimeStoreRecordsCloneTagEvents() throws {
        let store = DemoAppPrimeStore()
        let cloneURL = RepoURLs.cloneTag
        let expectedURL = RepoURLs.ssh
        let event = NostrEvent(
            kind: .unknown(30617),
            content: "",
            tags: [
                Tag(name: .identifier, value: RepoURLs.identifier),
                Tag(name: "clone", value: cloneURL)
            ],
            createdAt: 1,
            pubkey: RepoURLs.pubkey
        )

        store.record(event: event)

        XCTAssertEqual(store.seenRepositoryURLs, [expectedURL])
        XCTAssertEqual(store.repositoryEventByRepoIDAndKind[RepoURLs.identifier]?[30617]?.id, event.id)
    }

    func testNormalizesRepositoryCloneURLs() {
        for form in RepoURLs.expectedForms {
            XCTAssertEqual(
                DemoRepositoryHostStore.normalizedRepositoryCloneURL(from: form.rawValue),
                form.expected
            )
        }
    }
}

private enum RepoURLs {
    static let owner = "gnostr-org"
    static let repo = "gnostr"
    static let identifier = "repo-1"
    static let pubkey = String(repeating: "2", count: 64)
    static let cloneTag = scp

    static let ssh = URL(string: "ssh://git@github.com/\(owner)/\(repo).git")!

    static let expectedForms: [ExpectedForm] = [
        .init(rawValue: https.absoluteString, expected: https),
        .init(rawValue: ssh.absoluteString, expected: ssh),
        .init(rawValue: scp, expected: ssh)
    ]

    private static let https = URL(string: "https://github.com/\(owner)/\(repo).git")!
    private static let scp = "git@github.com:\(owner)/\(repo).git"

    struct ExpectedForm {
        let rawValue: String
        let expected: URL
    }
}
