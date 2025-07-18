import StoreKit
import Foundation
import os

// MARK: - Subscription Management

extension StoreKitTheKit {
    
    // MARK: - Subscription Status
    
    /**
     Checks if a subscription is currently active (not expired and not in grace period issues).
     
     - Parameter element: The subscription Purchasable item to check
     - Returns: Boolean indicating if the subscription is active
     */
    public func isSubscriptionActive(for element: Purchasable) -> Bool {
        guard element.type.isSubscription else {
            Logger.store.addLog("Element \(element.bundleId) is not a subscription", level: .error)
            return false
        }
        return elementWasPurchased(element: element)
    }
    
    /**
     Gets the detailed subscription status for a given subscription.
     
     - Parameter element: The subscription Purchasable item to check
     - Returns: SubscriptionStatus indicating the current state of the subscription
     */
    public func getSubscriptionStatus(for element: Purchasable) -> SubscriptionStatus {
        guard element.type.isSubscription else {
            Logger.store.addLog("Element \(element.bundleId) is not a subscription", level: .error)
            return .unknown
        }
        
        if storeIsAvailable {
            // Check current entitlements for live status
            return getSubscriptionStatusFromStore(productID: element.bundleId)
        } else {
            // Check local storage
            return getSubscriptionStatusFromLocal(productID: element.bundleId)
        }
    }
    
    // MARK: - Subscription Information
    
    /**
     Gets detailed information about a subscription including expiration date and renewal info.
     
     - Parameter element: The subscription Purchasable item to get info for
     - Returns: SubscriptionInfo if available, nil otherwise
     */
    public func getSubscriptionInfo(for element: Purchasable) -> SubscriptionInfo? {
        guard element.type.isSubscription else {
            Logger.store.addLog("Element \(element.bundleId) is not a subscription", level: .error)
            return nil
        }
        
        return LocalStoreManager.shared.getSubscriptionInfo(for: element.bundleId)
    }
    
    /**
     Gets the remaining time for a subscription before expiration.
     
     - Parameter element: The subscription Purchasable item to check
     - Returns: TimeInterval representing seconds until expiration, or nil if subscription not found or expired
     */
    public func getSubscriptionTimeRemaining(for element: Purchasable) -> TimeInterval? {
        guard let subscriptionInfo = getSubscriptionInfo(for: element) else {
            return nil
        }
        
        let now = Date()
        let timeRemaining = subscriptionInfo.expirationDate.timeIntervalSince(now)
        
        return timeRemaining > 0 ? timeRemaining : nil
    }
    
    /**
     Gets the expiration date for a subscription.
     
     - Parameter element: The subscription Purchasable item to check
     - Returns: Date when the subscription expires, or nil if not found
     */
    public func getSubscriptionExpirationDate(for element: Purchasable) -> Date? {
        return getSubscriptionInfo(for: element)?.expirationDate
    }
    
    // MARK: - Subscription Management
    
    /**
     Opens subscription management by attempting to repurchase an active auto-renewable subscription.
     
     This clever approach triggers Apple's subscription management interface when trying to repurchase
     an already active subscription. The system will show options to manage, upgrade, or downgrade.
     
     - Parameter element: The auto-renewable subscription to manage
     - Throws: StoreError if the element is not an auto-renewable subscription or not currently active
     
     - Note: Only works for auto-renewable subscriptions that are currently active
     */
    public func manageSubscription(for element: Purchasable) async throws {
        // Check if it's an auto-renewable subscription
        guard element.type == .autoRenewableSubscription else {
            Logger.store.addLog("Element \(element.bundleId) is not an auto-renewable subscription", level: .error)
            throw StoreError.subscriptionNotFound
        }
        
        // Check if the subscription is currently active (in purchasedProducts)
        guard self.purchasedProducts.first(where: { $0.id == element.bundleId }) != nil else {
            Logger.store.addLog("Subscription \(element.bundleId) is not currently active", level: .error)
            throw StoreError.subscriptionNotFound
        }
        
        Logger.store.addLog("Opening subscription management for \(element.bundleId) by attempting repurchase...")
        
        // Attempt to repurchase the active subscription - this will trigger subscription management UI
        let _ = await purchaseElement(element: element)
    }
    
    // MARK: - Private Helper Methods
    
    private func getSubscriptionStatusFromStore(productID: String) -> SubscriptionStatus {
        // Check if subscription is in current purchased products
        if purchasedProducts.contains(where: { $0.id == productID }) {
            return .active
        }
        
        // If not in purchased products, check if we have any stored info
        if let subscriptionInfo = LocalStoreManager.shared.getSubscriptionInfo(for: productID) {
            let now = Date()
            
            // Check if expired
            if subscriptionInfo.expirationDate <= now {
                // Check if in grace period
                if let gracePeriodEnd = subscriptionInfo.gracePeriodExpirationDate,
                   gracePeriodEnd > now {
                    return .inGracePeriod
                }
                return .expired
            }
            
            return .active
        }
        
        return .unknown
    }
    
    private func getSubscriptionStatusFromLocal(productID: String) -> SubscriptionStatus {
        guard let subscriptionInfo = LocalStoreManager.shared.getSubscriptionInfo(for: productID) else {
            return .unknown
        }
        
        let now = Date()
        
        // Check if subscription is still valid
        if subscriptionInfo.expirationDate > now {
            return .active
        }
        
        // Check if in grace period
        if let gracePeriodEnd = subscriptionInfo.gracePeriodExpirationDate,
           gracePeriodEnd > now {
            return .inGracePeriod
        }
        
        return .expired
    }
}
