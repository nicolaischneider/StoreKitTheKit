//
//  ContentView.swift
//  UltimateSwiftKitTester
//
//  Created by knc on 23.04.25.
//

import SwiftUI
import StoreKitTheKit

struct ContentView: View {
    
    @StateObject private var viewModel = ContentViewModel()
    
    var body: some View {
        ScrollView {
            VStack(spacing: 25) {
                Text("StoreKitTheKit Tester")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .padding(.bottom, 20)
                
                if viewModel.isLoading {
                    LoadingView()
                } else {
                    VStack(spacing: 30) {
                        
                        // Non-Consumable Section
                        VStack(spacing: 15) {
                            Text("Non-Consumable Testing")
                                .font(.headline)
                                .foregroundColor(.blue)
                            
                            Button("Purchase Super Package (\(viewModel.superPackagePrice))") {
                                Task { await viewModel.purchaseNonConsumable() }
                            }
                            .buttonStyle(.borderedProminent)
                            
                            Button("Check Super Package Status") {
                                viewModel.checkNonConsumableStatus()
                            }
                            .buttonStyle(.bordered)
                        }
                        
                        Divider()
                        
                        // Subscription Section
                        VStack(spacing: 15) {
                            Text("Subscription Testing")
                                .font(.headline)
                                .foregroundColor(.green)
                            
                            // Test new functions
                            VStack(spacing: 10) {
                                Text("Weekly subscription divided by \(SubscriptionPeriodLength.weekly.weeksPerPeriod): \(viewModel.weeklyDividedPrice)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                
                                Text("Yearly subscription divided by \(SubscriptionPeriodLength.yearly.weeksPerPeriod): \(viewModel.yearlyDividedPrice)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                
                                Text("Subscription savings: \(viewModel.subscriptionSavings)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .padding(10)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color(.systemGray6))
                            )
                            
                            // Subscription Picker
                            Picker("Select Subscription", selection: $viewModel.selectedSubscription) {
                                Text("Weekly (\(viewModel.weeklySubscriptionPrice))").tag(StoreItems.weeklySubscription)
                                Text("Yearly (\(viewModel.yearlySubscriptionPrice))").tag(StoreItems.yearlySubscription)
                            }
                            .pickerStyle(.segmented)
                            .padding(.horizontal)
                            
                            // Purchase current subscription
                            Button("Purchase \(viewModel.selectedSubscription == StoreItems.weeklySubscription ? "Weekly (\(viewModel.weeklySubscriptionPrice))" : "Yearly (\(viewModel.yearlySubscriptionPrice))")") {
                                Task { await viewModel.purchaseSubscription() }
                            }
                            .buttonStyle(.borderedProminent)
                            
                            // Switch subscription (purchase the other one)
                            Button("Switch to \(viewModel.selectedSubscription == StoreItems.weeklySubscription ? "Yearly (\(viewModel.yearlySubscriptionPrice))" : "Weekly (\(viewModel.weeklySubscriptionPrice))")") {
                                Task { await viewModel.switchSubscription() }
                            }
                            .buttonStyle(.bordered)
                            
                            // Check subscription status
                            Button("Check Status") {
                                viewModel.checkSubscriptionStatus()
                            }
                            .buttonStyle(.bordered)
                            
                            // Manage subscription
                            Button("Manage Subscription") {
                                Task { await viewModel.manageSubscription() }
                            }
                            .buttonStyle(.bordered)
                        }
                        
                        Divider()
                        
                        // Non-Renewable Subscription Section
                        VStack(spacing: 15) {
                            Text("Non-Renewable Subscription Testing")
                                .font(.headline)
                                .foregroundColor(.orange)
                            
                            Button("Purchase Premium Pass - 30 Days (\(viewModel.premiumPassPrice))") {
                                Task { await viewModel.purchaseNonRenewableSubscription() }
                            }
                            .buttonStyle(.borderedProminent)
                            
                            Button("Check Premium Pass Status") {
                                viewModel.checkNonRenewableSubscriptionStatus()
                            }
                            .buttonStyle(.bordered)
                        }
                        
                        Divider()
                        
                        // Consumable Section
                        VStack(spacing: 15) {
                            Text("Consumable Testing")
                                .font(.headline)
                                .foregroundColor(.purple)
                            
                            VStack(spacing: 10) {
                                HStack(spacing: 10) {
                                    // Purchase coins
                                    Button("Buy 100 Coins (\(viewModel.hundredCoinsPrice))") {
                                        Task { await viewModel.purchaseConsumable(StoreItems.hundredCoins) }
                                    }
                                    .buttonStyle(.bordered)
                                    
                                    // Purchase energy
                                    Button("Buy 10 Energy (\(viewModel.tenEnergyPrice))") {
                                        Task { await viewModel.purchaseConsumable(StoreItems.tenEnergy) }
                                    }
                                    .buttonStyle(.bordered)
                                }
                                
                                // Display current counts
                                HStack(spacing: 20) {
                                    Text("Coins: \(viewModel.coinsCount)")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    
                                    Text("Energy: \(viewModel.energyCount)")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                        
                        Divider()
                        
                        // Status Section
                        VStack(spacing: 10) {
                            Text("Current Status")
                                .font(.headline)
                                .foregroundColor(.orange)
                            
                            Button("Check All Products") {
                                viewModel.checkAllStatus()
                            }
                            .buttonStyle(.bordered)
                            
                            if !viewModel.subscriptionInfo.isEmpty {
                                Text(viewModel.subscriptionInfo)
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
                    
                    if viewModel.showFeedback {
                        Text(viewModel.feedbackMessage)
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(Color(.systemBackground))
                                    .shadow(radius: 3)
                            )
                            .padding()
                            .transition(.opacity)
                            .animation(.easeInOut, value: viewModel.showFeedback)
                    }
                }
            }
            .padding()
        }
        .onAppear {
            Task {
                await viewModel.initializeStore()
            }
        }
        .onReceive(StoreKitTheKit.shared.$storeState) { state in
            viewModel.feedbackMessage = "Store state changed: \(state)"
            viewModel.showFeedback = true
            // Update prices when store becomes available
            if state == .available {
                viewModel.updatePrices()
            }
        }
        .onReceive(StoreKitTheKit.shared.$purchaseDataChangedAfterGettingBackOnline) { changed in
            if changed {
                viewModel.feedbackMessage = "Purchase data has been updated"
                viewModel.showFeedback = true
                viewModel.getSubscriptionInfo()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
            Task {
                await StoreKitTheKit.shared.syncWithStore()
            }
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
