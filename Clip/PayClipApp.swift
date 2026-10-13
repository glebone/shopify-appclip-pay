import SwiftUI
import ShopifyCheckoutSheetKit
import PayLinkCore

@main
struct PayClipApp: App {
    @State private var state: LaunchState = PayClipApp.initialState()

    init() {
        ShopifyCheckoutSheetKit.configure { $0.preloading.enabled = false }
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
                .onContinueUserActivity(NSUserActivityTypeBrowsingWeb) { activity in
                    state = LaunchState.from(invocationURL: activity.webpageURL)
                }
        }
    }
}
