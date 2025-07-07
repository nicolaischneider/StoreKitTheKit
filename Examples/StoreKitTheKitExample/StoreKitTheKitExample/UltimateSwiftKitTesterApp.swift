//
//  UltimateSwiftKitTesterApp.swift
//  UltimateSwiftKitTester
//
//  Created by knc on 23.04.25.
//

import SwiftUI
import StoreKitTheKit

@main
struct UltimateSwiftKitTesterApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .onAppear {
                    PurchasableManager.shared.register(purchasableItems: StoreItems.allItems)
                }
        }
    }
}
