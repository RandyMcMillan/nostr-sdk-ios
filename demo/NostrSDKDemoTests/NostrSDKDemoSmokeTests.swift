import Foundation
@testable import NostrSDK
@testable import NostrSDKDemo
import XCTest

final class NostrSDKDemoSmokeTests: XCTestCase {
    func testPrimeStoreRecordsCloneTagEvents() throws {
        let store = DemoAppPrimeStore()
        let cloneURL = "git@github.com:owner/repo.git"
        let expectedURL = URL(string: "ssh://git@github.com/owner/repo.git")!
        let event = NostrEvent(
            kind: .unknown(30617),
            content: "",
            tags: [
                Tag(name: .identifier, value: "repo-1"),
                Tag(name: "clone", value: cloneURL)
            ],
            createdAt: 1,
            pubkey: String(repeating: "2", count: 64)
        )

        store.record(event: event)

        XCTAssertEqual(store.seenRepositoryURLs, [expectedURL])
        XCTAssertEqual(store.repositoryEventByRepoIDAndKind["repo-1"]?[30617]?.id, event.id)
    }

    func testNormalizesRepositoryCloneURLs() {
        let httpsURL = URL(string: "https://github.com/owner/repo.git")!
        XCTAssertEqual(DemoRepositoryHostStore.normalizedRepositoryCloneURL(from: httpsURL.absoluteString), httpsURL)
        XCTAssertEqual(
            DemoRepositoryHostStore.normalizedRepositoryCloneURL(from: "git@github.com:owner/repo.git"),
            URL(string: "ssh://git@github.com/owner/repo.git")
        )
    }
}
