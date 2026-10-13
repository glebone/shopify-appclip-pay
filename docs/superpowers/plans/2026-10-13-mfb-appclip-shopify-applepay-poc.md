# MfB → App Clip → Shopify Apple Pay POC Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Prove on a real iPhone that a link sent through Apple Messages for Business (Infobip) opens an App Clip whose only control is Shopify's native Apple Pay button, and that paying creates a test order in a Shopify store.

**Architecture:** A parent iOS app exists only to carry an App Clip target. The App Clip parses the invocation URL (`https://<domain>/pay/?v=<variant>`), fetches the variant's title and price from the Storefront API, and renders `AcceleratedCheckoutButtons` from Shopify Checkout Kit restricted to Apple Pay. A static GitHub Pages site serves the AASA file and the landing page with the App Clip meta tags. Shell scripts handle the Shopify certificate exchange and the Infobip send. URL parsing and Storefront decoding live in a local Swift package so they are unit-tested on macOS without a device.

**Tech Stack:** Swift 6 / SwiftUI, iOS 17.0 deployment target, XcodeGen 2.46, Shopify `checkout-sheet-kit-swift` 3.9.2 (`ShopifyAcceleratedCheckouts`), Storefront GraphQL API 2026-04, GitHub Pages via Actions, Infobip Apple MfB REST API, bash + curl + jq.

**Spec:** `docs/superpowers/specs/2026-10-13-mfb-appclip-shopify-applepay-requirements.md`

## Global Constraints

- iOS deployment target `17.0` for both targets (spec A6). Accelerated Checkouts needs iOS 16+; 17+ unlocks the 100 MB App Clip budget with digital-only invocation (F4).
- Shopify package version `from: "3.9.2"`; product `ShopifyAcceleratedCheckouts` (F5, README prerequisites).
- Variant IDs passed to the SDK must start with `gid://shopify/ProductVariant/` (SDK doc comment on `AcceleratedCheckoutButtons.init(variantID:quantity:)`).
- Quantity is always `1`; one variant per link (spec A1, A2).
- Only wallet shown: `.wallets([.applePay])` (spec FR5).
- Invocation URL shape: `https://<CLIP_DOMAIN>/pay/?v=<numeric variant id>` (spec FR4, D4). The `/pay/` directory is what GitHub Pages can serve.
- No secrets in git. `Config/Local.xcconfig` is gitignored; only `Config/Local.xcconfig.example` is committed (spec NFR4). Storefront public token ships in the clip's Info.plist (spec A3).
- Shopify Payments stays in test mode at all times (spec NFR1). Test purchases must exceed 1 USD (F6).
- Demo modes in order: A (`_XCAppClipURL`), B (Local Experience + iMessage from a contact), C (App Store + Infobip) (spec NFR6, D3).
- All text the customer sees is English; the only screen is product title, price, image, Apple Pay button, then a confirmation line (spec FR5, FR7).
- Every task ends with a commit on `main`.

## Review Focus

1. Invocation URL arrives as `/pay/index.html?v=…` (Safari sometimes rewrites directory URLs) — must parse like `/pay/?v=…`. Test added in Task 2.
2. `v` contains whitespace, a `gid://` string, or a negative number — must be rejected with `invalidVariant`, never passed to the SDK. Test added in Task 2.
3. Storefront returns `"node": null` (variant deleted or not published to the Headless channel) — PayView must still show the Apple Pay button and a short "product unavailable" line, not crash. Test for the decode half added in Task 3; manual check in Task 8.
4. Storefront returns a top-level `errors` array (bad token or scope) — error message must name the GraphQL message so the developer can fix the token. Test added in Task 3.
5. App Clip launched with no `NSUserActivity` (for example from the App Clip card test in Xcode without `_XCAppClipURL`) — must show a "waiting for link" state, never a blank screen. Test on the pure state function added in Task 3; manual check in Task 8.

---

## File Structure

```
Shopify_AppClip/
├── .gitignore
├── README.md                                  # setup + demo checklist, filled in by the tasks below
├── project.yml                                # XcodeGen spec: PayDemo (app) + PayClip (App Clip)
├── Config/
│   ├── Local.xcconfig.example                 # committed template of every parameter
│   └── Local.xcconfig                         # gitignored; real values
├── Packages/PayLinkCore/
│   ├── Package.swift
│   ├── Sources/PayLinkCore/
│   │   ├── PayLink.swift                      # invocation URL → variant gid
│   │   ├── LaunchState.swift                  # nil / parsed / failed state for the root view
│   │   └── VariantLookup.swift                # Storefront GraphQL request + decode + fetch
│   └── Tests/PayLinkCoreTests/
│       ├── PayLinkTests.swift
│       ├── LaunchStateTests.swift
│       └── VariantLookupTests.swift
├── App/
│   └── PayDemoApp.swift                       # parent app, one static screen
├── Clip/
│   ├── PayClipApp.swift                       # @main, SDK configuration, user-activity handling
│   ├── ClipConfig.swift                       # reads parameters from Info.plist
│   ├── RootView.swift                         # switches on LaunchState
│   └── PayView.swift                          # product + AcceleratedCheckoutButtons
├── site-src/
│   ├── apple-app-site-association.tmpl        # tokens replaced by scripts/render_site.sh
│   └── pay.html.tmpl
├── site/                                      # generated, committed, deployed to GitHub Pages
│   ├── .nojekyll
│   ├── index.html
│   ├── preview.png
│   ├── .well-known/apple-app-site-association
│   └── pay/index.html
├── .github/workflows/pages.yml
└── scripts/
    ├── config.sh                              # exports Config/Local.xcconfig keys as shell vars
    ├── render_site.sh                         # site-src → site
    ├── make_preview.py                        # 1200×630 PNG for og:image, no dependencies
    ├── check_aasa.sh                          # direct + Apple CDN check
    ├── apple_pay_cert.sh                      # Shopify CSR ↔ Apple certificate exchange
    └── send_mfb_appclip.sh                    # Infobip APP_CLIP message
```

---

### Task 1: Repository scaffold and configuration contract

**Files:**
- Create: `.gitignore`
- Create: `Config/Local.xcconfig.example`
- Create: `scripts/config.sh`
- Create: `README.md`

**Interfaces:**
- Produces: `Config/Local.xcconfig` keys `DEVELOPMENT_TEAM`, `APP_BUNDLE_ID`, `CLIP_DOMAIN`, `APP_STORE_ID`, `STOREFRONT_DOMAIN`, `STOREFRONT_ACCESS_TOKEN`, `APPLE_PAY_MERCHANT_ID`, `DEMO_VARIANT_ID`, `STOREFRONT_API_VERSION`. Every later task reads these names exactly.
- Produces: `scripts/config.sh` which, when sourced, exports each key above as a shell variable of the same name.

- [ ] **Step 1: Write `.gitignore`**

```gitignore
# Xcode
*.xcodeproj
*.xcworkspace
xcuserdata/
DerivedData/
.build/
.swiftpm/
*.ipa
*.dSYM.zip

# Secrets and local parameters
Config/Local.xcconfig
*.cer
*.csr
*.p12
.env

# macOS
.DS_Store
```

- [ ] **Step 2: Write `Config/Local.xcconfig.example`**

```
// Copy to Config/Local.xcconfig and fill in. Never commit Local.xcconfig.
// xcconfig syntax: KEY = value. Values must not contain "//" (treated as a comment).

// Apple Developer team ID (10 characters), from developer.apple.com/account → Membership
DEVELOPMENT_TEAM = ABCDE12345

// Parent app bundle ID. The App Clip is always $(APP_BUNDLE_ID).Clip
APP_BUNDLE_ID = com.example.payclipdemo

// Host that serves site/ (GitHub Pages). No scheme, no path.
CLIP_DOMAIN = example.github.io

// Numeric Apple ID of the app record in App Store Connect (App Information → General → Apple ID).
// Use 0 until Task 6 creates the record.
APP_STORE_ID = 0

// Shopify
STOREFRONT_DOMAIN = example-store.myshopify.com
STOREFRONT_ACCESS_TOKEN = 00000000000000000000000000000000
STOREFRONT_API_VERSION = 2026-04

// Apple Pay merchant ID registered in the developer portal (Task 6)
APPLE_PAY_MERCHANT_ID = merchant.com.example.payclipdemo

// Numeric product variant ID of the demo item (Task 7). Appears in the admin URL
// admin.shopify.com/store/<store>/products/<product>/variants/<DEMO_VARIANT_ID>
DEMO_VARIANT_ID = 0
```

- [ ] **Step 3: Write `scripts/config.sh`**

