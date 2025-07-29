import StoreKit
import Foundation
import os

typealias Transaction = StoreKit.Transaction

extension StoreKitTheKit {
    
    // request products
    @MainActor
    func requestProducts() async {
        let productIDs = Set(purchasableManager.allCases.map(\.bundleId))
        do {
            let newProducts = try await Product.products(for: productIDs)
            state.updateProducts(newProducts)
            storeState = !state.isEmpty() ? .available : .unavailable
        } catch {
            Logger.store.addLog("Failed to load products: \(error)")
            storeState = .unavailable
        }
    }
    
    func listenForTransactions() -> Task<Void, Error> {
        return Task.detached {
            // Iterate through any transactions which didn't come from a direct call to `purchase()`.
            for await result in Transaction.updates {
                do {
                    let transaction = try self.checkVerified(result)
                    
                    // Deliver products to the user.
                    await self.updateCustomerProductStatus()
                    
                    // Always finish a transaction
                    await transaction.finish()
                    
                } catch {
                    // StoreKit transaction failed verification, don't deliver content to user.
                    Logger.store.addLog("Transaction \(result) failed verification")
                    Task {
                        await MainActor.run {
                            self.storeState = .unavailable
                        }
                    }
                }
            }
        }
    }
    
    // Determine customer product state
    @MainActor
    func updateCustomerProductStatus() async {
        
        purchaseDataChangedAfterGettingBackOnline = false
        
        var purchased: [Product] = []
        var purchasedItemsIds: [String] = []
        var activeSubscriptions: [String: SubscriptionInfo] = [:]

        // Iterate through all of the user's purchased products.
        for await result in Transaction.currentEntitlements {
            
            do {
                // First check if the transaction is verified. If the transaction is not verified
                // we'll catch the `failedVerification` error.
                let transaction = try checkVerified(result)
                
                // Process the transaction based on product type
                let result = processTransaction(
                    transaction,
                    purchased: &purchased,
                    purchasedItemsIds: &purchasedItemsIds,
                    activeSubscriptions: &activeSubscriptions
                )
                
                if !result {
                    continue
                }
            } catch {
                Logger.store.addLog("Something went wrong while updating customer product status: \(error)", level: .error)
                storeState = .unavailable
            }
        }
        
        state.updatePurchasedProducts(purchased)
        
        if !purchasedProductsMatchLocallyStored(productIds: purchasedItemsIds) {
            LocalStoreManager.shared.storePurchasedProductIds(purchasedItemsIds)
            purchaseDataChangedAfterGettingBackOnline = true
        }
        
        // Store subscription data and notify of changes
        if !activeSubscriptions.isEmpty {
            let subscriptionData = StoredSubscriptionData(
                subscriptions: activeSubscriptions,
                lastUpdated: Date()
            )
            LocalStoreManager.shared.storeSubscriptionData(subscriptionData)
            purchaseDataChangedAfterGettingBackOnline = true
        }
        
        storeState = !state.isEmpty() ? .available : .unavailable
    }
    
