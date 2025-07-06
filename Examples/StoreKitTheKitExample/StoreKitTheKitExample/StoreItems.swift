//
//  StoreItems.swift
//  UltimateSwiftKitTester
//
//  Created by knc on 23.04.25.
//

import Foundation
import StoreKitTheKit

struct StoreItems {
    
    // Non-consumable
    static let superPackage = Purchasable(bundleId: "com.nicolaischneider.superpackage", type: .nonConsumable)
    
    // Subscriptions
    static let weeklySubscription = Purchasable(bundleId: "com.nicolaischneider.superdupersub.weekly", type: .autoRenewableSubscription)
    static let yearlySubscription = Purchasable(bundleId: "com.nicolaischneider.superdupersub.yearly", type: .autoRenewableSubscription)
    
    // Consumables
    static let hundredCoins = Purchasable(bundleId: "com.nicolaischneider.coins.hundred", type: .consumable)
    static let tenEnergy = Purchasable(bundleId: "com.nicolaischneider.energy.ten", type: .consumable)
    
    // All items for easy registration
    static let allItems = [superPackage, weeklySubscription, yearlySubscription, hundredCoins, tenEnergy]
}