```bash
#!/usr/bin/env bash
# Source this file: `source scripts/config.sh`
# Exports every KEY = value line of Config/Local.xcconfig as a shell variable.
_cfg="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/Config/Local.xcconfig"
if [[ ! -f "$_cfg" ]]; then
  echo "Missing $_cfg. Copy Config/Local.xcconfig.example and fill it in." >&2
  return 1 2>/dev/null || exit 1
fi
while IFS= read -r line; do
  line="${line%%//*}"                      # strip comments
  [[ "$line" =~ ^[[:space:]]*([A-Z_][A-Z0-9_]*)[[:space:]]*=[[:space:]]*(.*)$ ]] || continue
  key="${BASH_REMATCH[1]}"
  val="${BASH_REMATCH[2]}"
  val="${val%"${val##*[![:space:]]}"}"     # trim trailing spaces
  export "$key=$val"
done < "$_cfg"
unset _cfg line key val
```

- [ ] **Step 4: Create a working Local.xcconfig and verify the exporter**

```bash
cp Config/Local.xcconfig.example Config/Local.xcconfig
chmod +x scripts/config.sh
bash -c 'source scripts/config.sh && echo "domain=$CLIP_DOMAIN bundle=$APP_BUNDLE_ID version=$STOREFRONT_API_VERSION"'
```

Expected: `domain=example.github.io bundle=com.example.payclipdemo version=2026-04`

- [ ] **Step 5: Write `README.md` skeleton**

```markdown
# MfB → App Clip → Shopify Apple Pay (proof of concept)

One link in Apple Messages for Business opens an App Clip with a single Apple Pay button
backed by Shopify Checkout Kit. Spec: `docs/superpowers/specs/`. Plan: `docs/superpowers/plans/`.

## Parameters

Copy `Config/Local.xcconfig.example` to `Config/Local.xcconfig` and fill every key.
Shell scripts read the same file via `source scripts/config.sh`.

## Build

    xcodegen generate
    open PayClipDemo.xcodeproj

Schemes: `PayDemo` (parent app), `PayClip` (App Clip, launches with `_XCAppClipURL`).

## Unit tests

    swift test --package-path Packages/PayLinkCore

## Demo modes

- Mode A: run the `PayClip` scheme on a device; `_XCAppClipURL` supplies the link.
- Mode B: register a Local Experience, then text the link from a contact.
- Mode C: App Store release, then `scripts/send_mfb_appclip.sh`.

Sections below are filled in by later tasks.
```

- [ ] **Step 6: Commit**

```bash
git add .gitignore Config/Local.xcconfig.example scripts/config.sh README.md
git commit -m "chore: scaffold repo, config contract, and README skeleton"
```

---

### Task 2: PayLink parsing (local Swift package, TDD)

**Files:**
- Create: `Packages/PayLinkCore/Package.swift`
- Create: `Packages/PayLinkCore/Sources/PayLinkCore/PayLink.swift`
- Create: `Packages/PayLinkCore/Tests/PayLinkCoreTests/PayLinkTests.swift`

**Interfaces:**
- Produces: `public struct PayLink: Equatable { public let numericID: String; public let variantID: String }` where `variantID == "gid://shopify/ProductVariant/" + numericID`.
- Produces: `public static func parse(_ url: URL) throws -> PayLink` throwing `PayLink.ParseError` (`notHTTPS`, `wrongPath`, `missingVariant`, `invalidVariant`).

- [ ] **Step 1: Write `Package.swift`**

```swift
// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "PayLinkCore",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "PayLinkCore", targets: ["PayLinkCore"])
    ],
    targets: [
        .target(name: "PayLinkCore"),
        .testTarget(name: "PayLinkCoreTests", dependencies: ["PayLinkCore"])
    ]
)
```

- [ ] **Step 2: Write the failing tests**

```swift
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
```

- [ ] **Step 3: Run tests to verify they fail**

Run: `swift test --package-path Packages/PayLinkCore 2>&1 | tail -5`
Expected: build error, `cannot find 'PayLink' in scope`

- [ ] **Step 4: Write `PayLink.swift`**

```swift
import Foundation

/// The parsed form of an App Clip invocation URL: `https://<domain>/pay/?v=<numeric variant id>`.
public struct PayLink: Equatable {
    public static let gidPrefix = "gid://shopify/ProductVariant/"

    /// Numeric Shopify product variant ID as it appears in the admin URL.
    public let numericID: String

    /// Storefront GID accepted by `AcceleratedCheckoutButtons(variantID:quantity:)`.
    public var variantID: String { Self.gidPrefix + numericID }

    public enum ParseError: Error, Equatable {
        case notHTTPS
        case wrongPath
        case missingVariant
        case invalidVariant
    }

    public init(numericID: String) {
        self.numericID = numericID
    }

    public static func parse(_ url: URL) throws -> PayLink {
        guard url.scheme?.lowercased() == "https" else { throw ParseError.notHTTPS }

        let acceptedPaths: Set<String> = ["/pay", "/pay/", "/pay/index.html"]
        guard acceptedPaths.contains(url.path) else { throw ParseError.wrongPath }

        let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
        guard let raw = items.first(where: { $0.name == "v" })?.value, !raw.isEmpty else {
            throw ParseError.missingVariant
        }
        guard raw.allSatisfy({ $0.isASCII && $0.isNumber }) else { throw ParseError.invalidVariant }
        return PayLink(numericID: raw)
    }
}
```

Note on `%2012`: `URLComponents.queryItems` percent-decodes to `" 12"`, which contains a space and fails the digit check. `-5` fails on `-`. `1 2` fails on the space.

- [ ] **Step 5: Run tests to verify they pass**

Run: `swift test --package-path Packages/PayLinkCore 2>&1 | tail -3`
Expected: `Executed 7 tests, with 0 failures`

- [ ] **Step 6: Commit**

```bash
git add Packages/PayLinkCore
git commit -m "feat(core): parse App Clip invocation URL into a variant GID"
```

---

### Task 3: Launch state and Storefront variant lookup (TDD)

**Files:**
- Create: `Packages/PayLinkCore/Sources/PayLinkCore/LaunchState.swift`
- Create: `Packages/PayLinkCore/Sources/PayLinkCore/VariantLookup.swift`
- Create: `Packages/PayLinkCore/Tests/PayLinkCoreTests/LaunchStateTests.swift`
- Create: `Packages/PayLinkCore/Tests/PayLinkCoreTests/VariantLookupTests.swift`

**Interfaces:**
- Consumes: `PayLink`, `PayLink.ParseError` from Task 2.
- Produces: `public enum LaunchState: Equatable { case waiting; case ready(PayLink); case failed(String) }` with `public static func from(invocationURL: URL?) -> LaunchState`.
- Produces: `public struct VariantSummary: Equatable { title, variantTitle: String?, amount: Decimal, currencyCode: String, imageURL: URL? }` with `public func formattedPrice(locale: Locale = .current) -> String`.
- Produces: `public enum VariantLookup` with
  - `public static let query: String`
  - `public static func request(domain: String, apiVersion: String, token: String, variantID: String) -> URLRequest`
  - `public static func decode(_ data: Data) throws -> VariantSummary` throwing `VariantLookup.LookupError` (`notFound`, `graphQL([String])`, `malformed`)
  - `public static func fetch(domain: String, apiVersion: String, token: String, variantID: String) async throws -> VariantSummary`

- [ ] **Step 1: Write the failing LaunchState tests**

```swift
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
```

- [ ] **Step 2: Write the failing VariantLookup tests**

```swift
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
```

- [ ] **Step 3: Run tests to verify they fail**

Run: `swift test --package-path Packages/PayLinkCore 2>&1 | grep -E "error:|Executed" | head -5`
Expected: compile errors `cannot find 'LaunchState'`, `cannot find 'VariantLookup'`

- [ ] **Step 4: Write `LaunchState.swift`**

```swift
import Foundation

/// What the root view should show, derived purely from the invocation URL.
public enum LaunchState: Equatable {
    case waiting
    case ready(PayLink)
    case failed(String)

    public static func from(invocationURL: URL?) -> LaunchState {
        guard let url = invocationURL else { return .waiting }
        do {
            return .ready(try PayLink.parse(url))
        } catch let error as PayLink.ParseError {
            return .failed(message(for: error, url: url))
        } catch {
            return .failed("Could not read the link: \(error)")
        }
    }

