import XCTest
@testable import PayLinkCore

final class LaunchStateTests: XCTestCase {
    func testNilURLIsWaiting() {
        // Review Focus 5: launched without a user activity
        XCTAssertEqual(LaunchState.from(invocationURL: nil), .waiting)
    }

    func testValidURLIsReady() {
        let url = URL(string: "https://example.github.io/pay/?v=7")!
        XCTAssertEqual(LaunchState.from(invocationURL: url), .ready(PayLink(numericID: "7")))
    }

    func testInvalidURLIsFailedWithReadableMessage() {
        let url = URL(string: "https://example.github.io/pay/?v=abc")!
        guard case let .failed(message) = LaunchState.from(invocationURL: url) else {
            return XCTFail("expected .failed")
        }
        XCTAssertTrue(message.contains("invalid"), message)
    }
}
