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
                            
                            Button("Purchase Super Package") {
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
                            
                            // Subscription Picker
                            Picker("Select Subscription", selection: $viewModel.selectedSubscription) {
                                Text("Weekly ($0.99)").tag(StoreItems.weeklySubscription)
                                Text("Yearly ($10.99)").tag(StoreItems.yearlySubscription)
                            }
                            .pickerStyle(.segmented)
                            .padding(.horizontal)
                            
                            // Purchase current subscription
                            Button("Purchase \(viewModel.selectedSubscription == StoreItems.weeklySubscription ? "Weekly" : "Yearly")") {
                                Task { await viewModel.purchaseSubscription() }
                            }
                            .buttonStyle(.borderedProminent)
                            
                            // Switch subscription (purchase the other one)
                            Button("Switch to \(viewModel.selectedSubscription == StoreItems.weeklySubscription ? "Yearly" : "Weekly")") {
                                Task { await viewModel.switchSubscription() }
                            }
                            .buttonStyle(.bordered)
                            
                            // Check subscription status
                            Button("Check Status") {
                                viewModel.checkSubscriptionStatus()
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
                                    Button("Buy 100 Coins ($1.99)") {
                                        Task { await viewModel.purchaseConsumable(StoreItems.hundredCoins) }
                                    }
                                    .buttonStyle(.bordered)
                                    
                                    // Purchase energy
                                    Button("Buy 10 Energy ($0.99)") {
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
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