    private static func message(for error: PayLink.ParseError, url: URL) -> String {
        switch error {
        case .notHTTPS:        return "This link is not secure (not https): \(url.absoluteString)"
        case .wrongPath:       return "This link is not a payment link: \(url.path)"
        case .missingVariant:  return "This payment link has no item (missing ?v=)."
        case .invalidVariant:  return "This payment link has an invalid item id."
        }
    }
}
```

- [ ] **Step 5: Write `VariantLookup.swift`**

```swift
import Foundation

public struct VariantSummary: Equatable {
    public let title: String
    public let variantTitle: String?
    public let amount: Decimal
    public let currencyCode: String
    public let imageURL: URL?

    public init(title: String, variantTitle: String?, amount: Decimal, currencyCode: String, imageURL: URL?) {
        self.title = title
        self.variantTitle = variantTitle
        self.amount = amount
        self.currencyCode = currencyCode
        self.imageURL = imageURL
    }

    public func formattedPrice(locale: Locale = .current) -> String {
        let f = NumberFormatter()
        f.locale = locale
        f.numberStyle = .currency
        f.currencyCode = currencyCode
        return f.string(from: amount as NSDecimalNumber) ?? "\(amount) \(currencyCode)"
    }
}

/// Minimal Storefront API client for one query. No SDK dependency so it is testable on macOS.
public enum VariantLookup {
    public enum LookupError: Error, Equatable {
        case notFound
        case graphQL([String])
        case malformed
    }

    public static let query = """
    query VariantSummary($id: ID!) {
      node(id: $id) {
        ... on ProductVariant {
          title
          price { amount currencyCode }
          image { url }
          product { title }
        }
      }
    }
    """

    public static func request(domain: String, apiVersion: String, token: String, variantID: String) -> URLRequest {
        var req = URLRequest(url: URL(string: "https://\(domain)/api/\(apiVersion)/graphql.json")!)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue(token, forHTTPHeaderField: "X-Shopify-Storefront-Access-Token")
        let body: [String: Any] = ["query": query, "variables": ["id": variantID]]
        req.httpBody = try? JSONSerialization.data(withJSONObject: body)
        return req
    }

    // Wire shape of the response. Kept private; callers get VariantSummary.
    private struct Envelope: Decodable {
        struct Err: Decodable { let message: String }
        struct Data: Decodable { let node: Node? }
        struct Node: Decodable {
            struct Price: Decodable { let amount: String; let currencyCode: String }
            struct Image: Decodable { let url: String }
            struct Product: Decodable { let title: String }
            let title: String
            let price: Price
            let image: Image?
            let product: Product
        }
        let data: Data?
        let errors: [Err]?
    }

    public static func decode(_ data: Data) throws -> VariantSummary {
        let envelope: Envelope
        do {
            envelope = try JSONDecoder().decode(Envelope.self, from: data)
        } catch {
            throw LookupError.malformed
        }
        if let errors = envelope.errors, !errors.isEmpty {
            throw LookupError.graphQL(errors.map(\.message))
        }
        guard let node = envelope.data?.node else { throw LookupError.notFound }
        guard let amount = Decimal(string: node.price.amount) else { throw LookupError.malformed }
        return VariantSummary(
            title: node.product.title,
            variantTitle: node.title,
            amount: amount,
            currencyCode: node.price.currencyCode,
            imageURL: node.image.flatMap { URL(string: $0.url) }
        )
    }

    public static func fetch(domain: String, apiVersion: String, token: String, variantID: String) async throws -> VariantSummary {
        let req = request(domain: domain, apiVersion: apiVersion, token: token, variantID: variantID)
        let (data, _) = try await URLSession.shared.data(for: req)
        return try decode(data)
    }
}
```

- [ ] **Step 6: Run tests to verify they pass**

Run: `swift test --package-path Packages/PayLinkCore 2>&1 | tail -3`
Expected: `Executed 17 tests, with 0 failures`

- [ ] **Step 7: Commit**

```bash
git add Packages/PayLinkCore
git commit -m "feat(core): launch state and Storefront variant lookup"
```

---

### Task 4: Xcode project with parent app and App Clip

**Files:**
- Create: `project.yml`
- Create: `App/PayDemoApp.swift`
- Create: `Clip/PayClipApp.swift`
- Create: `Clip/ClipConfig.swift`
- Create: `Clip/RootView.swift`
- Create: `Clip/PayView.swift`

**Interfaces:**
- Consumes: `PayLink`, `LaunchState`, `VariantSummary`, `VariantLookup` from Tasks 2–3; `Config/Local.xcconfig` keys from Task 1.
- Consumes from SDK (verified against checkout-sheet-kit-swift 3.9.2 source): `ShopifyAcceleratedCheckouts.Configuration(storefrontDomain:storefrontAccessToken:customer:)` (ObservableObject), `ShopifyAcceleratedCheckouts.ApplePayConfiguration(merchantIdentifier:contactFields:)` with `contactFields: [RequiredContactFields]` (`.email`, `.phone`), `AcceleratedCheckoutButtons(variantID: String, quantity: Int)`, modifiers `.wallets([Wallet])`, `.onComplete((CheckoutCompletedEvent) -> Void)`, `.onFail((CheckoutError) -> Void)`, `.onCancel(() -> Void)`, `.cornerRadius(CGFloat)`. `CheckoutCompletedEvent.orderDetails.id: String`.
- Produces: Xcode project `PayClipDemo.xcodeproj` with schemes `PayDemo` and `PayClip`; Info.plist keys `STOREFRONT_DOMAIN`, `STOREFRONT_ACCESS_TOKEN`, `STOREFRONT_API_VERSION`, `APPLE_PAY_MERCHANT_ID` in the clip.

- [ ] **Step 1: Write `project.yml`**

```yaml
name: PayClipDemo
options:
  deploymentTarget:
    iOS: "17.0"
  createIntermediateGroups: true
configFiles:
  Debug: Config/Local.xcconfig
  Release: Config/Local.xcconfig
packages:
  CheckoutSheetKit:
    url: https://github.com/Shopify/checkout-sheet-kit-swift
    from: 3.9.2
  PayLinkCore:
    path: Packages/PayLinkCore
settings:
  base:
    DEVELOPMENT_TEAM: $(DEVELOPMENT_TEAM)
    CODE_SIGN_STYLE: Automatic
    SWIFT_VERSION: "5.10"
    TARGETED_DEVICE_FAMILY: "1"
targets:
  PayDemo:
    type: application
    platform: iOS
    sources: [App]
    dependencies:
      - target: PayClip
    settings:
      base:
        PRODUCT_BUNDLE_IDENTIFIER: $(APP_BUNDLE_ID)
        GENERATE_INFOPLIST_FILE: YES
        INFOPLIST_KEY_UILaunchScreen_Generation: YES
        INFOPLIST_KEY_CFBundleDisplayName: Pay Demo
    entitlements:
      path: App/PayDemo.entitlements
      properties:
        com.apple.developer.associated-domains:
          - applinks:$(CLIP_DOMAIN)
    scheme:
      testTargets: []
  PayClip:
    type: application.on-demand-install-capable
    platform: iOS
    sources: [Clip]
    dependencies:
      - package: CheckoutSheetKit
        product: ShopifyAcceleratedCheckouts
      - package: PayLinkCore
        product: PayLinkCore
    info:
      path: Clip/Info.plist
      properties:
        CFBundleDisplayName: Pay
        UILaunchScreen: {}
        UISupportedInterfaceOrientations: [UIInterfaceOrientationPortrait]
        NSAppClip:
          NSAppClipRequestEphemeralUserNotification: false
          NSAppClipRequestLocationConfirmation: false
        STOREFRONT_DOMAIN: $(STOREFRONT_DOMAIN)
        STOREFRONT_ACCESS_TOKEN: $(STOREFRONT_ACCESS_TOKEN)
        STOREFRONT_API_VERSION: $(STOREFRONT_API_VERSION)
        APPLE_PAY_MERCHANT_ID: $(APPLE_PAY_MERCHANT_ID)
    settings:
      base:
        PRODUCT_BUNDLE_IDENTIFIER: $(APP_BUNDLE_ID).Clip
    entitlements:
      path: Clip/PayClip.entitlements
      properties:
        com.apple.developer.associated-domains:
          - appclips:$(CLIP_DOMAIN)
        com.apple.developer.parent-application-identifiers:
          - $(AppIdentifierPrefix)$(APP_BUNDLE_ID)
        com.apple.developer.in-app-payments:
          - $(APPLE_PAY_MERCHANT_ID)
    scheme:
      testTargets: []
      environmentVariables:
        _XCAppClipURL: https://$(CLIP_DOMAIN)/pay/?v=$(DEMO_VARIANT_ID)
