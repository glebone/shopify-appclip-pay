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
