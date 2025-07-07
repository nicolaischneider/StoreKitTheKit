import Foundation
import StoreKit

public struct SubscriptionInfo: Codable, Sendable {
    public let productID: String
    public let expirationDate: Date
    public let isActive: Bool
    public let renewalDate: Date?
    public let gracePeriodExpirationDate: Date?
    public let subscriptionGroupID: String
    
    public init(productID: String, expirationDate: Date, isActive: Bool, renewalDate: Date?, gracePeriodExpirationDate: Date?, subscriptionGroupID: String) {
        self.productID = productID
        self.expirationDate = expirationDate
        self.isActive = isActive
        self.renewalDate = renewalDate
        self.gracePeriodExpirationDate = gracePeriodExpirationDate
        self.subscriptionGroupID = subscriptionGroupID
    }
}

public enum SubscriptionStatus: Sendable {
    case active
    case expired
    case inGracePeriod
    case inBillingRetry
    case revoked
    case unknown
}

struct StoredSubscriptionData: Codable, Sendable {
    let subscriptions: [String: SubscriptionInfo]
    let lastUpdated: Date
    
    init(subscriptions: [String: SubscriptionInfo] = [:], lastUpdated: Date = Date()) {
        self.subscriptions = subscriptions
        self.lastUpdated = lastUpdated
    }
}