```

Xcode substitutes `$(VAR)` build settings inside entitlements, Info.plist, and scheme environment variables, so the xcconfig is the single source of truth.

- [ ] **Step 2: Write `App/PayDemoApp.swift`**

```swift
import SwiftUI

@main
struct PayDemoApp: App {
    var body: some Scene {
        WindowGroup {
            VStack(spacing: 12) {
                Text("Pay Demo").font(.title.bold())
                Text("This app only exists to carry the App Clip. Open a payment link from Messages to see the clip.")
                    .multilineTextAlignment(.center)
            }
            .padding()
        }
    }
}
```

- [ ] **Step 3: Write `Clip/ClipConfig.swift`**

```swift
import Foundation

/// Parameters injected from Config/Local.xcconfig through Info.plist (see project.yml).
enum ClipConfig {
    static let storefrontDomain = value("STOREFRONT_DOMAIN")
    static let storefrontAccessToken = value("STOREFRONT_ACCESS_TOKEN")
    static let storefrontAPIVersion = value("STOREFRONT_API_VERSION")
    static let merchantID = value("APPLE_PAY_MERCHANT_ID")

    private static func value(_ key: String) -> String {
        guard let v = Bundle.main.object(forInfoDictionaryKey: key) as? String, !v.isEmpty else {
            fatalError("\(key) is missing from Info.plist. Fill it in Config/Local.xcconfig and run `xcodegen generate`.")
        }
        return v
    }
}
```

- [ ] **Step 4: Write `Clip/PayClipApp.swift`**

```swift
import SwiftUI
import ShopifyAcceleratedCheckouts
import PayLinkCore

@main
struct PayClipApp: App {
    @State private var state: LaunchState = .waiting

    @StateObject private var configuration = ShopifyAcceleratedCheckouts.Configuration(
        storefrontDomain: ClipConfig.storefrontDomain,
        storefrontAccessToken: ClipConfig.storefrontAccessToken
    )
    @StateObject private var applePay = ShopifyAcceleratedCheckouts.ApplePayConfiguration(
        merchantIdentifier: ClipConfig.merchantID,
        contactFields: [.email]
    )

    init() {
        ShopifyAcceleratedCheckouts.logLevel = .all
    }

    var body: some Scene {
        WindowGroup {
            RootView(state: state)
                .environmentObject(configuration)
                .environmentObject(applePay)
                .onContinueUserActivity(NSUserActivityTypeBrowsingWeb) { activity in
                    state = LaunchState.from(invocationURL: activity.webpageURL)
                }
        }
    }
}
```

Both `Configuration` and `ApplePayConfiguration` are `ObservableObject` classes in 3.9.2, so `@StateObject` and `.environmentObject` are correct.

- [ ] **Step 5: Write `Clip/RootView.swift`**

```swift
import SwiftUI
import PayLinkCore

struct RootView: View {
    let state: LaunchState

    var body: some View {
        switch state {
        case .waiting:
            VStack(spacing: 8) {
                ProgressView()
                Text("Waiting for a payment link…").foregroundStyle(.secondary)
            }
        case .failed(let message):
            VStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle").font(.largeTitle)
                Text(message).multilineTextAlignment(.center)
            }
            .padding()
        case .ready(let link):
            PayView(link: link)
        }
    }
}
```

- [ ] **Step 6: Write `Clip/PayView.swift`**

```swift
import SwiftUI
import ShopifyAcceleratedCheckouts
import PayLinkCore

struct PayView: View {
    let link: PayLink

    private enum Status: Equatable {
        case ready
        case done(orderID: String)
        case failed(String)
    }

    @State private var variant: VariantSummary?
    @State private var loadError: String?
    @State private var status: Status = .ready

    var body: some View {
        VStack(spacing: 24) {
            Spacer(minLength: 0)
            productSection
            paymentSection
            Spacer(minLength: 0)
        }
        .padding(24)
        .task { await loadVariant() }
    }

    @ViewBuilder private var productSection: some View {
        if let variant {
            AsyncImage(url: variant.imageURL) { image in
                image.resizable().scaledToFit()
            } placeholder: {
                Color.clear
            }
            .frame(height: 160)
            Text(variant.title).font(.title2.bold()).multilineTextAlignment(.center)
            Text(variant.formattedPrice()).font(.title3)
        } else if let loadError {
            Text(loadError).font(.footnote).foregroundStyle(.secondary).multilineTextAlignment(.center)
        } else {
            ProgressView()
        }
    }

    @ViewBuilder private var paymentSection: some View {
        switch status {
        case .ready:
            AcceleratedCheckoutButtons(variantID: link.variantID, quantity: 1)
                .wallets([.applePay])
                .cornerRadius(12)
                .onComplete { event in status = .done(orderID: event.orderDetails.id) }
                .onFail { error in status = .failed(String(describing: error)) }
                .onCancel { status = .ready }
                .frame(height: 56)
        case .done(let orderID):
            Label("Order placed", systemImage: "checkmark.circle.fill")
                .font(.title2.bold()).foregroundStyle(.green)
            Text(orderID).font(.footnote).foregroundStyle(.secondary)
        case .failed(let message):
            Text("Payment failed: \(message)").font(.footnote).multilineTextAlignment(.center)
            Button("Try again") { status = .ready }.buttonStyle(.borderedProminent)
        }
    }

    private func loadVariant() async {
        do {
            variant = try await VariantLookup.fetch(
                domain: ClipConfig.storefrontDomain,
                apiVersion: ClipConfig.storefrontAPIVersion,
                token: ClipConfig.storefrontAccessToken,
                variantID: link.variantID
            )
        } catch VariantLookup.LookupError.notFound {
            loadError = "Product unavailable. You can still try to pay."     // Review Focus 3
        } catch VariantLookup.LookupError.graphQL(let messages) {
            loadError = "Storefront error: " + messages.joined(separator: "; ") // Review Focus 4
        } catch {
            loadError = "Could not load product: \(error.localizedDescription)"
        }
    }
}
```

- [ ] **Step 7: Generate and build for the simulator**

```bash
xcodegen generate
xcodebuild -project PayClipDemo.xcodeproj -scheme PayClip \
  -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO -quiet build && echo BUILD_OK
xcodebuild -project PayClipDemo.xcodeproj -scheme PayDemo \
  -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO -quiet build && echo BUILD_OK
```

Expected: `BUILD_OK` twice. First run resolves the Shopify package from GitHub (about a minute).

- [ ] **Step 8: Verify the generated artifacts carry the parameters**

```bash
grep -A1 "parent-application-identifiers" Clip/PayClip.entitlements
grep -c "AppClips" PayClipDemo.xcodeproj/project.pbxproj
grep -B1 -A1 "_XCAppClipURL" PayClipDemo.xcodeproj/xcshareddata/xcschemes/PayClip.xcscheme
```

Expected: the entitlement contains `$(AppIdentifierPrefix)$(APP_BUNDLE_ID)`; the pbxproj mentions `AppClips` at least once (embed phase); the scheme contains the `_XCAppClipURL` variable.

- [ ] **Step 9: Run the clip in the simulator and confirm the "waiting" and "failed" states**

Open `PayClipDemo.xcodeproj`, select the `PayClip` scheme and an iPhone simulator, run. Because `DEMO_VARIANT_ID` is still `0` in Local.xcconfig, the URL is `…/pay/?v=0`, which parses, so the screen shows "Storefront error: …" or "Could not load product" plus the Apple Pay button (Apple Pay is unavailable in the simulator, so the SDK may hide the button; that is fine here). Then edit the scheme, uncheck `_XCAppClipURL`, run again, and confirm "Waiting for a payment link…" is shown (Review Focus 5).

- [ ] **Step 10: Commit**

```bash
git add project.yml App Clip
git commit -m "feat(ios): parent app and App Clip with Shopify Apple Pay button"
```

---

### Task 5: Website, AASA, and GitHub Pages deployment

**Files:**
- Create: `site-src/apple-app-site-association.tmpl`
- Create: `site-src/pay.html.tmpl`
- Create: `scripts/render_site.sh`
- Create: `scripts/make_preview.py`
- Create: `scripts/check_aasa.sh`
- Create: `site/.nojekyll`, `site/index.html`
- Create: `.github/workflows/pages.yml`
- Modify: `README.md` (add "Website" section)

**Interfaces:**
- Consumes: `scripts/config.sh` keys `DEVELOPMENT_TEAM`, `APP_BUNDLE_ID`, `CLIP_DOMAIN`, `APP_STORE_ID`.
- Produces: `https://$CLIP_DOMAIN/.well-known/apple-app-site-association` and `https://$CLIP_DOMAIN/pay/?v=…` live on GitHub Pages.