    func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified:
            throw StoreError.purchaseNotVerifed
        case .verified(let safe):
            return safe
        }
    }
    
    // MARK: - Private Transaction Processing
    
    private func processTransaction(
        _ transaction: Transaction,
        purchased: inout [Product],
        purchasedItemsIds: inout [String],
        activeSubscriptions: inout [String: SubscriptionInfo]
    ) -> Bool {
        switch transaction.productType {
        case .nonConsumable:
            return processNonConsumableTransaction(
                transaction,
                purchased: &purchased,
                purchasedItemsIds: &purchasedItemsIds)
            
        case .autoRenewable:
            return processAutoRenewableSubscriptionTransaction(
                transaction,
                purchased: &purchased,
                purchasedItemsIds: &purchasedItemsIds,
                activeSubscriptions: &activeSubscriptions)
            
        case .nonRenewable:
            return processNonRenewableSubscriptionTransaction(
                transaction,
                purchased: &purchased,
                purchasedItemsIds: &purchasedItemsIds,
                activeSubscriptions: &activeSubscriptions)
            
        case .consumable:
            return processConsumableTransaction(transaction)
            
        default:
            return false
        }
    }
    
    private func processNonConsumableTransaction(
        _ transaction: Transaction,
        purchased: inout [Product],
        purchasedItemsIds: inout [String]
    ) -> Bool {
        if let purchasedItem = state.getProduct(withId: transaction.productID) {
            purchased.append(purchasedItem)
        }
        if purchasableManager.productIDExists(transaction.productID) {
            purchasedItemsIds.append(transaction.productID)
        }
        return true
    }
    
    private func processAutoRenewableSubscriptionTransaction(
        _ transaction: Transaction,
        purchased: inout [Product],
        purchasedItemsIds: inout [String],
        activeSubscriptions: inout [String: SubscriptionInfo]
    ) -> Bool {
        // Check if the product ID exists in PurchasableManager
        guard purchasableManager.productIDExists(transaction.productID) else {
            Logger.store.addLog("Product \(transaction.productID) not found in PurchasableManager")
            return false
        }
        
        // Create subscription info from transaction
        let subscriptionInfo = SubscriptionInfo(
            productID: transaction.productID,
            expirationDate: transaction.expirationDate ?? Date(),
            isActive: true,
            renewalDate: nil,
            gracePeriodExpirationDate: nil,
            subscriptionGroupID: transaction.subscriptionGroupID ?? ""
        )
        activeSubscriptions[transaction.productID] = subscriptionInfo
        
        // Add to purchased items if subscription is active
        if let purchasedItem = state.getProduct(withId: transaction.productID) {
            purchased.append(purchasedItem)
        }
        purchasedItemsIds.append(transaction.productID)
        return true
    }
    
    private func processNonRenewableSubscriptionTransaction(
        _ transaction: Transaction,
        purchased: inout [Product],
        purchasedItemsIds: inout [String],
        activeSubscriptions: inout [String: SubscriptionInfo]
    ) -> Bool {
        // Check if the product ID exists in PurchasableManager
        guard purchasableManager.productIDExists(transaction.productID) else {
            Logger.store.addLog("Product \(transaction.productID) not found in PurchasableManager")
            return false
        }
        
        // For non-renewable subscriptions, calculate expiration from purchase date + duration
        // StoreKit test environment may not set expirationDate correctly
        let purchaseDate = transaction.purchaseDate
        let expirationDate: Date
        
        if let transactionExpirationDate = transaction.expirationDate {
            // Use StoreKit's expiration date if available
            expirationDate = transactionExpirationDate
            Logger.store.addLog("Using StoreKit expiration date for \(transaction.productID): \(transactionExpirationDate)")
        } else {
            // Fallback: calculate expiration based on product duration (30 days for our test product)
            expirationDate = Calendar.current.date(byAdding: .day, value: 30, to: purchaseDate) ?? Date()
            Logger.store.addLog("Calculated expiration date for \(transaction.productID): \(expirationDate)")
        }
        
        let isStillActive = expirationDate > Date()
        Logger.store.addLog("Non-renewable subscription \(transaction.productID) - Active: \(isStillActive), Expires: \(expirationDate)")
        
        // Create subscription info from transaction
        let subscriptionInfo = SubscriptionInfo(
            productID: transaction.productID,
            expirationDate: expirationDate,
            isActive: isStillActive,
            renewalDate: nil,
            gracePeriodExpirationDate: nil,
            subscriptionGroupID: transaction.subscriptionGroupID ?? ""
        )
        activeSubscriptions[transaction.productID] = subscriptionInfo
        
        // Only add to purchased items if non-renewable subscription is still active
        if isStillActive {
            if let purchasedItem = state.getProduct(withId: transaction.productID) {
                purchased.append(purchasedItem)
            }
            purchasedItemsIds.append(transaction.productID)
        }
        return true
    }
    
    private func processConsumableTransaction(_ transaction: Transaction) -> Bool {
        // Consumables are processed but not tracked in purchased products
        // Apps handle their own consumption logic after successful purchase
        if purchasableManager.productIDExists(transaction.productID) {
            Logger.store.addLog("Consumable purchase processed: \(transaction.productID)")
        }
        return true
    }
}
