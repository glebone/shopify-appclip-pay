import Foundation

/// The parsed form of an App Clip invocation URL: `https://<domain>/pay/?v=<numeric variant id>`.
public struct PayLink: Hashable {
    public static let gidPrefix = "gid://shopify/ProductVariant/"

    /// Numeric Shopify product variant ID as it appears in the admin URL.
    public let numericID: String

    /// Storefront GID form of the variant id.
    public var variantID: String { Self.gidPrefix + numericID }

    /// Shopify cart permalink for one unit of the variant. The Checkout Sheet Kit accepts it as a
    /// checkout URL, so no Storefront token or custom app is needed.
    /// https://help.shopify.com/en/manual/products/details/cart-permalink
    public func checkoutURL(storeDomain: String) -> URL {
        URL(string: "https://\(storeDomain)/cart/\(numericID):1")!
    }

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
