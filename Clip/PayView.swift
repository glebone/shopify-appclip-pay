import SwiftUI
import ShopifyCheckoutSheetKit
import PayLinkCore

/// One screen: Shopify's checkout sheet opens as soon as the link is known. Apple Pay is a
/// button inside that sheet, served by Shopify as the web merchant, so the clip needs no
/// merchant ID, certificate, Storefront token, or custom app.
struct PayView: View {
    let link: PayLink

    private enum Status: Equatable {
        case idle
        case done(orderID: String)
        case failed(String)
    }

    @State private var sheetPresented = false
    @State private var status: Status = .idle

    private var checkoutURL: URL { link.checkoutURL(storeDomain: ClipConfig.storefrontDomain) }

    var body: some View {
        VStack(spacing: 16) {
            switch status {
            case .idle:
                Image(systemName: "creditcard").font(.largeTitle)
                Button("Pay") { sheetPresented = true }.buttonStyle(.borderedProminent)
            case .done(let orderID):
                Label("Order placed", systemImage: "checkmark.circle.fill")
                    .font(.title2.bold()).foregroundStyle(.green)
                Text(orderID).font(.footnote).foregroundStyle(.secondary)
            case .failed(let message):
                Text("Payment failed: \(message)").font(.footnote).multilineTextAlignment(.center)
                Button("Try again") { status = .idle; sheetPresented = true }.buttonStyle(.borderedProminent)
            }
        }
        .padding(24)
        .onAppear { sheetPresented = true }
        .sheet(isPresented: $sheetPresented) {
            CheckoutSheet(checkout: checkoutURL)
                .title("Checkout")
                .onCancel { sheetPresented = false }
                .onComplete { event in
                    status = .done(orderID: event.orderDetails.id)
                    sheetPresented = false
                }
                .onFail { error in
                    status = .failed(String(describing: error))
                    sheetPresented = false
                }
                .edgesIgnoringSafeArea(.all)
        }
    }
}
