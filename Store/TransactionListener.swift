import Foundation
import StoreKit

/// Listens for all App Store transaction updates: purchases, renewals, and refunds.
/// Delegates verification and storage to ProductStore.shared.
@MainActor
final class TransactionListener {
    static let shared = TransactionListener()

    private var listenerTask: Task<Void, Error>?
    private var isListening = false

    private init() {}

    /// Start listening for transaction updates. Safe to call multiple times.
    func startListening() {
        guard !isListening else { return }
        isListening = true

        listenerTask = Task {
            await listenForTransactions()
        }
    }

    /// Stop listening for transaction updates.
    func stopListening() {
        isListening = false
        listenerTask?.cancel()
        listenerTask = nil
    }

    private func listenForTransactions() async {
        for await result in Transaction.updates {
            await handleTransactionUpdate(result)
        }
    }

    private func handleTransactionUpdate(_ result: VerificationResult<Transaction>) async {
        do {
            let transaction = try checkVerified(result)
            await ProductStore.shared.handleTransaction(transaction)
            await transaction.finish()
        } catch {
            print("[TransactionListener] Failed to verify transaction: \(error)")
        }
    }

    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified:
            throw StoreError.verificationFailed
        case .verified(let value):
            return value
        }
    }
}

// MARK: - ProductStore Transaction Handling Extension

extension ProductStore {
    /// Handle a verified transaction: update purchased products map.
    func handleTransaction(_ transaction: Transaction) async {
        if let revocationDate = transaction.revocationDate {
            // Product was refunded — remove from entitlements
            purchasedProductIDs.remove(transaction.productID)
            print("[ProductStore] Product \(transaction.productID) revoked at \(revocationDate)")
        } else {
            // Active product — add to entitlements
            purchasedProductIDs.insert(transaction.productID)
            print("[ProductStore] Product \(transaction.productID) purchased/entitled")
        }
    }
}