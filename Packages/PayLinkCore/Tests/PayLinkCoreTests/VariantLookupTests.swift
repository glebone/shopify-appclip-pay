import XCTest
@testable import PayLinkCore

final class VariantLookupTests: XCTestCase {
    let okJSON = """
    {"data":{"node":{"title":"Default Title","price":{"amount":"5.0","currencyCode":"USD"},
     "image":{"url":"https://cdn.shopify.com/s/files/1/x/demo.png"},
     "product":{"title":"Demo Pass"}}}}
    """.data(using: .utf8)!

    func testDecodesSummary() throws {
        let v = try VariantLookup.decode(okJSON)
        XCTAssertEqual(v.title, "Demo Pass")
        XCTAssertEqual(v.variantTitle, "Default Title")
        XCTAssertEqual(v.amount, Decimal(string: "5.0"))
        XCTAssertEqual(v.currencyCode, "USD")
        XCTAssertEqual(v.imageURL, URL(string: "https://cdn.shopify.com/s/files/1/x/demo.png"))
    }

    func testDecodesMissingImage() throws {
        let json = """
        {"data":{"node":{"title":"Default Title","price":{"amount":"12.50","currencyCode":"USD"},
         "image":null,"product":{"title":"Demo Pass"}}}}
        """.data(using: .utf8)!
        XCTAssertNil(try VariantLookup.decode(json).imageURL)
    }

    func testNullNodeIsNotFound() {
        // Review Focus 3: variant deleted or not published to the Headless channel
        let json = #"{"data":{"node":null}}"#.data(using: .utf8)!
        XCTAssertThrowsError(try VariantLookup.decode(json)) {
            XCTAssertEqual($0 as? VariantLookup.LookupError, .notFound)
        }
    }

    func testGraphQLErrorsSurfaceMessages() {
        // Review Focus 4: bad token or scope
        let json = #"{"errors":[{"message":"Invalid API key or access token"}]}"#.data(using: .utf8)!
        XCTAssertThrowsError(try VariantLookup.decode(json)) {
            XCTAssertEqual($0 as? VariantLookup.LookupError, .graphQL(["Invalid API key or access token"]))
        }
    }

    func testGarbageIsMalformed() {
        XCTAssertThrowsError(try VariantLookup.decode(Data("<html>".utf8))) {
            XCTAssertEqual($0 as? VariantLookup.LookupError, .malformed)
        }
    }

    func testRequestShape() throws {
        let req = VariantLookup.request(domain: "shop.myshopify.com", apiVersion: "2026-04",
                                        token: "tok", variantID: "gid://shopify/ProductVariant/9")
        XCTAssertEqual(req.url?.absoluteString, "https://shop.myshopify.com/api/2026-04/graphql.json")
        XCTAssertEqual(req.httpMethod, "POST")
        XCTAssertEqual(req.value(forHTTPHeaderField: "X-Shopify-Storefront-Access-Token"), "tok")
        XCTAssertEqual(req.value(forHTTPHeaderField: "Content-Type"), "application/json")
        let body = try XCTUnwrap(req.httpBody)
        let obj = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Any])
        XCTAssertEqual(obj["query"] as? String, VariantLookup.query)
        XCTAssertEqual((obj["variables"] as? [String: String])?["id"], "gid://shopify/ProductVariant/9")
    }

    func testFormattedPriceUSD() {
        let v = VariantSummary(title: "x", variantTitle: nil, amount: 5, currencyCode: "USD", imageURL: nil)
        XCTAssertEqual(v.formattedPrice(locale: Locale(identifier: "en_US")), "$5.00")
    }
}