- [ ] **Step 1: Write the AASA template**

`site-src/apple-app-site-association.tmpl`:

```json
{
  "appclips": {
    "apps": ["__TEAM_ID__.__APP_BUNDLE_ID__.Clip"]
  },
  "applinks": {
    "details": [
      {
        "appIDs": ["__TEAM_ID__.__APP_BUNDLE_ID__"],
        "components": [{ "/": "/pay/*" }]
      }
    ]
  }
}
```

- [ ] **Step 2: Write the landing page template**

`site-src/pay.html.tmpl`:

```html
<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <meta name="apple-itunes-app" content="app-id=__APP_STORE_ID__, app-clip-bundle-id=__APP_BUNDLE_ID__.Clip, app-clip-display=card">
  <meta property="og:title" content="Pay with Apple Pay">
  <meta property="og:description" content="Tap to pay in seconds.">
  <meta property="og:image" content="https://__CLIP_DOMAIN__/preview.png">
  <title>Pay</title>
  <style>
    body { font-family: -apple-system, system-ui, sans-serif; margin: 0; padding: 32px 16px; text-align: center; }
    .muted { color: #666; }
  </style>
</head>
<body>
  <h1>Pay</h1>
  <p id="item" class="muted"></p>
  <p>Open this link on an iPhone running iOS 17 or later to pay with Apple Pay.</p>
  <p class="muted">If no App Clip card appeared, this page is the fallback (spec FR2).</p>
  <script>
    var v = new URLSearchParams(location.search).get('v');
    document.getElementById('item').textContent = v ? 'Item ' + v : 'No item specified.';
  </script>
</body>
</html>
```

- [ ] **Step 3: Write `scripts/render_site.sh`**

```bash
#!/usr/bin/env bash
# Renders site-src/*.tmpl into site/ using values from Config/Local.xcconfig.
set -euo pipefail
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$root/scripts/config.sh"

render() {
  sed -e "s|__TEAM_ID__|$DEVELOPMENT_TEAM|g" \
      -e "s|__APP_BUNDLE_ID__|$APP_BUNDLE_ID|g" \
      -e "s|__CLIP_DOMAIN__|$CLIP_DOMAIN|g" \
      -e "s|__APP_STORE_ID__|$APP_STORE_ID|g" "$1"
}

mkdir -p "$root/site/.well-known" "$root/site/pay"
render "$root/site-src/apple-app-site-association.tmpl" > "$root/site/.well-known/apple-app-site-association"
render "$root/site-src/pay.html.tmpl" > "$root/site/pay/index.html"
python3 -I "$root/scripts/make_preview.py" "$root/site/preview.png"
echo "Rendered site/ for $CLIP_DOMAIN (team $DEVELOPMENT_TEAM, bundle $APP_BUNDLE_ID, app id $APP_STORE_ID)"
```

- [ ] **Step 4: Write `scripts/make_preview.py`** (solid-color 1200×630 PNG, standard library only)

```python
#!/usr/bin/env python3
"""Write a 1200x630 solid PNG for og:image. Usage: make_preview.py out.png"""
import struct, sys, zlib

W, H = 1200, 630
R, G, B = 0x1E, 0x7A, 0xFF  # blue

def chunk(tag: bytes, data: bytes) -> bytes:
    body = tag + data
    return struct.pack(">I", len(data)) + body + struct.pack(">I", zlib.crc32(body) & 0xFFFFFFFF)

row = b"\x00" + bytes([R, G, B]) * W
raw = row * H
png = (b"\x89PNG\r\n\x1a\n"
       + chunk(b"IHDR", struct.pack(">IIBBBBB", W, H, 8, 2, 0, 0, 0))
       + chunk(b"IDAT", zlib.compress(raw, 9))
       + chunk(b"IEND", b""))
with open(sys.argv[1], "wb") as f:
    f.write(png)
```

- [ ] **Step 5: Write `scripts/check_aasa.sh`**

```bash
#!/usr/bin/env bash
# Checks the AASA file directly and through Apple's CDN (what iOS actually reads).
set -euo pipefail
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$root/scripts/config.sh"
echo "== direct: https://$CLIP_DOMAIN/.well-known/apple-app-site-association"
curl -sS -o /tmp/aasa.direct -w "status=%{http_code} content-type=%{content_type} redirects=%{num_redirects}\n" \
  "https://$CLIP_DOMAIN/.well-known/apple-app-site-association"
python3 -I -c 'import json,sys; d=json.load(open("/tmp/aasa.direct")); print("appclips:", d["appclips"]["apps"])'
echo "== apple cdn: https://app-site-association.cdn-apple.com/a/v1/$CLIP_DOMAIN"
curl -sS -w "\nstatus=%{http_code}\n" "https://app-site-association.cdn-apple.com/a/v1/$CLIP_DOMAIN" | head -c 800; echo
echo "== landing page meta"
curl -sS "https://$CLIP_DOMAIN/pay/?v=1" | grep -o '<meta name="apple-itunes-app"[^>]*>'
```

- [ ] **Step 6: Write static site files and the Pages workflow**

`site/.nojekyll`: empty file (so GitHub Pages publishes the `.well-known` directory).

`site/index.html`:

```html
<!doctype html>
<html lang="en"><head><meta charset="utf-8"><title>Pay Clip Demo</title></head>
<body><p>Pay Clip demo host. Payment links look like <code>/pay/?v=&lt;variant&gt;</code>.</p></body></html>
```

`.github/workflows/pages.yml`:

```yaml
name: pages
on:
  push:
    branches: [main]
    paths: ["site/**", ".github/workflows/pages.yml"]
  workflow_dispatch:
permissions:
  contents: read
  pages: write
  id-token: write
concurrency:
  group: pages
  cancel-in-progress: true
jobs:
  deploy:
    runs-on: ubuntu-latest
    environment:
      name: github-pages
      url: ${{ steps.deployment.outputs.page_url }}
    steps:
      - uses: actions/checkout@v4
      - uses: actions/upload-pages-artifact@v3
        with:
          path: site
      - id: deployment
        uses: actions/deploy-pages@v4
```

- [ ] **Step 7: Render locally and verify**

```bash
chmod +x scripts/render_site.sh scripts/check_aasa.sh
scripts/render_site.sh
cat site/.well-known/apple-app-site-association
grep apple-itunes-app site/pay/index.html
file site/preview.png
```

Expected: AASA shows `ABCDE12345.com.example.payclipdemo.Clip` (the example values until Task 6 fills real ones); meta tag shows `app-id=0, app-clip-bundle-id=com.example.payclipdemo.Clip, app-clip-display=card`; `file` reports `PNG image data, 1200 x 630`.

- [ ] **Step 8: Create the GitHub repository and enable Pages from Actions**

```bash
source scripts/config.sh
gh repo create "$(gh api user -q .login)/shopify-appclip-pay" --public --source=. --remote=origin --push
gh api -X POST "repos/{owner}/{repo}/pages" -f build_type=workflow
gh workflow run pages.yml
sleep 90
gh run list --workflow=pages.yml --limit 1
```

Expected: last line shows `completed  success`. The site is at `https://<login>.github.io/shopify-appclip-pay/` unless a custom domain is attached.

**Important path note:** GitHub project sites live under `/<repo>/`, so `CLIP_DOMAIN` alone is not enough. Choose one of:
- (a) Use a *user site* repo named `<login>.github.io` so paths are at the root (matches `/pay/*` in the AASA and `/pay/` in `PayLink`), or
- (b) attach a custom domain to this repo (Settings → Pages → Custom domain), set `CLIP_DOMAIN` to it, which also puts `/pay/` at the root.

Pick (a) if no custom domain is at hand: create the repo as `<login>.github.io` instead of `shopify-appclip-pay` in the command above, and set `CLIP_DOMAIN = <login>.github.io`. Do not try to support a `/<repo>/pay/` prefix; the spec fixes the URL shape.

- [ ] **Step 9: Verify the live site**

```bash
scripts/check_aasa.sh
```

Expected: direct status `200`, `appclips: ['ABCDE12345.com.example.payclipdemo.Clip']`; Apple CDN status `200` with the same JSON (the CDN may take up to a few minutes after first deploy; retry). Record the direct `content-type` value in README: if it is not `application/json`, note it; Apple's CDN result is what matters (spec R5). If the CDN returns 404 or an error after 15 minutes, switch hosting to Cloudflare Pages with a `_headers` file setting `Content-Type: application/json` for `/.well-known/apple-app-site-association`, and update `CLIP_DOMAIN`.

