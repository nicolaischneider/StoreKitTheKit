//
//  StoreManager.swift
//  100Questions
//
//  Created by Nicolai Schneider on 09.10.21.
//  Copyright © 2021 Schneider & co. All rights reserved.
//

import StoreKit
import Foundation
import os
import Network

class StoreKitTheKit: NSObject, @unchecked Sendable {
    
    static let shared = StoreKitTheKit()
    
    // products
    var products = [Product]()
    var purchasedProducts = [Product]()
    var updateListenerTask: Task<Void, Error>? = nil
    
    // delegates
    weak var availabilityDelegate: StoreAvailabilityDelegate?
    
    // Add network monitor
    private let networkMonitor = NWPathMonitor()
    private let monitorQueue = DispatchQueue(label: "com.nicolaischneider.100questions.networkMonitor")
    
    // Add store state
    @Published var storeState: StoreAvailabilityState = .checking {
        didSet {
            Logger.store.addLog("Store state has updated to \(storeState).")
        }
    }
    
    @Published var purchaseDataChanged = false
    
    var storeIsAvailable: Bool {
        return storeState == .available && !products.isEmpty
    }
        
    override init () {
        super.init()
        setupNetworkMonitoring()
    }
    
    deinit {
        updateListenerTask?.cancel()
        networkMonitor.cancel()
    }
    
    private func setupNetworkMonitoring() {
        networkMonitor.pathUpdateHandler = { [weak self] path in
            guard let self = self else { return }
            
            if path.status == .satisfied {
                // Logger.app.addLog("Network connection restored.")
                Task {
                    await self.retryStoreConnection()
                }
            } else {
                // Logger.app.addLog("No network connection available.")
            }
        }
        networkMonitor.start(queue: monitorQueue)
    }
    
    func retryStoreConnection() async {
        await MainActor.run {
            self.storeState = .checking
        }
        await connectToStore()
    }
    
    // MARK: - initialize Store and load products
    
    func begin () async {
        await MainActor.run {
            self.storeState = .checking
        }
        SKPaymentQueue.default().add(self)
        await connectToStore()
    }
    
    func connectToStore () async {
        updateListenerTask?.cancel()
        updateListenerTask = listenForTransactions()
        await requestProducts()
        await updateCustomerProductStatus()
    }
    
    func purchasedProductsMatchLocallyStored(productIds: [String]) -> Bool {
        let currentProductIds = LocalStoreManager.shared.getPurchasedProductIds()
        return Set(productIds) == Set(currentProductIds)
    }
}
