import Foundation
import StoreKit
import os

extension StoreKitTheKit {
    
    // MARK: - Purchasing
    
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
    
    public func elementWasPurchased (element: Purchasable) -> Bool {
        
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
    
    func restorePurchases () async {
        do {
            try await AppStore.sync()
            Logger.store.addLog("Purchases were synced")
        } catch {
            Logger.store.addLog("Something went wrong while syncing purchases \(error)")
        }
    }
    
    // MARK: - Formatting
    
    public func getPriceFormatted(for purchasable: Purchasable) -> String? {
        guard let product = getPurchasableProduct(id: purchasable.bundleId) else {
            Logger.store.addLog("Product coulnd't be found")
            return nil
        }
        return product.displayPrice
    }
    
    public func getTotalPrice(for purchasables: [Purchasable]) -> String? {
        let totalPrice = purchasables.compactMap {
            getPurchasableProduct(id: $0.bundleId)?.price
        }.reduce(0, +)
        guard let item = getPurchasableProduct(id: purchasables[0].bundleId) else {
            return nil
        }
        return item.priceFormatStyle.format(totalPrice)
    }
    
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
