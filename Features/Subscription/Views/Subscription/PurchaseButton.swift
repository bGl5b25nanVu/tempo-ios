import SwiftUI
import StoreKit

/// A button that initiates a purchase for a given product.
/// Handles loading state, success, and `.userCancelled` gracefully.
struct PurchaseButton: View {
    let product: Product
    @State private var isPurchasing = false
    @State private var purchaseError: String?
    @State private var showError = false

    var body: some View {
        Button {
            Task { await purchase() }
        } label: {
            HStack(spacing: 8) {
                if isPurchasing {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(0.8)
                }
                Text(buttonTitle)
                    .font(.headline)
                    .fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(isPurchasing ? Color.gray : Color.blue)
            .foregroundColor(.white)
            .cornerRadius(12)
        }
        .disabled(isPurchasing)
        .alert("Purchase Failed", isPresented: $showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(purchaseError ?? "An unknown error occurred.")
        }
    }

    private var buttonTitle: String {
        if isPurchasing {
            return "Purchasing..."
        }
        let price = product.displayPrice
        return "Subscribe for \(price)/month"
    }

    @MainActor
    private func purchase() async {
        isPurchasing = true
        purchaseError = nil

        do {
            let success = try await ProductStore.shared.purchase(product)
            if success {
                print("[PurchaseButton] Purchase succeeded for \(product.id)")
            }
            // user cancelled returns false, no error shown
        } catch StoreError.verificationFailed {
            purchaseError = "Transaction could not be verified. Please try again."
            showError = true
        } catch {
            purchaseError = error.localizedDescription
            showError = true
        }

        isPurchasing = false
    }
}