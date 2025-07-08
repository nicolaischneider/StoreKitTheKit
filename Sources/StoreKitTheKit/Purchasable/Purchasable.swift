import Foundation

public enum PurchasableType: Sendable {
    case nonConsumable
    case autoRenewableSubscription
    case nonRenewableSubscription
    case consumable
    
    var isSubscription: Bool {
        switch self {
        case .autoRenewableSubscription, .nonRenewableSubscription:
            return true
        default:
            return false
        }
    }
}

public struct Purchasable: Equatable, Hashable, Sendable {
    
    public init(bundleId: String, type: PurchasableType) {
        self.bundleId = bundleId
        self.type = type
    }
    
    public let bundleId: String
    public let type: PurchasableType
}

class PurchasableManager: @unchecked Sendable {
        
    private var purchasableItems: [String: Purchasable] = [:]
    private let lock = NSLock()
        
    func register(purchasableItems: [Purchasable]) async {
        // Use Task to ensure we're on a background thread if needed
        await Task {
            lock.withLock {
                for item in purchasableItems {
                    self.purchasableItems[item.bundleId] = item
                }
            }
        }.value
    }

    var allCases: [Purchasable] {
        lock.withLock {
            return Array(purchasableItems.values)
        }
    }
    
    // Synchronous read methods
    func productIDExists(_ id: String) -> Bool {
        lock.withLock {
            return purchasableItems[id] != nil
        }
    }
    
    func product(id: String) -> Purchasable? {
        lock.withLock {
            return purchasableItems[id]
        }
    }
}
