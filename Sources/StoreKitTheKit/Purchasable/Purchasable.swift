//
//  PurchasableGameModes.swift
//  100Questions
//
//  Created by Nicolai Schneider on 09.10.21.
//  Copyright © 2021 Schneider & co. All rights reserved.
//

import Foundation

public enum PurchasableType: Sendable {
    case nonConsumable
}

public struct Purchasable: Sendable {
    
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
