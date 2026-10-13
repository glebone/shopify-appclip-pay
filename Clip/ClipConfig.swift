import Foundation

/// Parameters injected from Config/Local.xcconfig through Info.plist (see project.yml).
enum ClipConfig {
    static let storefrontDomain = value("STOREFRONT_DOMAIN")

    private static func value(_ key: String) -> String {
        guard let v = Bundle.main.object(forInfoDictionaryKey: key) as? String, !v.isEmpty else {
            fatalError("\(key) is missing from Info.plist. Fill it in Config/Local.xcconfig and run `xcodegen generate`.")
        }
        return v
    }
}
