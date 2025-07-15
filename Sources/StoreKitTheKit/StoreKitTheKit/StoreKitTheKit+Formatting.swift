import Foundation
import StoreKit
import os

extension StoreKitTheKit {
    
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
    
    /**
     Divides the price of a purchasable item by a given number and returns the formatted result.
     
     This function is useful for calculating proportional costs, such as the weekly cost
     of a yearly subscription or the monthly cost of an annual plan.
     
     - Parameters:
       - purchasable: The Purchasable item to get the price for
       - divisor: The number to divide the price by
     - Returns: A formatted price string representing the divided price, or nil if the product couldn't be found
     */
    public func getDividedPrice(for purchasable: Purchasable, dividedBy divisor: Int) -> String? {
        guard let product = getPurchasableProduct(id: purchasable.bundleId) else {
            Logger.store.addLog("Product couldn't be found")
            return nil
        }
        
        let dividedPrice = product.price / Decimal(divisor)
        return product.priceFormatStyle.format(dividedPrice)
    }
    
    /**
     Compares two subscription items and returns the percentage savings of the cheaper option.
     
     This function converts both subscriptions to their weekly cost equivalent and calculates
     the percentage savings when choosing the cheaper option.
     
     - Parameters:
       - subscription1: The first subscription item to compare
       - subscription2: The second subscription item to compare
     - Returns: A formatted percentage string representing the savings, or nil if either product couldn't be found
     */
    public func compareSubscriptionSavings(subscription1: SubscriptionItem, subscription2: SubscriptionItem) -> String? {
        guard let product1 = getPurchasableProduct(id: subscription1.purchasable.bundleId),
              let product2 = getPurchasableProduct(id: subscription2.purchasable.bundleId) else {
            Logger.store.addLog("One or both subscription products couldn't be found")
            return nil
        }
        
        // Convert both subscriptions to weekly cost
        let weeklyCost1 = product1.price / Decimal(subscription1.period.weeksPerPeriod)
        let weeklyCost2 = product2.price / Decimal(subscription2.period.weeksPerPeriod)
        
        // Calculate savings percentage (more expensive - cheaper) / more expensive * 100
        let (moreExpensive, cheaper) = weeklyCost1 > weeklyCost2 ? (weeklyCost1, weeklyCost2) : (weeklyCost2, weeklyCost1)
        
        guard moreExpensive > 0 else {
            Logger.store.addLog("Invalid subscription price found")
            return nil
        }
        
        let savingsPercentage = ((moreExpensive - cheaper) / moreExpensive) * 100
        let percentageDouble = NSDecimalNumber(decimal: savingsPercentage).doubleValue
        
        return String(format: "%.0f%%", percentageDouble)
    }
    
    /// Retrieves a purchasable product by its identifier.
    private func getPurchasableProduct (id: String) -> Product? {
        for product in self.products {
            if product.id == id {
                return product
            }
        }
        return nil
    }
}
