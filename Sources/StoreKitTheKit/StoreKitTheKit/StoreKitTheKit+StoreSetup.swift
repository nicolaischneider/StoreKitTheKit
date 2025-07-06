import StoreKit
import Foundation
import os

typealias Transaction = StoreKit.Transaction

extension StoreKitTheKit {
    
    // request products
    @MainActor
    func requestProducts() async {
        let productIDs = Set(PurchasableManager.shared.allCases.map(\.bundleId))
        do {
            self.products = try await Product.products(for: productIDs)
            storeState = !products.isEmpty ? .available : .unavailable
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
                
                // Check the `productType` of the transaction and get the corresponding product from the store
                switch transaction.productType {
                case .nonConsumable:
                    if let purchasedItem = products.first(where: { $0.id == transaction.productID }) {
                        purchased.append(purchasedItem)
                    }
                    if PurchasableManager.shared.productIDExists(transaction.productID) {
                        purchasedItemsIds.append(transaction.productID)
                    }
                case .autoRenewable:
                    // Check if the product ID exists in PurchasableManager
                    guard PurchasableManager.shared.productIDExists(transaction.productID) else {
                        Logger.store.addLog("Product \(transaction.productID) not found in PurchasableManager")
                        continue
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
                    if let purchasedItem = products.first(where: { $0.id == transaction.productID }) {
                        purchased.append(purchasedItem)
                    }
                    purchasedItemsIds.append(transaction.productID)
                case .consumable:
                    // Consumables are processed but not tracked in purchased products
                    // Apps handle their own consumption logic after successful purchase
                    if PurchasableManager.shared.productIDExists(transaction.productID) {
                        Logger.store.addLog("Consumable purchase processed: \(transaction.productID)")
                        // Transaction will be finished in the purchase flow
                    }
                default:
                    continue
                }
            } catch {
                Logger.store.addLog("Something went wrong while updating customer product status: \(error)", level: .error)
                storeState = .unavailable
            }
        }
        
        self.purchasedProducts = purchased
        
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
        
        storeState = !products.isEmpty ? .available : .unavailable
    }
    
    func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified:
            throw StoreError.purchaseNotVerifed
        case .verified(let safe):
            return safe
        }
    }
}
