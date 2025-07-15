import Foundation

public enum SubscriptionPeriod {
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
    let period: SubscriptionPeriod
}
