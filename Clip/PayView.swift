import SwiftUI
import ShopifyAcceleratedCheckouts
import PayLinkCore

struct PayView: View {
    let link: PayLink

    private enum Status: Equatable {
        case ready
        case done(orderID: String)
        case failed(String)
    }

    @State private var variant: VariantSummary?
    @State private var loadError: String?
    @State private var status: Status = .ready

    var body: some View {
        VStack(spacing: 24) {
            Spacer(minLength: 0)
            productSection
            paymentSection
            Spacer(minLength: 0)
        }
        .padding(24)
        .task { await loadVariant() }
    }

    @ViewBuilder private var productSection: some View {
        if let variant {
            AsyncImage(url: variant.imageURL) { image in
                image.resizable().scaledToFit()
            } placeholder: {
                Color.clear
            }
            .frame(height: 160)
            Text(variant.title).font(.title2.bold()).multilineTextAlignment(.center)
            Text(variant.formattedPrice()).font(.title3)
        } else if let loadError {
            Text(loadError).font(.footnote).foregroundStyle(.secondary).multilineTextAlignment(.center)
        } else {
            ProgressView()
        }
    }

    @ViewBuilder private var paymentSection: some View {
        switch status {
        case .ready:
            AcceleratedCheckoutButtons(variantID: link.variantID, quantity: 1)
                .wallets([.applePay])
                .cornerRadius(12)
                .onComplete { event in status = .done(orderID: event.orderDetails.id) }
                .onFail { error in status = .failed(String(describing: error)) }
                .onCancel { status = .ready }
                .frame(height: 56)
        case .done(let orderID):
            Label("Order placed", systemImage: "checkmark.circle.fill")
                .font(.title2.bold()).foregroundStyle(.green)
            Text(orderID).font(.footnote).foregroundStyle(.secondary)
        case .failed(let message):
            Text("Payment failed: \(message)").font(.footnote).multilineTextAlignment(.center)
            Button("Try again") { status = .ready }.buttonStyle(.borderedProminent)
        }
    }

    private func loadVariant() async {
        do {
            variant = try await VariantLookup.fetch(
                domain: ClipConfig.storefrontDomain,
                apiVersion: ClipConfig.storefrontAPIVersion,
                token: ClipConfig.storefrontAccessToken,
                variantID: link.variantID
            )
        } catch VariantLookup.LookupError.notFound {
            loadError = "Product unavailable. You can still try to pay."     // Review Focus 3
        } catch VariantLookup.LookupError.graphQL(let messages) {
            loadError = "Storefront error: " + messages.joined(separator: "; ") // Review Focus 4
        } catch {
            loadError = "Could not load product: \(error.localizedDescription)"
        }
    }
}
