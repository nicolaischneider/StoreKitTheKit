import Foundation
import StoreKit
import os

extension StoreKitTheKit {
    
    // MARK: - Purchase List
    
    /**
     Checks if a specific item has been purchased by the user.
     
     This function verifies whether the user has purchased the specified item by checking against
     StoreKit's purchase records. If the store is unavailable, it falls back to local storage
     to check the purchase status.
     
     - Note: For consumable items, this always returns `false` since consumables are meant to be 
             purchased and consumed by the app. Apps should handle their own consumption logic.
     
     - Parameter element: The Purchasable item to check for purchase status
     - Returns: Boolean value indicating whether the item has been purchased (always false for consumables)
     */
    public func elementWasPurchased(element: Purchasable) -> Bool {
        // Consumables are not "owned" - they're purchased and consumed
        // Apps should handle their own consumption logic
        if element.type == .consumable {
            return false
        }
        
        // check whether purchase has been made / subscription is active
        if storeIsAvailable {
            return self.purchasedProducts.first(where: { $0.id == element.bundleId }) != nil
            
        // Fallback to keychain
        } else {
            switch element.type {
            case .nonConsumable:
                return isNonConsumablePurchasedLocally(element: element)
            case .autoRenewableSubscription:
                return isSubscriptionActiveLocally(element: element)
            case .consumable:
                return false // Consumables are never "owned"
            }
        }
    }
    
    private func isNonConsumablePurchasedLocally(element: Purchasable) -> Bool {
        Logger.store.addLog("Retrieving \(element.bundleId) from local storage instead of StoreKit due to inavailability.")
        let purchasedIds = LocalStoreManager.shared.getPurchasedProductIds()
        let available = purchasedIds.contains(element.bundleId)
        if available {
            Logger.store.addLog("product available: \(available)")
        }
        return available
    }
    
    private func isSubscriptionActiveLocally(element: Purchasable) -> Bool {
        if storeIsAvailable {
            // Check if subscription is in current purchased products (active subscriptions)
            return self.purchasedProducts.first(where: { $0.id == element.bundleId }) != nil
        } else {
            // Fallback to local storage for subscription validation
            Logger.store.addLog("Checking subscription \(element.bundleId) from local storage due to store unavailability.")
            return LocalStoreManager.shared.isSubscriptionActive(for: element.bundleId)
        }
    }
    
    // MARK: - Restore
    
    /**
     Restores previously purchased items for the current user.
     
     This function synchronizes with the App Store to restore any previously purchased items
     that might not be reflected in the current app state, helpful when users reinstall the app
     or switch to a new device.
     */
    public func restorePurchases() async {
        do {
            try await AppStore.sync()
            Logger.store.addLog("Purchases were synced")
        } catch {
            Logger.store.addLog("Something went wrong while syncing purchases \(error)")
        }
    }
}
