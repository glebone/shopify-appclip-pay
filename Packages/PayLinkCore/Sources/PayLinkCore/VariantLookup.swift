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
