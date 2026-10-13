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
