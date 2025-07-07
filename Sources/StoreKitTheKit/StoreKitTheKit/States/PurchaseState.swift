import Foundation

public enum PurchaseState: Sendable {
    case purchaseCompleted(Purchasable)
    case purchaseFailure(PurchaseError)
    
    public enum PurchaseError: Error, Sendable {
        // Product errors
        case productNotFound
        case unverifiedPurchase
        
        // User interaction
        case userCancelled
        case pendingPurchase
        
        // System errors
        case unknownPurchaseState
        case purchaseError(Error)
        
        // Subscription errors
        case subscriptionExpired
        case subscriptionNotActive
        case subscriptionInGracePeriod
        case subscriptionBillingRetry
    }
}
