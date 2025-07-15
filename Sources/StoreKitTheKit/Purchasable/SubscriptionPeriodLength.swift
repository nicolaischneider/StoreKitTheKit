import Foundation

public enum SubscriptionPeriodLength {
    case weekly
    case monthly
    case yearly
    
    public var weeksPerPeriod: Int {
        switch self {
        case .weekly: return 1
        case .monthly: return 4
        case .yearly: return 52
        }
    }
}

public struct SubscriptionItem {
    let purchasable: Purchasable
    let period: SubscriptionPeriodLength
    
    public init(purchasable: Purchasable, period: SubscriptionPeriodLength) {
        self.purchasable = purchasable
        self.period = period
    }
}
