import SwiftUI
import StoreKit

/// The paywall screen shown to users prompting subscription purchase.
/// Displays available products and a restore purchases option.
struct PaywallView: View {
    @StateObject private var productStore = ProductStore.shared
    @State private var isLoading = true

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 32) {
                    headerSection

                    if isLoading {
                        loadingSection
                    } else if productStore.products.isEmpty {
                        emptySection
                    } else {
                        productsSection
                    }

                    Divider()

                    restoreSection
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 40)
            }
            .background(Color(.systemGroupedBackground).ignoresSafeArea())
            .navigationTitle("Subscribe")
            .navigationBarTitleDisplayMode(.large)
        }
        .task {
            await loadProducts()
        }
    }

    // MARK: - Sections

    private var headerSection: some View {
        VStack(spacing: 12) {
            Image(systemName: "crown.fill")
                .font(.system(size: 48))
                .foregroundStyle(.yellow)

            Text("Unlock Tempo Pro")
                .font(.title)
                .fontWeight(.bold)

            Text("Get unlimited access to all premium features.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
    }

    private var loadingSection: some View {
        VStack {
            ProgressView()
            Text("Loading plans...")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.top, 8)
        }
    }

    private var emptySection: some View {
        VStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle")
                .font(.title)
                .foregroundColor(.orange)
            Text("No products available.")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
    }

    private var productsSection: some View {
        VStack(spacing: 16) {
            ForEach(productStore.products, id: \.id) { product in
                productCard(for: product)
            }
        }
    }

    private func productCard(for product: Product) -> some View {
        VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(product.displayName)
                        .font(.headline)
                    Text(product.displayDescription)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
                Text(product.displayPrice)
                    .font(.title3)
                    .fontWeight(.bold)
            }

            PurchaseButton(product: product)
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(16)
    }

    private var restoreSection: some View {
        VStack(spacing: 8) {
            RestoreButton()
            Text("Re-download your purchases.")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
    }

    // MARK: - Actions

    private func loadProducts() async {
        _ = await productStore.loadProducts()
        isLoading = false
    }
}

// MARK: - Preview

#Preview {
    PaywallView()
}