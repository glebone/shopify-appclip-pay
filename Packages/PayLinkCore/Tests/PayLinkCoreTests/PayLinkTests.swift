import XCTest
@testable import PayLinkCore

final class PayLinkTests: XCTestCase {
    func testParsesDirectoryURL() throws {
        let link = try PayLink.parse(URL(string: "https://example.github.io/pay/?v=45678901234567")!)
        XCTAssertEqual(link.numericID, "45678901234567")
        XCTAssertEqual(link.variantID, "gid://shopify/ProductVariant/45678901234567")
    }

    func testParsesWithoutTrailingSlash() throws {
        let link = try PayLink.parse(URL(string: "https://example.github.io/pay?v=1")!)
        XCTAssertEqual(link.numericID, "1")
    }

    func testParsesIndexHTMLRewrite() throws {
        // Review Focus 1: Safari may rewrite /pay/ to /pay/index.html
        let link = try PayLink.parse(URL(string: "https://example.github.io/pay/index.html?v=42")!)
        XCTAssertEqual(link.numericID, "42")
    }

    func testRejectsHTTP() {
        XCTAssertThrowsError(try PayLink.parse(URL(string: "http://example.github.io/pay/?v=1")!)) {
            XCTAssertEqual($0 as? PayLink.ParseError, .notHTTPS)
        }
    }

    func testRejectsWrongPath() {
        XCTAssertThrowsError(try PayLink.parse(URL(string: "https://example.github.io/other/?v=1")!)) {
            XCTAssertEqual($0 as? PayLink.ParseError, .wrongPath)
        }
    }

    func testRejectsMissingVariant() {
        XCTAssertThrowsError(try PayLink.parse(URL(string: "https://example.github.io/pay/")!)) {
            XCTAssertEqual($0 as? PayLink.ParseError, .missingVariant)
        }
        XCTAssertThrowsError(try PayLink.parse(URL(string: "https://example.github.io/pay/?v=")!)) {
            XCTAssertEqual($0 as? PayLink.ParseError, .missingVariant)
        }
    }

    func testRejectsNonNumericVariant() {
        // Review Focus 2: gid strings, whitespace, negatives must never reach the SDK
        for bad in ["abc", "gid://shopify/ProductVariant/1", "%2012", "-5", "12abc"] {
            let url = URL(string: "https://example.github.io/pay/?v=\(bad)")!
            XCTAssertThrowsError(try PayLink.parse(url), bad) {
                XCTAssertEqual($0 as? PayLink.ParseError, .invalidVariant, bad)
            }
        }
    }
}

final class PayLinkIdentityTests: XCTestCase {
    func testPayLinkIsHashableSoViewsCanKeyOnIt() {
        // Review fix 1: RootView uses .id(link) so a second link rebuilds PayView's state
        let a = PayLink(numericID: "1"), b = PayLink(numericID: "2"), a2 = PayLink(numericID: "1")
        let set: Set<PayLink> = [a, b, a2]
        XCTAssertEqual(set.count, 2)
        XCTAssertEqual(a.hashValue, a2.hashValue)
    }
}