- [ ] **Step 10: Update README and commit**

Append to README under a new `## Website` heading:

```markdown
## Website

`site/` is generated from `site-src/` by `scripts/render_site.sh` and deployed by `.github/workflows/pages.yml`.
After changing any key in `Config/Local.xcconfig`, run `scripts/render_site.sh`, commit `site/`, push, then `scripts/check_aasa.sh`.
Observed direct Content-Type on GitHub Pages: <fill in>. Apple CDN status: <fill in>.
```

Replace both `<fill in>` with the values observed in Step 9.

```bash
git add site-src site scripts/render_site.sh scripts/make_preview.py scripts/check_aasa.sh .github README.md
git commit -m "feat(site): AASA, landing page, and GitHub Pages deployment"
git push
```

---

### Task 6: Apple side: identifiers, merchant ID, App Store Connect record

**Files:**
- Modify: `Config/Local.xcconfig` (real `DEVELOPMENT_TEAM`, `APP_BUNDLE_ID`, `APPLE_PAY_MERCHANT_ID`, `APP_STORE_ID`)
- Modify: `site/` (re-rendered)
- Modify: `README.md` (add "Apple setup" section)

**Interfaces:**
- Produces: a registered App ID for `$APP_BUNDLE_ID` and `$APP_BUNDLE_ID.Clip`, a merchant ID `$APPLE_PAY_MERCHANT_ID`, and an App Store Connect app record whose numeric Apple ID is `$APP_STORE_ID`.

- [ ] **Step 1: Pick final identifiers and write them to Local.xcconfig**

Edit `Config/Local.xcconfig`: set `DEVELOPMENT_TEAM` to the 10-character team ID from https://developer.apple.com/account (Membership details), `APP_BUNDLE_ID` to a reverse-DNS id you own (for example `com.<yourname>.payclipdemo`), `APPLE_PAY_MERCHANT_ID` to `merchant.` + the same reverse-DNS id. Verify:

```bash
bash -c 'source scripts/config.sh && echo "$DEVELOPMENT_TEAM $APP_BUNDLE_ID $APPLE_PAY_MERCHANT_ID"'
```

Expected: three real values, none equal to the example values.

- [ ] **Step 2: Create the merchant ID**

In https://developer.apple.com/account/resources/identifiers/list/merchant click **+**, choose **Merchant IDs**, enter description `Pay Clip Demo` and identifier exactly `$APPLE_PAY_MERCHANT_ID`. Register.

- [ ] **Step 3: Let Xcode register the App IDs with capabilities**

```bash
xcodegen generate
open PayClipDemo.xcodeproj
```

In Xcode, select the `PayClip` target → Signing & Capabilities: confirm automatic signing with your team shows no error, and that capabilities **Associated Domains**, **Apple Pay** (with the merchant ID ticked) and **App Clip** parent appear. Then select `PayDemo` → confirm Associated Domains. Build both schemes for **Any iOS Device**:

```bash
xcodebuild -project PayClipDemo.xcodeproj -scheme PayDemo -destination 'generic/platform=iOS' -quiet -allowProvisioningUpdates build && echo SIGNED_BUILD_OK
```

Expected: `SIGNED_BUILD_OK`. If Xcode reports the merchant ID is not in the App ID, open https://developer.apple.com/account/resources/identifiers → the `.Clip` App ID → Apple Pay → Configure → tick the merchant ID → Save, then rebuild.

- [ ] **Step 4: Create the App Store Connect app record**

In https://appstoreconnect.apple.com/apps click **+** → New App: platform iOS, name `Pay Clip Demo` (names must be unique; add a suffix if taken), primary language English (U.S.), bundle ID `$APP_BUNDLE_ID`, SKU `payclipdemo`. After creation open **App Information** → General and copy the numeric **Apple ID**.

- [ ] **Step 5: Write APP_STORE_ID, re-render and redeploy the site**

Set `APP_STORE_ID = <numeric id>` in `Config/Local.xcconfig`, then:

```bash
scripts/render_site.sh
git add site && git commit -m "chore(site): real team, bundle, and App Store IDs" && git push
sleep 90 && scripts/check_aasa.sh
```

Expected: AASA now lists `<TEAM>.<bundle>.Clip` through the Apple CDN; the meta tag shows the numeric `app-id`.

- [ ] **Step 6: Document and commit**

Append to README:

```markdown
## Apple setup

- Team ID, bundle ID, merchant ID and App Store Apple ID live in `Config/Local.xcconfig`.
- Merchant ID is created at developer.apple.com → Identifiers → Merchant IDs.
- Xcode automatic signing registers both App IDs; the clip's App ID must list the merchant ID under Apple Pay.
- The App Store Connect record is needed before any device test because the landing page's `app-id` meta value comes from it.
- The Apple Pay *Payment Processing* certificate is created in Task 7 because its CSR comes from Shopify.
```

```bash
git add README.md && git commit -m "docs: Apple identifier setup" && git push
```

---

### Task 7: Shopify side: sandbox store, scopes, token, certificate

**Files:**
- Create: `scripts/apple_pay_cert.sh`
- Modify: `Config/Local.xcconfig` (`STOREFRONT_DOMAIN`, `STOREFRONT_ACCESS_TOKEN`, `DEMO_VARIANT_ID`)
- Modify: `README.md` (add "Shopify setup" section)

**Interfaces:**
- Consumes: `$APPLE_PAY_MERCHANT_ID` from Task 6.
- Produces: a store in Shopify Payments test mode with Apple Pay enabled, one published variant `$DEMO_VARIANT_ID`, a Storefront token `$STOREFRONT_ACCESS_TOKEN` with `write_cart_wallet_payments`, and an active Apple Pay payment processing certificate on the store.
- Environment for the script (not stored in xcconfig): `ADMIN_API_ACCESS_TOKEN`.

- [ ] **Step 1: Create the trial store and enable test mode with Apple Pay**

1. At https://www.shopify.com/free-trial start a trial; country **United States**. When asked to pick a plan, choose the cheapest paid plan (a paid plan is required for Shopify Payments test mode, spec F6). No real orders will ever be placed.
2. Settings → Payments → Shopify Payments → **Complete account setup** with the business details (needed before test mode is offered in the US).
3. Settings → Payments → Shopify Payments → Manage → **Test mode** → Enable test mode → Save.
4. Same page → **Wallets** → tick **Apple Pay** → Save.
5. Settings → Checkout: leave defaults. Settings → Shipping: nothing needed because the product is digital.

Verification: the Payments page shows "Test mode enabled" and Apple Pay listed under wallets.

- [ ] **Step 2: Create the demo product**

Products → Add product: title `Demo Pass`, price `5.00`, untick **This is a physical product** (digital, no shipping, spec D5), tick **Charge tax** off, status **Active**, Sales channels: all (including the Headless channel after Step 3). Save. Open the product's variant (Default Title) and copy the numeric id from the URL `…/variants/<id>`. Put it in `Config/Local.xcconfig` as `DEMO_VARIANT_ID`.

- [ ] **Step 3: Request the gated scopes**

Fill the Shopify form at https://www.appsheet.com/start/1ff317b6-2da1-4f39-b041-c01cfada6098 once, requesting all three scopes for this store: `write_cart_wallet_payments` (Storefront, needed by Accelerated Checkouts), plus `write_mobile_payments` and `read_mobile_payments` (Admin, needed to create the Apple Pay certificate). State the use case as "native iOS Apple Pay via Checkout Kit Accelerated Checkouts, proof of concept". Approval is manual and can take days (spec R6); continue with Step 4 while waiting, and finish Steps 5–7 after approval.

- [ ] **Step 4: Create the custom app and the Storefront token**

1. https://dev.shopify.com/dashboard → Apps → **Create app** → name `Pay Clip Demo`. Under Access → Storefront API scopes tick `unauthenticated_read_product_listings`, `unauthenticated_read_checkouts`, `unauthenticated_write_checkouts`, `unauthenticated_read_product_inventory`. Under Admin API scopes tick nothing yet.
2. Install the app on the trial store (Versions → Release, then Install on the store).
3. In the store admin → Settings → Apps → the app → API credentials: copy the **Storefront API access token** into `Config/Local.xcconfig` as `STOREFRONT_ACCESS_TOKEN`, and the store's `*.myshopify.com` host as `STOREFRONT_DOMAIN`.
4. Make sure the product is available to this app's sales channel (Products → Demo Pass → Sales channels → tick the app).

Verify the token and the product with the same query the clip uses:

