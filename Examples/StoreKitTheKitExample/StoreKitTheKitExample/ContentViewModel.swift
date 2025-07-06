//
//  ContentViewModel.swift
//  UltimateSwiftKitTester
//
//  Created by knc on 23.04.25.
//

import SwiftUI
import StoreKitTheKit
#if canImport(UIKit)
import UIKit
#endif

@MainActor
class ContentViewModel: ObservableObject {
    
    @Published var isLoading = true
    @Published var feedbackMessage = ""
    @Published var showFeedback = false
    @Published var selectedSubscription: Purchasable = StoreItems.weeklySubscription
    @Published var subscriptionInfo = ""
    
    // Consumable tracking
    @Published var coinsCount = 0
    @Published var energyCount = 0
    
    init() {
        setupObservers()
    }
    
    private func setupObservers() {
        // Observe store state changes
        NotificationCenter.default.addObserver(
            forName: .storeStateChanged,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.feedbackMessage = "Store state changed: \(StoreKitTheKit.shared.storeState)"
            self?.showFeedback = true
        }
        
        // Observe purchase data changes
        NotificationCenter.default.addObserver(
            forName: .purchaseDataChanged,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            if StoreKitTheKit.shared.purchaseDataChangedAfterGettingBackOnline {
                self?.feedbackMessage = "Purchase data has been updated"
                self?.showFeedback = true
                self?.getSubscriptionInfo()
            }
        }
        
        #if canImport(UIKit)
        // Observe app becoming active
        NotificationCenter.default.addObserver(
            forName: UIApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { _ in
            Task {
                await StoreKitTheKit.shared.syncWithStore()
            }
        }
        #endif
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    // MARK: - Store Initialization
    
    func initializeStore() async {
        await StoreKitTheKit.shared.begin()
        isLoading = false
    }
    
    // MARK: - Non-Consumable Functions
    
    func purchaseNonConsumable() async {
        feedbackMessage = "Processing non-consumable purchase..."
        showFeedback = true
        
        let result = await StoreKitTheKit.shared.purchaseElement(element: StoreItems.superPackage)
        
        switch result {
        case .purchaseCompleted(let purchasable):
            feedbackMessage = "✅ Successfully purchased: \(purchasable.bundleId)"
        case .purchaseFailure(let withError):
            feedbackMessage = "❌ Purchase failed: \(withError)"
        }
    }
    
    func checkNonConsumableStatus() {
        let isPurchased = StoreKitTheKit.shared.elementWasPurchased(element: StoreItems.superPackage)
        
        feedbackMessage = isPurchased ?
            "✅ Super Package is purchased" :
            "❌ Super Package is not purchased yet"
        showFeedback = true
    }
    
    // MARK: - Consumable Functions
    
    func purchaseConsumable(_ consumable: Purchasable) async {
        let consumableName = consumable == StoreItems.hundredCoins ? "100 Coins" : "10 Energy"
        
        feedbackMessage = "Processing \(consumableName) purchase..."
        showFeedback = true
        
        let result = await StoreKitTheKit.shared.purchaseElement(element: consumable)
        
        switch result {
        case .purchaseCompleted(_):
            // Update internal counts
            if consumable == StoreItems.hundredCoins {
                coinsCount += 100
            } else if consumable == StoreItems.tenEnergy {
                energyCount += 10
            }
            feedbackMessage = "✅ Successfully purchased \(consumableName)!"
        case .purchaseFailure(let withError):
            feedbackMessage = "❌ Consumable purchase failed: \(withError)"
        }
    }
    
    // MARK: - Subscription Functions
    
    func purchaseSubscription() async {
        let subscriptionName = selectedSubscription == StoreItems.weeklySubscription ? "Weekly" : "Yearly"
        
        feedbackMessage = "Processing \(subscriptionName) subscription purchase..."
        showFeedback = true
        
        let result = await StoreKitTheKit.shared.purchaseElement(element: selectedSubscription)
        
        switch result {
        case .purchaseCompleted:
            feedbackMessage = "✅ Successfully subscribed to: \(subscriptionName)"
            getSubscriptionInfo()
        case .purchaseFailure(let withError):
            feedbackMessage = "❌ Subscription failed: \(withError)"
        }
    }
    
    func switchSubscription() async {
        let targetSubscription = selectedSubscription == StoreItems.weeklySubscription ?
                                StoreItems.yearlySubscription : StoreItems.weeklySubscription
        let targetName = targetSubscription == StoreItems.weeklySubscription ? "Weekly" : "Yearly"
        
        feedbackMessage = "Switching to \(targetName) subscription..."
        showFeedback = true
        
        let result = await StoreKitTheKit.shared.purchaseElement(element: targetSubscription)
        
        switch result {
        case .purchaseCompleted(_):
            feedbackMessage = "✅ Successfully switched to \(targetName) subscription"
            selectedSubscription = targetSubscription
            getSubscriptionInfo()
        case .purchaseFailure(let withError):
            feedbackMessage = "❌ Switch failed: \(withError)"
        }
    }
    
    func checkSubscriptionStatus() {
        let weeklyActive = StoreKitTheKit.shared.isSubscriptionActive(for: StoreItems.weeklySubscription)
        let yearlyActive = StoreKitTheKit.shared.isSubscriptionActive(for: StoreItems.yearlySubscription)
        
        var status = "Subscription Status:\n"
        status += "• Weekly: \(weeklyActive ? "✅ Active" : "❌ Inactive")\n"
        status += "• Yearly: \(yearlyActive ? "✅ Active" : "❌ Inactive")"
        
        let weeklyStatus = StoreKitTheKit.shared.getSubscriptionStatus(for: StoreItems.weeklySubscription)
        let yearlyStatus = StoreKitTheKit.shared.getSubscriptionStatus(for: StoreItems.yearlySubscription)
        
        status += "\n\nDetailed Status:\n"
        status += "• Weekly: \(weeklyStatus)\n"
        status += "• Yearly: \(yearlyStatus)"
        
        feedbackMessage = status
        showFeedback = true
    }
    
    func getSubscriptionInfo() {
        var info = "Subscription Details:\n"
        
        for subscription in [StoreItems.weeklySubscription, StoreItems.yearlySubscription] {
            let name = subscription == StoreItems.weeklySubscription ? "Weekly" : "Yearly"
            let subscriptionInfo = StoreKitTheKit.shared.getSubscriptionInfo(for: subscription)
            
            if let subInfo = subscriptionInfo {
                info += "\n\(name):\n"
                info += "  • Active: \(subInfo.isActive)\n"
                info += "  • Expires: \(DateFormatter.localizedString(from: subInfo.expirationDate, dateStyle: .short, timeStyle: .short))\n"
                
                if let timeRemaining = StoreKitTheKit.shared.getSubscriptionTimeRemaining(for: subscription) {
                    let days = Int(timeRemaining / 86400)
                    let hours = Int((timeRemaining.truncatingRemainder(dividingBy: 86400)) / 3600)
                    info += "  • Time left: \(days)d \(hours)h\n"
                }
            } else {
                info += "\n\(name): No active subscription\n"
            }
        }
        
        subscriptionInfo = info
    }
    
    func checkAllStatus() {
        var status = "All Products Status:\n\n"
        
        // Non-consumable
        let superPackagePurchased = StoreKitTheKit.shared.elementWasPurchased(element: StoreItems.superPackage)
        status += "Super Package: \(superPackagePurchased ? "✅ Purchased" : "❌ Not purchased")\n\n"
        
        // Subscriptions using elementWasPurchased (which checks validity)
        let weeklyValid = StoreKitTheKit.shared.elementWasPurchased(element: StoreItems.weeklySubscription)
        let yearlyValid = StoreKitTheKit.shared.elementWasPurchased(element: StoreItems.yearlySubscription)
        
        status += "Weekly Subscription: \(weeklyValid ? "✅ Active" : "❌ Inactive")\n"
        status += "Yearly Subscription: \(yearlyValid ? "✅ Active" : "❌ Inactive")\n\n"
        
        // Consumables (show current counts)
        status += "Consumables:\n"
        status += "• Coins: \(coinsCount)\n"
        status += "• Energy: \(energyCount)"
        
        feedbackMessage = status
        showFeedback = true
        
        // Also refresh detailed subscription info
        getSubscriptionInfo()
    }
}

// MARK: - Notification Extensions

extension Notification.Name {
    static let storeStateChanged = Notification.Name("storeStateChanged")
    static let purchaseDataChanged = Notification.Name("purchaseDataChanged")
}
