//
//  ContentView.swift
//  UltimateSwiftKitTester
//
//  Created by knc on 23.04.25.
//

import SwiftUI
import StoreKitTheKit

struct ContentView: View {
    
    @State private var isLoading = true
    @State private var feedbackMessage = ""
    @State private var showFeedback = false
    @State private var selectedSubscription: Purchasable = StoreItems.weeklySubscription
    @State private var subscriptionInfo = ""
    
    var body: some View {
        ScrollView {
            VStack(spacing: 25) {
                Text("StoreKitTheKit Tester")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .padding(.bottom, 20)
                
                if isLoading {
                    LoadingView()
                } else {
                    VStack(spacing: 30) {
                        
                        // Non-Consumable Section
                        VStack(spacing: 15) {
                            Text("Non-Consumable Testing")
                                .font(.headline)
                                .foregroundColor(.blue)
                            
                            Button("Purchase Super Package") {
                                Task { await purchaseNonConsumable() }
                            }
                            .buttonStyle(.borderedProminent)
                            
                            Button("Check Super Package Status") {
                                checkNonConsumableStatus()
                            }
                            .buttonStyle(.bordered)
                        }
                        
                        Divider()
                        
                        // Subscription Section
                        VStack(spacing: 15) {
                            Text("Subscription Testing")
                                .font(.headline)
                                .foregroundColor(.green)
                            
                            // Subscription Picker
                            Picker("Select Subscription", selection: $selectedSubscription) {
                                Text("Weekly ($0.99)").tag(StoreItems.weeklySubscription)
                                Text("Yearly ($10.99)").tag(StoreItems.yearlySubscription)
                            }
                            .pickerStyle(.segmented)
                            .padding(.horizontal)
                            
                            // Purchase current subscription
                            Button("Purchase \(selectedSubscription == StoreItems.weeklySubscription ? "Weekly" : "Yearly")") {
                                Task { await purchaseSubscription() }
                            }
                            .buttonStyle(.borderedProminent)
                            
                            // Switch subscription (purchase the other one)
                            Button("Switch to \(selectedSubscription == StoreItems.weeklySubscription ? "Yearly" : "Weekly")") {
                                Task { await switchSubscription() }
                            }
                            .buttonStyle(.bordered)
                            
                            HStack(spacing: 10) {
                                // Check subscription status
                                Button("Check Status") {
                                    checkSubscriptionStatus()
                                }
                                .buttonStyle(.bordered)
                                
                                // Get subscription info
                                Button("Get Info") {
                                    getSubscriptionInfo()
                                }
                                .buttonStyle(.bordered)
                            }
                        }
                        
                        Divider()
                        
                        // Status Section
                        VStack(spacing: 10) {
                            Text("Current Status")
                                .font(.headline)
                                .foregroundColor(.orange)
                            
                            Button("Check All Products") {
                                checkAllStatus()
                            }
                            .buttonStyle(.bordered)
                            
                            if !subscriptionInfo.isEmpty {
                                Text(subscriptionInfo)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .padding()
                                    .background(
                                        RoundedRectangle(cornerRadius: 8)
                                            .fill(Color(.systemGray6))
                                    )
                            }
                        }
                    }
                    .padding()
                    
                    if showFeedback {
                        Text(feedbackMessage)
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(Color(.systemBackground))
                                    .shadow(radius: 3)
                            )
                            .padding()
                            .transition(.opacity)
                            .animation(.easeInOut, value: showFeedback)
                    }
                }
            }
            .padding()
        }
        .onAppear {
            Task {
                await initializeStore()
            }
        }
        .onReceive(StoreKitTheKit.shared.$storeState) { state in
            feedbackMessage = "Store state changed: \(state)"
            showFeedback = true
        }
        .onReceive(StoreKitTheKit.shared.$purchaseDataChangedAfterGettingBackOnline) { changed in
            if changed {
                feedbackMessage = "Purchase data has been updated"
                showFeedback = true
                // Refresh subscription info when data changes
                getSubscriptionInfo()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
            Task {
                await StoreKitTheKit.shared.syncWithStore()
            }
        }
    }
    
    // MARK: - Store Initialization
    
    private func initializeStore() async {
        await StoreKitTheKit.shared.begin()
        
        await MainActor.run {
            isLoading = false
        }
    }
    
    // MARK: - Non-Consumable Functions
    
    private func purchaseNonConsumable() async {
        await MainActor.run {
            feedbackMessage = "Processing non-consumable purchase..."
            showFeedback = true
        }
        
        let result = await StoreKitTheKit.shared.purchaseElement(element: StoreItems.superPackage)
        
        await MainActor.run {
            switch result {
            case .purchaseCompleted(let purchasable):
                feedbackMessage = "✅ Successfully purchased: \(purchasable.bundleId)"
            case .purchaseFailure(let withError):
                feedbackMessage = "❌ Purchase failed: \(withError)"
            }
        }
    }
    
