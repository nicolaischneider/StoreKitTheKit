import StoreKit
import Foundation
import os

// MARK: Public

extension StoreKitTheKit {
    
    // MARK: - Purchasing
    
    /**
     Purchases a specified item from the App Store.
     
     This function will attempt to purchase the provided item and handle the purchase flow.
     If the store connection is unavailable, it will try to reconnect before proceeding with the purchase.
     
     - Parameter element: The Purchasable item to be purchased
     - Returns: A PurchaseState enum indicating the result of the purchase attempt
     */
    public func purchaseElement(element: Purchasable) async -> PurchaseState {
        
        Logger.store.addLog("Purchasing item \(element.bundleId)...")
        
        // in case store not available try to restart that dum retard fuck
        if !storeIsAvailable {
            Logger.store.addLog("Store not available. Trying to reconnect.")
            await self.syncWithStore()
        }
        
        return await purchase(element)
    }
}

// MARK: Private

extension StoreKitTheKit {
    
    func purchase(_ element: Purchasable) async -> PurchaseState {
        
        guard let product = self.products.first(where: { $0.id == element.bundleId }) else {
            Logger.store.addLog("Purchasable item couldn't be found.")
            return .purchaseFailure(.productNotFound)
        }
                
        do {
            let result = try await product.purchase()
            switch result {
                
            // Purchase went through!
            case .success(let verified):
                
                // verify purchase
                guard let transaction = try? checkVerified(verified) else {
                    Logger.store.addLog("Purchase unverified")
                    return .purchaseFailure(.unverifiedPurchase)
                }
                Logger.store.addLog("Purchase verified: \(transaction)")
                
                // Update customer status
                await self.updateCustomerProductStatus()
                await transaction.finish()
                
                // Return purchase as completed
                Logger.store.addLog("Purchase completed")
                return .purchaseCompleted(element)
                
            case .userCancelled:
                Logger.store.addLog("User cancelled purchase")
                return .purchaseFailure(.userCancelled)
                
            case .pending:
                Logger.store.addLog("Purchase still pending")
                return .purchaseFailure(.pendingPurchase)
                
            @unknown default:
                Logger.store.addLog("Unknown purchase state")
                return .purchaseFailure(.unknownPurchaseState)
            }
        } catch {
            Logger.store.addLog("Failed to purchase product: \(error)")
            return .purchaseFailure(.purchaseError(error))
        }
    }
}

// App Store promotion
extension StoreKitTheKit: SKPaymentTransactionObserver {
    
    public func paymentQueue(_ queue: SKPaymentQueue, updatedTransactions transactions: [SKPaymentTransaction]) {
        return
    }
    
    public func paymentQueue(_ queue: SKPaymentQueue, shouldAddStorePayment payment: SKPayment, for product: SKProduct) -> Bool {
        guard let purchasable = purchasableManager.product(id: product.productIdentifier) else {
            Logger.store.addLog("Product couldn't be identified")
            return false
        }
        
        guard !elementWasPurchased(element: purchasable) else {
            Logger.store.addLog("Product already purchased")
            return false
        }
        
        Task {
            let _ = await purchaseElement(element: purchasable)
        }
        
        return true
    }
}
