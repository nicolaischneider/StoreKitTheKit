import Foundation
import StoreKit

extension StoreKitTheKit {
    
    // MARK: - Purchase List
    
    /**
     Checks if a specific item has been purchased by the user.
     
     This function verifies whether the user has purchased the specified item by checking against
     StoreKit's purchase records. If the store is unavailable, it falls back to local storage
     to check the purchase status.
     
     - Parameter element: The Purchasable item to check for purchase status
     - Returns: Boolean value indicating whether the item has been purchased
     */
    public func elementWasPurchased(element: Purchasable) -> Bool {
        
        // check whether regular purchase has been made
        if storeIsAvailable {
            return self.purchasedProducts.first(where: { $0.id == element.bundleId }) != nil
        } else {
            // Fallback to keychain
            Logger.store.addLog("Retrieving \(element.bundleId) from local storage instead of StoreKit due to inavailability.")
            let purchasedIds = LocalStoreManager.shared.getPurchasedProductIds()
            let available = purchasedIds.contains(element.bundleId)
            if available {
                Logger.store.addLog("product available: \(available)")
            }
            return available
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
