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
    
    var body: some View {
        ZStack {
            VStack(spacing: 20) {
                Text("StoreKitTheKit Tester")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .padding(.bottom, 30)
                
                if isLoading {
                    LoadingView()
                } else {
                    VStack(spacing: 30) {
                        // Purchase button
                        Button(action: {
                            Task {
                                await purchaseItem()
                            }
                        }) {
                            ActionButton(title: "Purchase Super Package", iconName: "cart")
                        }
                        
                        // Check purchase status button
                        Button(action: {
                            checkPurchaseStatus()
                        }) {
                            ActionButton(title: "Check Purchase Status", iconName: "magnifyingglass")
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
                // Initialize StoreKitTheKit
                await initializeStore()
            }
        }
    }
    
    private func initializeStore() async {
        // Simulate loading with a slight delay for testing
        await StoreKitTheKit.shared.begin()
        
        // Update UI on main thread
        await MainActor.run {
            isLoading = false
        }
    }
    
    private func purchaseItem() async {
        await MainActor.run {
            feedbackMessage = "Processing purchase..."
            showFeedback = true
        }
        
        let result = await StoreKitTheKit.shared.purchaseElement(element: StoreItems.superPackage)
        
        await MainActor.run {
            switch result {
            case .purchaseCompleted(let purchasable):
                feedbackMessage = "Successfully purchased: \(purchasable.bundleId)"
            case .purchaseFailure(let withError):
                feedbackMessage = "Purchase failed: \(withError)"
            }
        }
    }
    
    private func checkPurchaseStatus() {
        let isPurchased = StoreKitTheKit.shared.elementWasPurchased(element: StoreItems.superPackage)
        
        feedbackMessage = isPurchased ?
            "Super Package is purchased" :
            "Super Package is not purchased yet"
        showFeedback = true
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
