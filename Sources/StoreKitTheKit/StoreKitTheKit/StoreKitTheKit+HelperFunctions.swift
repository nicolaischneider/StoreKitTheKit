import Foundation
import StoreKit
import os

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
            await self.connectToStore()
        }
        
        return await purchase(element)
    }
    
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
    
    // MARK: - Formatting
    
    /**
     Returns the formatted price string for a purchasable item.
     
     This function retrieves the formatted price string for display purposes, including the
     appropriate currency symbol and formatting based on the user's locale.
     
     - Parameter purchasable: The Purchasable item to get the price for
     - Returns: A formatted price string, or nil if the product couldn't be found
     */
    public func getPriceFormatted(for purchasable: Purchasable) -> String? {
        guard let product = getPurchasableProduct(id: purchasable.bundleId) else {
            Logger.store.addLog("Product coulnd't be found")
            return nil
        }
        return product.displayPrice
    }
    
    /**
     Calculates and formats the total price for a collection of purchasable items.
     
     This function adds up the prices of all provided purchasable items and returns
     the sum as a formatted string in the user's local currency format.
     
     - Parameter purchasables: An array of Purchasable items to calculate the total price for
     - Returns: A formatted string representing the total price, or nil if any product couldn't be found
     */
    public func getTotalPrice(for purchasables: [Purchasable]) -> String? {
        let totalPrice = purchasables.compactMap {
            getPurchasableProduct(id: $0.bundleId)?.price
        }.reduce(0, +)
        guard let item = getPurchasableProduct(id: purchasables[0].bundleId) else {
            return nil
        }
        return item.priceFormatStyle.format(totalPrice)
    }
    
    /**
     Compares the price of a collection of purchasable items with a single comparison item.
     
     This function calculates both the absolute price difference and the percentage difference
     between the total price of an array of purchasable items and a single comparison item.
     Useful for showing savings when offering bundles or package deals.
     
     - Parameters:
       - purchasables: An array of Purchasable items to calculate the collective price for
       - comparisonItem: A single Purchasable item to compare against the collection
     - Returns: A tuple containing the formatted price difference and percentage difference strings,
               or nil if any products couldn't be found
     */
    public func comparePrice(for purchasables: [Purchasable], with comparisonItem: Purchasable) -> (differenceString: String?, percentageString: String?)? {
        // Calculate total price of all purchasables
        let totalPrice = purchasables.compactMap {
            getPurchasableProduct(id: $0.bundleId)?.price
        }.reduce(Decimal(0), +)
        
        // Get the comparison item price
        guard let comparisonProduct = getPurchasableProduct(id: comparisonItem.bundleId),
              let formatStyle = getPurchasableProduct(id: purchasables.first?.bundleId ?? "")?.priceFormatStyle else {
            return nil
        }
        
        let comparisonPrice = comparisonProduct.price
        let difference = totalPrice - comparisonPrice
        
        // Calculate the percentage (comparison price / total price)
        var percentage: Decimal
        if totalPrice > 0 {
            percentage = (comparisonPrice / totalPrice) * 100
            percentage = 100 - percentage
        } else {
            percentage = 0
        }
        
        // Format the values
        let differenceString = formatStyle.format(abs(difference))
        
        // Convert Decimal to Double for string formatting
        let percentageDouble = NSDecimalNumber(decimal: percentage).doubleValue
        let percentageString = String(format: "%.0f%%", percentageDouble)
        
        return (differenceString, percentageString)
    }
}
