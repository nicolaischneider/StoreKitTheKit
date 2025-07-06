import Foundation

public enum PurchasableType: Sendable {
    case nonConsumable
    case autoRenewableSubscription
}

public struct Purchasable: Equatable, Hashable, Sendable {
    
    public init(bundleId: String, type: PurchasableType) {
        self.bundleId = bundleId
        self.type = type
    }
    
    public let bundleId: String
    public let type: PurchasableType
}

public class PurchasableManager: @unchecked Sendable {
    
    public static let shared = PurchasableManager()
    
    private var purchasableItems: [String: Purchasable] = [:]
    
    var allCases: [Purchasable] {
        return purchasableItems.map { $0.value }
    }
    
    public func register(purchasableItems: [Purchasable]) {
        for item in purchasableItems {
            self.purchasableItems[item.bundleId] = item
        }
    }
    
    public func productIDExists(_ id: String) -> Bool {
        return purchasableItems[id] != nil
    }
    
    func produc(id: String) -> Purchasable? {
        return purchasableItems[id]
    }
}
