import SwiftUI
import ShopifyAcceleratedCheckouts
import PayLinkCore

@main
struct PayClipApp: App {
    @State private var state: LaunchState = PayClipApp.initialState()

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

    /// Xcode turns `_XCAppClipURL` into the browsing user activity; a launch from `devicectl`
    /// passes the variable but no activity, so debug builds read it directly. Release: no-op.
    private static func initialState() -> LaunchState {
        #if DEBUG
        if let raw = ProcessInfo.processInfo.environment["_XCAppClipURL"], let url = URL(string: raw) {
            return LaunchState.from(invocationURL: url)
        }
        #endif
        return .waiting
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
