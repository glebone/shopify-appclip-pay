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
