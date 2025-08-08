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
        Logger.store.addLog("elementWasPurchased called for: \(element.bundleId) on thread: \(Thread.current.isMainThread ? "main" : "background")")
        
        // Ensure thread safety by executing on main thread, avoiding deadlock
        if Thread.isMainThread {
            // Already on main thread, execute directly
            return _elementWasPurchasedInternal(element: element)
        } else {
            // Switch to main thread for thread safety
            return DispatchQueue.main.sync {
                return _elementWasPurchasedInternal(element: element)
            }
        }
    }
    
    private func _elementWasPurchasedInternal(element: Purchasable) -> Bool {
        // Consumables are not "owned" - they're purchased and consumed
        // Apps should handle their own consumption logic
        if element.type == .consumable {
            Logger.store.addLog("Consumable \(element.bundleId) is never stored as purchase - returning false")
            return false
        }
        
        // Capture state values for logging
        let currentStoreState = storeState
        let storeEmpty = state.isEmpty()
        let isStoreCurrentlyAvailable = currentStoreState == .available && !storeEmpty
        Logger.store.addLog("Store check to validate purchase of \(element.bundleId): storeState=\(currentStoreState), isEmpty=\(storeEmpty), storeIsAvailable=\(isStoreCurrentlyAvailable)")
        
        // check whether purchase has been made / subscription is active
        if isStoreCurrentlyAvailable {
            let isPurchasedResult = state.isPurchased(productId: element.bundleId)
            Logger.store.addLog("Store available, \(element.bundleId) isPurchased: \(isPurchasedResult)")
            return isPurchasedResult
            
        // Fallback to keychain
        } else {
            Logger.store.addLog("Store unavailable, checking locally for \(element.bundleId)")
            switch element.type {
            case .nonConsumable:
                return isNonConsumablePurchasedLocally(element: element)
            case .autoRenewableSubscription, .nonRenewableSubscription:
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
            // For non-renewable subscriptions, we need to double-check expiration even if in purchasedProducts
            if element.type == .nonRenewableSubscription {
                return LocalStoreManager.shared.isSubscriptionActive(for: element.bundleId)
            } else {
                // For auto-renewable subscriptions, being in purchasedProducts means it's active
                return state.isPurchased(productId: element.bundleId)
            }
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