```bash
source scripts/config.sh
curl -sS "https://$STOREFRONT_DOMAIN/api/$STOREFRONT_API_VERSION/graphql.json" \
  -H "Content-Type: application/json" -H "X-Shopify-Storefront-Access-Token: $STOREFRONT_ACCESS_TOKEN" \
  -d "{\"query\":\"{ node(id: \\\"gid://shopify/ProductVariant/$DEMO_VARIANT_ID\\\") { ... on ProductVariant { title price { amount currencyCode } product { title } } } }\"}"
```

Expected: `{"data":{"node":{"title":"Default Title","price":{"amount":"5.0","currencyCode":"USD"},"product":{"title":"Demo Pass"}}}}`. A `node: null` means the product is not published to the app's channel; an `errors` array means the token or scopes are wrong.

- [ ] **Step 5: After approval, add the gated scopes**

In the Dev Dashboard app → Access: add Storefront scope `write_cart_wallet_payments` and Admin scopes `read_mobile_payments`, `write_mobile_payments`. Release a new version and re-install on the store. Copy the **Admin API access token** (shown once) and keep it only in your shell:

```bash
export ADMIN_API_ACCESS_TOKEN=shpat_...
```

- [ ] **Step 6: Write `scripts/apple_pay_cert.sh`**

```bash
#!/usr/bin/env bash
# Apple Pay payment processing certificate exchange between Shopify and Apple.
# Follows https://shopify.dev/docs/storefronts/mobile/create-apple-payment-processing-certificates
#
# Usage:
#   export ADMIN_API_ACCESS_TOKEN=shpat_...
#   scripts/apple_pay_cert.sh create              # prints the certificate id
#   scripts/apple_pay_cert.sh csr <id>            # writes apple_payment_processing.csr
#   scripts/apple_pay_cert.sh upload <id> apple_pay.cer
#   scripts/apple_pay_cert.sh status <id>
set -euo pipefail
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$root/scripts/config.sh"
: "${ADMIN_API_ACCESS_TOKEN:?export ADMIN_API_ACCESS_TOKEN first}"

api="https://$STOREFRONT_DOMAIN/admin/api/$STOREFRONT_API_VERSION"
hdr=(-H "X-Shopify-Access-Token: $ADMIN_API_ACCESS_TOKEN" -H "Content-Type: application/json")

case "${1:-}" in
  create)
    curl -sS -X POST "$api/apple_pay_certificates.json" "${hdr[@]}" -d '{"apple_pay_certificate":{}}' \
      | python3 -I -c 'import json,sys; c=json.load(sys.stdin)["apple_pay_certificate"]; print(c["id"], c["status"])'
    ;;
  status)
    curl -sS "$api/apple_pay_certificates/${2:?id}.json" "${hdr[@]}" \
      | python3 -I -c 'import json,sys; c=json.load(sys.stdin)["apple_pay_certificate"]; print(c["id"], c["status"], c.get("merchant_id"))'
    ;;
  csr)
    curl -sS "$api/apple_pay_certificates/${2:?id}/csr.json" "${hdr[@]}" \
      | python3 -I -c 'import json,sys,base64; k=json.load(sys.stdin)["csr"]["key"]; sys.stdout.buffer.write(base64.b64decode(k))' \
      > apple_payment_processing.csr
    echo "wrote apple_payment_processing.csr ($(wc -c < apple_payment_processing.csr) bytes)"
    ;;
  upload)
    id="${2:?id}"; cer="${3:?apple_pay.cer}"
    encoded="$(base64 < "$cer" | tr -d '\n')"
    python3 -I - "$id" "$APPLE_PAY_MERCHANT_ID" "$encoded" <<'PY' > /tmp/apple_pay_upload.json
import json, sys
cid, merchant, enc = sys.argv[1:4]
print(json.dumps({"apple_pay_certificate": {"id": int(cid), "status": "completed",
                  "merchant_id": merchant, "encoded_signed_certificate": enc}}))
PY
    curl -sS -X PUT "$api/apple_pay_certificates/$id.json" "${hdr[@]}" -d @/tmp/apple_pay_upload.json \
      | python3 -I -c 'import json,sys; c=json.load(sys.stdin)["apple_pay_certificate"]; print(c["id"], c["status"], c["merchant_id"])'
    rm -f /tmp/apple_pay_upload.json
    ;;
  *)
    sed -n '2,10p' "$0"; exit 1 ;;
esac
```

- [ ] **Step 7: Run the certificate exchange**

```bash
chmod +x scripts/apple_pay_cert.sh
scripts/apple_pay_cert.sh create          # note the id, e.g. "123456 pending" or "123456 csr"
scripts/apple_pay_cert.sh status 123456   # repeat until the second word is "csr"
scripts/apple_pay_cert.sh csr 123456
```

Then in https://developer.apple.com/account/resources/certificates/add choose **Apple Pay Payment Processing Certificate** (not Merchant Identity), select the merchant ID `$APPLE_PAY_MERCHANT_ID`, upload `apple_payment_processing.csr`, download `apple_pay.cer`. Then:

```bash
scripts/apple_pay_cert.sh upload 123456 ~/Downloads/apple_pay.cer
scripts/apple_pay_cert.sh status 123456
```

Expected: `123456 completed merchant.com.<yourname>.payclipdemo`. On the Apple certificate page, the first certificate is active by default; do not click Activate on later ones before uploading (F5 guide warning).

- [ ] **Step 8: Verify Apple Pay in the store's web checkout (spec V1)**

On the test iPhone, in Safari, open `https://$STOREFRONT_DOMAIN/products/demo-pass`, tap Buy it now. The checkout must offer an Apple Pay button at the top. Complete it with a real card on the device: test mode means no charge (F6). In the admin, Orders shows the order with a **Test** badge. Cancel/archive it.

If Apple Pay does not appear: re-check Step 1.4 and that the device has a card in Wallet.

- [ ] **Step 9: Document and commit**

Append to README:

```markdown
## Shopify setup

1. US trial store, cheapest paid plan, Shopify Payments account completed, **test mode on**, Apple Pay ticked under Wallets.
2. Product "Demo Pass", digital, 5.00 USD, published to the custom app's channel. Variant id → `DEMO_VARIANT_ID`.
3. Custom app in the Dev Dashboard. Storefront token → `STOREFRONT_ACCESS_TOKEN`. Gated scopes
   (`write_cart_wallet_payments`, `read/write_mobile_payments`) requested via Shopify's form; added after approval.
4. Apple Pay payment processing certificate: `scripts/apple_pay_cert.sh create|csr|upload|status` with
   `ADMIN_API_ACCESS_TOKEN` exported. Never commit `.csr`/`.cer` files.
5. Web checkout on the phone shows Apple Pay and creates a Test order.
```

```bash
git add scripts/apple_pay_cert.sh README.md
git commit -m "feat(shopify): Apple Pay certificate exchange script and store setup notes"
git push
```

---

### Task 8: Device demos, Mode A and Mode B

**Files:**
- Modify: `README.md` (add "Running the demo" section with observed results)

**Interfaces:**
- Consumes: everything from Tasks 4–7. `Config/Local.xcconfig` fully filled.
- Produces: a recorded, repeatable Mode A and Mode B demo.

- [ ] **Step 1: Regenerate with real parameters and run Mode A on the device**

```bash
xcodegen generate
bash -c 'source scripts/config.sh && echo "_XCAppClipURL should be https://$CLIP_DOMAIN/pay/?v=$DEMO_VARIANT_ID"'
```

Open the project in Xcode, scheme `PayClip`, destination: the physical iPhone (iOS 17+, a card in Wallet, signed into the same Apple ID that will test Messages). Run.

Expected on the phone: the clip shows "Demo Pass", "$5.00", and a black Apple Pay button, within about 3 seconds of launch on Wi-Fi (spec NFR3; note the observed time in README). Tap it → Apple Pay sheet shows "Demo Pass", total $5.00, email requested if not on file → authorize → screen changes to "Order placed" with an order id. In the Shopify admin, Orders shows a new **Test** order paid via Apple Pay.

If the sheet opens then closes immediately: the merchant ID is missing from the clip's App ID or the entitlement (Task 6 Step 3). If `onFail` fires with a cart or payment error, run `scripts/apple_pay_cert.sh status <id>` and confirm `completed`; also confirm the `write_cart_wallet_payments` scope was added to the released app version (Task 7 Step 5). The Xcode console has the SDK's full log because `logLevel = .all`.

- [ ] **Step 2: Check the two edge states on the device (Review Focus 3 and 5)**

