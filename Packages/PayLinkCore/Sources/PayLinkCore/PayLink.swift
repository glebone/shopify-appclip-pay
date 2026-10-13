import Foundation

/// The parsed form of an App Clip invocation URL: `https://<domain>/pay/?v=<numeric variant id>`.
public struct PayLink: Hashable {
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
