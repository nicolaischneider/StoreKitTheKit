import StoreKit
import Foundation
import os

typealias Transaction = StoreKit.Transaction

extension StoreKitTheKit {
    
    func getPurchasableProduct (id: String) -> Product? {
        for product in self.products {
            if product.id == id {
                return product
            }
        }
        return nil
    }
}

// storekit 2
extension StoreKitTheKit {
    
    // request products
    @MainActor
    func requestProducts() async {
        let productIDs = Set(Purchasable.allCases.map(\.rawValue))
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
        
        purchaseDataChanged = false
        
        var purchased: [Product] = []
        var purchasedItemsIds: [String] = []

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
                    if Purchasable.productIDExists(transaction.productID) {
                        purchasedItemsIds.append(transaction.productID)
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
            purchaseDataChanged = true
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

// purchase
extension StoreKitTheKit {

    func purchase(_ element: Purchasable) async -> PurchaseState {
        
        
        guard let product = self.products.first(where: { $0.id == element.rawValue }) else {
            Logger.store.addLog("Purchasbale item couldn't be found.")
            return completedPurchase(state: .purchaseNotCompleted(withError: true))
        }
        
        purchaseWasInitialized()
        
        do {
            let result = try await product.purchase()
            switch result {
                
            // Purchase went through!
            case .success(let verified):
                
                // verify purchase
                guard let transaction = try? checkVerified(verified) else {
                    Logger.store.addLog("Purchase unverified")
                    return completedPurchase(state: .purchaseNotCompleted(withError: false))
                }
                Logger.store.addLog("Purchase verified: \(transaction)")
                
                // Update customer status
                await self.updateCustomerProductStatus()
                await transaction.finish()
                
                // Return purchase as completed
                Logger.store.addLog("Purchase completed")
                return completedPurchase(state: .purchaseCompleted(element))
                
            case .userCancelled:
                Logger.store.addLog("User cancelled purchase")
                return completedPurchase(state: .purchaseNotCompleted(withError: false))
                
            case .pending:
                Logger.store.addLog("Purchase still pending")
                return completedPurchase(state: .purchaseNotCompleted(withError: false))
                
            @unknown default:
                Logger.store.addLog("Unknown purchase state")
                return completedPurchase(state: .purchaseNotCompleted(withError: true))
            }
        } catch {
            Logger.store.addLog("Failed to purchase product: \(error)")
            return completedPurchase(state: .purchaseNotCompleted(withError: true))
        }
    }
    
    private func purchaseWasInitialized () {
        DispatchQueue.main.async {
            // self.delegateLaunchScreen?.purchasing()
        }
    }
        
    private func completedPurchase (state: PurchaseState) -> PurchaseState {
        DispatchQueue.main.async {
            /*switch state {
            case .purchaseCompleted(let purchasable):
                self.delegateLaunchScreen?.itemWasPurchased(purchasable)
            case .purchaseNotCompleted(_):
                self.delegateLaunchScreen?.itemWasPurchased(nil)
            }*/
        }
        return state
    }
}

// App Store promotion
extension StoreKitTheKit: SKPaymentTransactionObserver {
    
    func paymentQueue(_ queue: SKPaymentQueue, updatedTransactions transactions: [SKPaymentTransaction]) {
        return
    }
    
    func paymentQueue(_ queue: SKPaymentQueue, shouldAddStorePayment payment: SKPayment, for product: SKProduct) -> Bool {
        guard let purchasable = Purchasable(rawValue: product.productIdentifier) else {
            //Logger.purchase.addLog("Product couldn't be identified")
            return false
        }
        
        guard !userHasAccessTo(element: purchasable) else {
            //Logger.purchase.addLog("Product already purchased")
            return false
        }
        
        Task {
            let _ = await purchaseElement(element: purchasable)
        }
        
        return true
    }
}
