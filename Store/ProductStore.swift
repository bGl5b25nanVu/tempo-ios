import Foundation
import StoreKit

// MARK: - Product Tier

enum ProductTier: String, CaseIterable {
    case free
    case pro
    case team
}

// MARK: - Product Identifiers

enum ProductID {
    static let free = "product_free"
    static let pro = "product_pro"
    static let team = "product_team"

    static let all: Set<String> = [free, pro, team]
}

// MARK: - ProductStore

@MainActor
final class ProductStore: ObservableObject {
    static let shared = ProductStore()

    @Published private(set) var products: [Product] = []
    @Published private(set) var purchasedProductIDs: Set<String> = []

    private var updateListenerTask: Task<Void, Error>?

    private init() {
        updateListenerTask = Task {
            await observeTransactionUpdates()
        }
    }

    deinit {
        updateListenerTask?.cancel()
    }

    // MARK: - Load Products

    func loadProducts() async -> [Product] {
        do {
            let productIDs = Array(ProductID.all)
            let loadedProducts = try await Product.products(for: productIDs)
            self.products = loadedProducts.sorted { $0.id < $1.id }
            return products
        } catch {
            print("Failed to load products: \(error)")
            return []
        }
    }

    // MARK: - Purchase

    func purchase(_ product: Product) async throws -> Bool {
        let result = try await product.purchase()

        switch result {
        case .success(let verification):
            let transaction = try checkVerified(verification)
            await transaction.finish()
            await updatePurchasedProducts()
            return true

        case .userCancelled:
            return false

        case .pending:
            return false

        @unknown default:
            return false
        }
    }

    // MARK: - Transaction Updates

    func observeTransactionUpdates() async {
        for await result in Transaction.updates {
            do {
                let transaction = try checkVerified(result)
                await updatePurchasedProducts()
                await transaction.finish()
            } catch {
                print("Transaction verification failed: \(error)")
            }
        }
    }

    // MARK: - Restore Purchases

    func restorePurchases() async {
        do {
            try await AppStore.sync()
            await updatePurchasedProducts()
        } catch {
            print("Failed to restore purchases: \(error)")
        }
    }

    // MARK: - Helpers

    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified:
            throw StoreError.verificationFailed
        case .verified(let safe):
            return safe
        }
    }

    private func updatePurchasedProducts() async {
        var purchased: Set<String> = []

        for await result in Transaction.currentEntitlements {
            do {
                let transaction = try checkVerified(result)
                if transaction.revocationDate == nil {
                    purchased.insert(transaction.productID)
                }
            } catch {
                continue
            }
        }

        self.purchasedProductIDs = purchased
    }

    func isPurchased(_ tier: ProductTier) -> Bool {
        purchasedProductIDs.contains(ProductID(rawValue: tier.rawValue) ?? "")
    }
}

// MARK: - Store Error

enum StoreError: Error, LocalizedError {
    case verificationFailed

    var errorDescription: String? {
        switch self {
        case .verificationFailed:
            return "Transaction verification failed."
        }
    }
}
