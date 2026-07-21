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
            updateStoreState(!state.isEmpty() ? StoreAvailabilityState.available : StoreAvailabilityState.unavailable)
        } catch {
            Logger.store.addLog("Failed to load products: \(error)")
            updateStoreState(StoreAvailabilityState.unavailable)
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
                    self.updateStoreState(StoreAvailabilityState.unavailable)
                }
            }
        }
    }
    
    // Determine customer product state
    @MainActor
    func updateCustomerProductStatus() async {
        // Prevent concurrent executions of this method
        if state.isUpdatingCustomerStatus {
            Logger.store.addLog("Customer product status update already in progress, skipping...")
            return
        }
        
        state.setIsUpdatingCustomerStatus(true)
        defer { state.setIsUpdatingCustomerStatus(false) }
        
        updatePurchaseDataChanged(false)
        
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
                updateStoreState(StoreAvailabilityState.unavailable)
            }
        }
        
        // currentEntitlements intermittently omits active subscriptions
        // (documented for sandbox and the Xcode test environment). The
        // subscription status API stays correct in those windows, so cross-check
        // it before treating a subscription as not owned.
        for product in state.products where product.type == .autoRenewable {
            if purchasedItemsIds.contains(product.id) { continue }
            guard let statuses = try? await product.subscription?.status else { continue }
            for status in statuses {
                guard status.state == .subscribed || status.state == .inGracePeriod,
                      let transaction = try? checkVerified(status.transaction),
                      transaction.productID == product.id,
                      !purchasedItemsIds.contains(transaction.productID) else { continue }
                _ = processTransaction(
                    transaction,
                    purchased: &purchased,
                    purchasedItemsIds: &purchasedItemsIds,
                    activeSubscriptions: &activeSubscriptions
                )
                Logger.store.addLog("Recovered \(product.id) via subscription status - missing in currentEntitlements")
            }
        }

        Logger.store.addLog("Customer product status resolved. Owned: \(purchasedItemsIds.isEmpty ? "none" : purchasedItemsIds.joined(separator: ", "))")

        state.updatePurchasedProducts(purchased)
        updatePurchasedProductIds(Set(purchasedItemsIds))

        if !purchasedProductsMatchLocallyStored(productIds: purchasedItemsIds) {
            LocalStoreManager.shared.storePurchasedProductIds(purchasedItemsIds)
            updatePurchaseDataChanged(true)
        }
        
        // Store subscription data and notify of changes
        if !activeSubscriptions.isEmpty {
            let subscriptionData = StoredSubscriptionData(
                subscriptions: activeSubscriptions,
                lastUpdated: Date()
            )
            LocalStoreManager.shared.storeSubscriptionData(subscriptionData)
            updatePurchaseDataChanged(true)
        } else if storeIsAvailable, !LocalStoreManager.shared.getSubscriptionData().subscriptions.isEmpty {
            // The store answered authoritatively and no subscription is
            // active: drop stale stored data so the local fallback cannot
            // keep reporting an entitlement that no longer exists. Never
            // cleared while the store is unreachable, so offline users keep
            // their keychain fallback.
            LocalStoreManager.shared.clearSubscriptionData()
            updatePurchaseDataChanged(true)
        }
        
        updateStoreState(!state.isEmpty() ? StoreAvailabilityState.available : StoreAvailabilityState.unavailable)
    }

    /// Marks a just-verified transaction as owned immediately, without waiting
    /// for a currentEntitlements round trip. Called right after a successful
    /// purchase so ownership is reflected the moment the purchase completes.
    @MainActor
    func applyVerifiedTransaction(_ transaction: Transaction) {
        guard purchasableManager.productIDExists(transaction.productID) else { return }

        if let product = state.getProduct(withId: transaction.productID),
           !state.isPurchased(productId: transaction.productID) {
            state.updatePurchasedProducts(state.purchasedProducts + [product])
        }
        updatePurchasedProductIds(purchasedProductIds.union([transaction.productID]))

        // Persist the expiry right away so the keychain fallback also knows
        // about the purchase before the next full status update
        if transaction.productType == .autoRenewable {
            var subscriptions = LocalStoreManager.shared.getSubscriptionData().subscriptions
            subscriptions[transaction.productID] = SubscriptionInfo(
                productID: transaction.productID,
                expirationDate: transaction.expirationDate ?? Date(),
                isActive: true,
                renewalDate: nil,
                gracePeriodExpirationDate: nil,
                subscriptionGroupID: transaction.subscriptionGroupID ?? ""
            )
            LocalStoreManager.shared.storeSubscriptionData(
                StoredSubscriptionData(subscriptions: subscriptions, lastUpdated: Date()))
        }

        Logger.store.addLog("Applied verified transaction for \(transaction.productID) immediately after purchase")
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
