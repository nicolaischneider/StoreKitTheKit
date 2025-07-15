//
//  ContentViewModel.swift
//  UltimateSwiftKitTester
//
//  Created by knc on 23.04.25.
//

import SwiftUI
import StoreKitTheKit
import UIKit

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
    
    // Dynamic pricing
    @Published var superPackagePrice = "Loading..."
    @Published var weeklySubscriptionPrice = "Loading..."
    @Published var yearlySubscriptionPrice = "Loading..."
    @Published var premiumPassPrice = "Loading..."
    @Published var hundredCoinsPrice = "Loading..."
    @Published var tenEnergyPrice = "Loading..."
    
    // Test new functions
    @Published var weeklyDividedPrice = "Loading..."
    @Published var yearlyDividedPrice = "Loading..."
    @Published var subscriptionSavings = "Loading..."
    
    init() {
        setupObservers()
    }
    
    private func setupObservers() {
        // These custom notifications don't exist in StoreKitTheKit and were causing issues
        // We'll use the @Published properties directly in the view instead
    }
    
    // MARK: - Store Initialization
    
    func initializeStore() async {
        await StoreKitTheKit.shared.start(iapItems: StoreItems.allItems)
        updatePrices()
        isLoading = false
    }
    
    // MARK: - Price Management
    
    func updatePrices() {
        superPackagePrice = StoreKitTheKit.shared.getPriceFormatted(for: StoreItems.superPackage) ?? "N/A"
        weeklySubscriptionPrice = StoreKitTheKit.shared.getPriceFormatted(for: StoreItems.weeklySubscription) ?? "N/A"
        yearlySubscriptionPrice = StoreKitTheKit.shared.getPriceFormatted(for: StoreItems.yearlySubscription) ?? "N/A"
        premiumPassPrice = StoreKitTheKit.shared.getPriceFormatted(for: StoreItems.premiumPass) ?? "N/A"
        hundredCoinsPrice = StoreKitTheKit.shared.getPriceFormatted(for: StoreItems.hundredCoins) ?? "N/A"
        tenEnergyPrice = StoreKitTheKit.shared.getPriceFormatted(for: StoreItems.tenEnergy) ?? "N/A"
        
        // Test new functions
        weeklyDividedPrice = StoreKitTheKit.shared.getDividedPrice(for: StoreItems.weeklySubscription, dividedBy: SubscriptionPeriodLength.weekly.weeksPerPeriod) ?? "N/A"
        yearlyDividedPrice = StoreKitTheKit.shared.getDividedPrice(for: StoreItems.yearlySubscription, dividedBy: SubscriptionPeriodLength.yearly.weeksPerPeriod) ?? "N/A"

        let weeklySubscriptionItem = SubscriptionItem(purchasable: StoreItems.weeklySubscription, period: .weekly)
        let yearlySubscriptionItem = SubscriptionItem(purchasable: StoreItems.yearlySubscription, period: .yearly)
        subscriptionSavings = StoreKitTheKit.shared.compareSubscriptionSavings(subscription1: weeklySubscriptionItem, subscription2: yearlySubscriptionItem) ?? "N/A"
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
        
        for subscription in [StoreItems.weeklySubscription, StoreItems.yearlySubscription, StoreItems.premiumPass] {
            let name = subscription == StoreItems.weeklySubscription ? "Weekly" : 
                      subscription == StoreItems.yearlySubscription ? "Yearly" : "Premium Pass"
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
        let premiumPassValid = StoreKitTheKit.shared.elementWasPurchased(element: StoreItems.premiumPass)
        
        status += "Weekly Subscription: \(weeklyValid ? "✅ Active" : "❌ Inactive")\n"
        status += "Yearly Subscription: \(yearlyValid ? "✅ Active" : "❌ Inactive")\n"
        status += "Premium Pass: \(premiumPassValid ? "✅ Active" : "❌ Inactive")\n\n"
        
        // Consumables (show current counts)
        status += "Consumables:\n"
        status += "• Coins: \(coinsCount)\n"
        status += "• Energy: \(energyCount)"
        
        feedbackMessage = status
        showFeedback = true
        
        // Also refresh detailed subscription info
        getSubscriptionInfo()
    }
    
    // MARK: - Non-Renewable Subscription Functions
    
    func purchaseNonRenewableSubscription() async {
        feedbackMessage = "Processing Premium Pass purchase..."
        showFeedback = true
        
        let result = await StoreKitTheKit.shared.purchaseElement(element: StoreItems.premiumPass)
        
        switch result {
        case .purchaseCompleted:
            feedbackMessage = "✅ Successfully purchased Premium Pass - 30 Days!"
            getSubscriptionInfo()
        case .purchaseFailure(let withError):
            feedbackMessage = "❌ Premium Pass purchase failed: \(withError)"
        }
    }
    
    func checkNonRenewableSubscriptionStatus() {
        let isActive = StoreKitTheKit.shared.isSubscriptionActive(for: StoreItems.premiumPass)
        let status = StoreKitTheKit.shared.getSubscriptionStatus(for: StoreItems.premiumPass)
        
        var message = "Premium Pass Status: \(isActive ? "✅ Active" : "❌ Inactive")\n"
        message += "Detailed Status: \(status)"
        
        if let subscriptionInfo = StoreKitTheKit.shared.getSubscriptionInfo(for: StoreItems.premiumPass) {
            message += "\nExpires: \(DateFormatter.localizedString(from: subscriptionInfo.expirationDate, dateStyle: .short, timeStyle: .short))"
            
            if let timeRemaining = StoreKitTheKit.shared.getSubscriptionTimeRemaining(for: StoreItems.premiumPass) {
                let days = Int(timeRemaining / 86400)
                let hours = Int((timeRemaining.truncatingRemainder(dividingBy: 86400)) / 3600)
                message += "\nTime remaining: \(days)d \(hours)h"
            }
        }
        
        feedbackMessage = message
        showFeedback = true
    }
    
    func manageSubscription() async {
        feedbackMessage = "Opening subscription management..."
        showFeedback = true
        
        do {
            try await StoreKitTheKit.shared.manageSubscription(for: selectedSubscription)
            feedbackMessage = "Subscription management opened successfully"
        } catch {
            feedbackMessage = "❌ Failed to open subscription management: \(error)"
        }
    }
}