1. Edit the scheme's `_XCAppClipURL` to `https://<CLIP_DOMAIN>/pay/?v=1` (a variant that does not exist). Run. Expected: "Product unavailable. You can still try to pay." and the Apple Pay button. Tapping it should end in the "Payment failed" state with a Shopify error, not a crash. Restore the real value.
2. Uncheck `_XCAppClipURL`, run. Expected: "Waiting for a payment link…". Re-check it.

- [ ] **Step 3: Register a Local Experience for Mode B**

On the iPhone: Settings → Developer → **Local Experiences** → Register Local Experience:
- URL prefix: `https://<CLIP_DOMAIN>/pay/`
- Bundle ID: `<APP_BUNDLE_ID>.Clip`
- Title: `Demo Pass`, Subtitle: `Pay $5 with Apple Pay`, Action: `Open`
- Photo: any image.
Save. The clip must already be on the device from Step 1 (Apple: build and run first so it is cached).

- [ ] **Step 4: Send the link from a contact and launch from Messages**

From another iPhone or a Mac whose Messages account is saved as a contact on the test iPhone, send an iMessage containing exactly `https://<CLIP_DOMAIN>/pay/?v=<DEMO_VARIANT_ID>`.

Expected on the test iPhone: the message renders as a rich link; tapping it shows the App Clip card with the local experience title and "Open"; Open launches the clip which shows the product and the Apple Pay button; paying creates another Test order. This is Mode B and proves FR2–FR8 without the App Store.

If only a plain link preview appears and tapping opens Safari: confirm the sender is in Contacts, the Local Experience URL prefix matches, and the clip is cached (run it from Xcode once more). If the card appears but the clip shows "Waiting for a payment link…", the user activity did not carry the URL; check that the invocation URL starts with the registered prefix.

- [ ] **Step 5: Record results in README and commit**

Append to README:

```markdown
## Running the demo

### Mode A (Xcode)
Run scheme `PayClip` on the phone. `_XCAppClipURL` = `https://<domain>/pay/?v=<variant>`.
Observed: <date> order #<n> created in test mode.

### Mode B (Local Experience + iMessage)
Settings → Developer → Local Experiences → prefix `https://<domain>/pay/`, bundle `<bundle>.Clip`.
Send the link from a contact. Observed: <date> App Clip card shown, order #<n> created.
```

Fill the `<…>` fields with the real observations, then:

```bash
git add README.md && git commit -m "docs: Mode A and Mode B demo results" && git push
```

---

### Task 9: Mode C: App Store release and Infobip send

**Files:**
- Create: `scripts/send_mfb_appclip.sh`
- Modify: `README.md` (add "Mode C" results)

**Interfaces:**
- Consumes: `$CLIP_DOMAIN`, `$DEMO_VARIANT_ID` from `scripts/config.sh`.
- Environment for the script (never in git): `INFOBIP_BASE_URL` (for example `jdxdv9.api.infobip.com`), `INFOBIP_API_KEY`, `MFB_BUSINESS_ID` (the `sender` UUID), `MFB_USER_URN` (the `urn:mbid:…` of the test iPhone's conversation).

- [ ] **Step 1: Write `scripts/send_mfb_appclip.sh`**

```bash
#!/usr/bin/env bash
# Sends the App Clip link through Infobip's Apple Messages for Business API.
# Usage: INFOBIP_BASE_URL=xxx.api.infobip.com INFOBIP_API_KEY=... MFB_BUSINESS_ID=... MFB_USER_URN=urn:mbid:... \
#        scripts/send_mfb_appclip.sh [variant-id]
set -euo pipefail
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$root/scripts/config.sh"
: "${INFOBIP_BASE_URL:?}" "${INFOBIP_API_KEY:?}" "${MFB_BUSINESS_ID:?}" "${MFB_USER_URN:?}"
variant="${1:-$DEMO_VARIANT_ID}"
url="https://$CLIP_DOMAIN/pay/?v=$variant"

payload="$(python3 -I - "$MFB_BUSINESS_ID" "$MFB_USER_URN" "$url" <<'PY'
import json, sys
sender, to, url = sys.argv[1:4]
print(json.dumps({"messages": [{"sender": sender, "destinations": [{"to": to}],
                                 "content": {"url": url, "type": "APP_CLIP"}}]}))
PY
)"
echo "Sending $url"
curl -sS -X POST "https://$INFOBIP_BASE_URL/apple-mfb/1/messages" \
  -H "Authorization: App $INFOBIP_API_KEY" -H "Content-Type: application/json" -H "Accept: application/json" \
  -d "$payload" -w "\nstatus=%{http_code}\n"
```

- [ ] **Step 2: Dry-run the script against Infobip before the App Store release**

```bash
chmod +x scripts/send_mfb_appclip.sh
export INFOBIP_BASE_URL=... INFOBIP_API_KEY=... MFB_BUSINESS_ID=... MFB_USER_URN=...
scripts/send_mfb_appclip.sh
```

Expected: `status=200` and a JSON body with a message id. On the test iPhone the MfB conversation receives the link. Before release it will render as a rich link or plain link, not an App Clip card; that is expected (spec F2, F3). Record what was received.

- [ ] **Step 3: Archive and upload the app with its App Clip**

In Xcode: scheme `PayDemo`, destination **Any iOS Device**, Product → Archive → Distribute App → App Store Connect → Upload (automatic signing). Wait for processing (email from App Store Connect).

Then check the App Clip size budget (spec NFR2): in App Store Connect → the build → **App Clip** shows the thinned size; it must be under 100 MB and should be under 30 MB. If it is larger, the Shopify package is pulling in more than expected; check `Clip` target → Build Phases → Link Binary With Libraries lists only `ShopifyAcceleratedCheckouts` and `PayLinkCore`.

- [ ] **Step 4: Configure the default App Clip experience and submit**

In App Store Connect → the app → the 1.0 version:
1. Fill the required metadata minimally: screenshots for one iPhone size (take them from Mode A), description `Proof of concept App Clip for paying with Apple Pay.`, keywords `pay`, support URL `https://<CLIP_DOMAIN>/`, privacy policy URL `https://<CLIP_DOMAIN>/` (the page states no data is collected), category Utilities, age rating questionnaire, App Privacy: "Data Not Collected".
2. Select the processed build.
3. **App Clip** section → Default App Clip Experience: header image 1800×1200 PNG (export `site/preview.png` scaled with `sips -z 1200 1800 site/preview.png --out /tmp/appclip-header.png`), subtitle `Pay $5 with Apple Pay`, action **Open**.
4. Review notes: "App Clip proof of concept. Invocation URL: https://<CLIP_DOMAIN>/pay/?v=<DEMO_VARIANT_ID>. Payments run in Shopify test mode; no charges."
5. Submit for review. Release: manual.

Expected: status **Waiting for Review** → **Ready for Sale** after approval; then click Release. Review of a near-empty app may be questioned (spec R3); if rejected for minimum functionality, reply that the App Clip is the product and the parent app is required by platform rules, and resubmit.

- [ ] **Step 5: Verify the released configuration on the phone**

Remove the Local Experience (Settings → Developer → Local Experiences → delete) and clear the experience cache (Settings → Developer → Clear Experience Cache). Then Settings → Developer → **Diagnostics** (App Clips Testing) → enter `https://<CLIP_DOMAIN>/pay/`. Expected: "Published on the App Store" and "Associated" checks pass.

- [ ] **Step 6: Send the real MfB message and complete the purchase**

```bash
scripts/send_mfb_appclip.sh
```

Expected on the test iPhone, in the Messages for Business conversation: an App Clip card (icon, name, Open). Tap Open → clip shows Demo Pass and the Apple Pay button → pay → "Order placed" → Test order in Shopify admin. This is the full proof (spec US1–US4).

If Infobip returns an error such as the URL "does not support App Clips", re-run `scripts/check_aasa.sh` and confirm the landing page meta tag has the real `app-id`; the App Clip must be live in the US App Store (Apple `storeRegion` default). If the card is replaced by a plain link in MfB although Mode B worked, record it as the answer to spec R4.

- [ ] **Step 7: Record results and commit**

Append to README:

```markdown
### Mode C (App Store + Infobip)
`scripts/send_mfb_appclip.sh` with `INFOBIP_*` and `MFB_*` exported. App Store version 1.0 released <date>.
Observed: <App Clip card shown / plain link>, order #<n> created in test mode.
```

```bash
git add scripts/send_mfb_appclip.sh README.md
git commit -m "feat(mfb): Infobip App Clip send script and Mode C results"
git push
```
