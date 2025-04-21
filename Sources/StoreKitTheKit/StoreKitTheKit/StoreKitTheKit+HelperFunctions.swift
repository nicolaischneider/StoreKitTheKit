import Foundation
import StoreKit
import os

extension StoreKitTheKit {
    
    // MARK: - Purchasing
    
    func purchaseElement(element: Purchasable) async -> PurchaseState {
        
        // Logger.purchase.addLog("Purchasing item \(element.rawValue)...")
        
        // in case store not available try to restart that dum retard fuck
        if !storeIsAvailable {
            // Logger.purchase.addLog("Store not available. Trying to reconnect.")
            await self.connectToStore()
        }
        
        return await purchase(element)
    }
    
    // MARK: - Purchase List
    
    func elementWasPurchased (element: Purchasable) -> Bool {
        
        // check whether regular purchase has been made
        if storeIsAvailable {
            return self.purchasedProducts.first(where: { $0.id == element.rawValue }) != nil
        } else {
            // Fallback to keychain
           // Logger.purchase.addLog("Retrieving \(element.rawValue) from local storage instead of StoreKit due to inavailability.")
            let purchasedIds = LocalStoreManager.shared.getPurchasedProductIds()
            let available = purchasedIds.contains(element.rawValue)
            if available {
               //  Logger.purchase.addLog("product available: \(available)")
            }
            return available
        }
    }
    
    func userHasAccessTo (element: Purchasable) -> Bool {
        return elementWasPurchased(element: element)
    }
    
    // MARK: - Restore
    
    func restorePurchases () async {
        do {
            try await AppStore.sync()
            //Logger.purchase.addLog("Purchases were synced")
        } catch {
            //Logger.purchase.addLog("Something went wrong while syncing purchases")
        }
    }
    
    // MARK: - Formatting
    
    func getPriceFormatted(for purchasable: Purchasable) -> String? {
        guard let product = getPurchasableProduct(id: purchasable.rawValue) else {
            //Logger.purchase.addLog("Product coulnd't be found")
            return nil
        }
        return product.displayPrice
    }
    
    func getTotalPrice(for purchasables: [Purchasable]) -> String? {
        let totalPrice = purchasables.compactMap {
            getPurchasableProduct(id: $0.rawValue)?.price
        }.reduce(0, +)
        guard let item = getPurchasableProduct(id: purchasables[0].rawValue) else {
            return nil
        }
        return item.priceFormatStyle.format(totalPrice)
    }
    
    func comparePrice(for purchasables: [Purchasable], with comparisonItem: Purchasable) -> (differenceString: String?, percentageString: String?)? {
        // Calculate total price of all purchasables
        let totalPrice = purchasables.compactMap {
            getPurchasableProduct(id: $0.rawValue)?.price
        }.reduce(Decimal(0), +)
        
        // Get the comparison item price
        guard let comparisonProduct = getPurchasableProduct(id: comparisonItem.rawValue),
              let formatStyle = getPurchasableProduct(id: purchasables.first?.rawValue ?? "")?.priceFormatStyle else {
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
