import SwiftUI

/// A button that restores previously purchased products.
/// Shows a loading state during the restore operation.
struct RestoreButton: View {
    @State private var isRestoring = false
    @State private var restoreMessage: String?
    @State private var showMessage = false

    var body: some View {
        Button {
            Task { await restore() }
        } label: {
            HStack(spacing: 6) {
                if isRestoring {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .blue))
                        .scaleEffect(0.75)
                }
                Text(isRestoring ? "Restoring..." : "Restore Purchases")
                    .font(.subheadline)
                    .fontWeight(.medium)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 44)
            .foregroundColor(.blue)
        }
        .disabled(isRestoring)
        .alert("Restore Result", isPresented: $showMessage) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(restoreMessage ?? "")
        }
    }

    @MainActor
    private func restore() async {
        isRestoring = true
        restoreMessage = nil

        await ProductStore.shared.restorePurchases()

        // Give a moment for the UI to reflect updated entitlements
        try? await Task.sleep(nanoseconds: 500_000_000)

        let count = ProductStore.shared.purchasedProductIDs.count
        restoreMessage = count > 0
            ? "Restored \(count) product(s)."
            : "No previous purchases found."
        showMessage = true

        isRestoring = false
    }
}