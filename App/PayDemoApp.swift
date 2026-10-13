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