    private func checkNonConsumableStatus() {
        let isPurchased = StoreKitTheKit.shared.elementWasPurchased(element: StoreItems.superPackage)
        
        feedbackMessage = isPurchased ?
            "✅ Super Package is purchased" :
            "❌ Super Package is not purchased yet"
        showFeedback = true
    }
    
    // MARK: - Subscription Functions
    
    private func purchaseSubscription() async {
        let subscriptionName = selectedSubscription == StoreItems.weeklySubscription ? "Weekly" : "Yearly"
        
        await MainActor.run {
            feedbackMessage = "Processing \(subscriptionName) subscription purchase..."
            showFeedback = true
        }
        
        let result = await StoreKitTheKit.shared.purchaseElement(element: selectedSubscription)
        
        await MainActor.run {
            switch result {
            case .purchaseCompleted:
                feedbackMessage = "✅ Successfully subscribed to: \(subscriptionName)"
                getSubscriptionInfo()
            case .purchaseFailure(let withError):
                feedbackMessage = "❌ Subscription failed: \(withError)"
            }
        }
    }
    
    private func switchSubscription() async {
        let targetSubscription = selectedSubscription == StoreItems.weeklySubscription ? 
                                StoreItems.yearlySubscription : StoreItems.weeklySubscription
        let targetName = targetSubscription == StoreItems.weeklySubscription ? "Weekly" : "Yearly"
        
        await MainActor.run {
            feedbackMessage = "Switching to \(targetName) subscription..."
            showFeedback = true
        }
        
        let result = await StoreKitTheKit.shared.purchaseElement(element: targetSubscription)
        
        await MainActor.run {
            switch result {
            case .purchaseCompleted(_):
                feedbackMessage = "✅ Successfully switched to \(targetName) subscription"
                selectedSubscription = targetSubscription
                getSubscriptionInfo()
            case .purchaseFailure(let withError):
                feedbackMessage = "❌ Switch failed: \(withError)"
            }
        }
    }
    
    private func checkSubscriptionStatus() {
        let weeklyActive = StoreKitTheKit.shared.isSubscriptionActive(for: StoreItems.weeklySubscription)
        let yearlyActive = StoreKitTheKit.shared.isSubscriptionActive(for: StoreItems.yearlySubscription)
        
        var status = "Subscription Status:\n"
        status += "• Weekly: \(weeklyActive ? "✅ Active" : "❌ Inactive")\n"
        status += "• Yearly: \(yearlyActive ? "✅ Active" : "❌ Inactive")"
        
        // Also check detailed status
        let weeklyStatus = StoreKitTheKit.shared.getSubscriptionStatus(for: StoreItems.weeklySubscription)
        let yearlyStatus = StoreKitTheKit.shared.getSubscriptionStatus(for: StoreItems.yearlySubscription)
        
        status += "\n\nDetailed Status:\n"
        status += "• Weekly: \(weeklyStatus)\n"
        status += "• Yearly: \(yearlyStatus)"
        
        feedbackMessage = status
        showFeedback = true
    }
    
    private func getSubscriptionInfo() {
        var info = "Subscription Details:\n"
        
        for subscription in [StoreItems.weeklySubscription, StoreItems.yearlySubscription] {
            let name = subscription == StoreItems.weeklySubscription ? "Weekly" : "Yearly"
            let subscriptionInfo = StoreKitTheKit.shared.getSubscriptionInfo(for: subscription)
            
            if let subInfo = subscriptionInfo {
                info += "\n\(name):\n"
                info += "  • Active: \(subInfo.isActive)\n"
                info += "  • Expires: \(DateFormatter.localizedString(from: subInfo.expirationDate, dateStyle: .short, timeStyle: .short))\n"
                
                if let timeRemaining = StoreKitTheKit.shared.getSubscriptionTimeRemaining(for: subscription) {
                    let days = Int(timeRemaining / 86400) // Convert seconds to days
                    let hours = Int((timeRemaining.truncatingRemainder(dividingBy: 86400)) / 3600)
                    info += "  • Time left: \(days)d \(hours)h\n"
                }
            } else {
                info += "\n\(name): No active subscription\n"
            }
        }
        
        subscriptionInfo = info
    }
    
    private func checkAllStatus() {
        var status = "All Products Status:\n\n"
        
        // Non-consumable
        let superPackagePurchased = StoreKitTheKit.shared.elementWasPurchased(element: StoreItems.superPackage)
        status += "Super Package: \(superPackagePurchased ? "✅ Purchased" : "❌ Not purchased")\n\n"
        
        // Subscriptions using elementWasPurchased (which checks validity)
        let weeklyValid = StoreKitTheKit.shared.elementWasPurchased(element: StoreItems.weeklySubscription)
        let yearlyValid = StoreKitTheKit.shared.elementWasPurchased(element: StoreItems.yearlySubscription)
        
        status += "Weekly Subscription: \(weeklyValid ? "✅ Active" : "❌ Inactive")\n"
        status += "Yearly Subscription: \(yearlyValid ? "✅ Active" : "❌ Inactive")"
        
        feedbackMessage = status
        showFeedback = true
        
        // Also refresh detailed subscription info
        getSubscriptionInfo()
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
