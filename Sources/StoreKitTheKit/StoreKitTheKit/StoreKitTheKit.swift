import StoreKit
import Foundation
import os
import Network

public class StoreKitTheKit: NSObject, @unchecked Sendable {
    
    public static let shared = StoreKitTheKit()

    // MARK: - Properties
    let purchasableManager = PurchasableManager()
    
    // Thread-safe state management
    let state = StoreKitTheKitState()
    
    // Loading indicators
    private var storeKitTheKitHasBeenStarted = false
    
    // Add network monitor
    private let networkMonitor = NWPathMonitor()
    private let monitorQueue = DispatchQueue(label: "com.nicolaischneider.100questions.networkMonitor")
    
    // Add store state
    @Published public var storeState: StoreAvailabilityState = .checking {
        didSet {
            Logger.store.addLog("Store state has updated to \(storeState).")
        }
    }
    
    @Published public var purchaseDataChangedAfterGettingBackOnline = false
    
    // MARK: - Thread-Safe Property Access
    
    /// Thread-safe access to products array
    var products: [Product] {
        state.products
    }
    
    /// Thread-safe access to purchased products array
    var purchasedProducts: [Product] {
        state.purchasedProducts
    }
    
    /// Thread-safe access to syncing state
    var isSyncing: Bool {
        state.isSyncing
    }
    
    var storeIsAvailable: Bool {
        return storeState == .available && !state.isEmpty()
    }
    
    // MARK: - Thread-Safe @Published Property Updates
    
    /// Thread-safe method to update storeState on main thread
    /// Ensures @Published property updates happen on the correct thread for SwiftUI
    func updateStoreState(_ newState: StoreAvailabilityState) {
        DispatchQueue.main.async {
            self.storeState = newState
        }
    }
    
    /// Thread-safe method to update purchaseDataChangedAfterGettingBackOnline on main thread
    /// Ensures @Published property updates happen on the correct thread for SwiftUI
    func updatePurchaseDataChanged(_ changed: Bool) {
        DispatchQueue.main.async {
            self.purchaseDataChangedAfterGettingBackOnline = changed
        }
    }
        
    override init() {
        super.init()
        setupNetworkMonitoring()
    }
    
    deinit {
        state.cancelListenerTask()
        networkMonitor.cancel()
    }
    
    private func setupNetworkMonitoring() {
        networkMonitor.pathUpdateHandler = { [weak self] path in
            guard let self = self else { return }
            
            if path.status == .satisfied {
                Logger.store.addLog("Network connection restored.")
                Task {
                    await self.retryStoreConnection()
                }
            } else {
                Logger.store.addLog("No network connection available.")
            }
        }
        networkMonitor.start(queue: monitorQueue)
    }
    
    private func retryStoreConnection() async {
        updateStoreState(.checking)
        await syncWithStore()
    }
    
    // MARK: - initialize Store and load products
    
    /// Initialize the StoreKit, register the purchasable items, and start listening for transactions.
    /// - Parameter iapItems: A list of purchasable items to register within the app..
    public func start(iapItems: [Purchasable]) async {
        Logger.store.addLog("Starting StoreKitTheKit with items: \(iapItems.map { $0.bundleId })")
        updateStoreState(.checking)
        
        await purchasableManager.register(purchasableItems: iapItems)
        SKPaymentQueue.default().add(self)
        storeKitTheKitHasBeenStarted = true
        await syncWithStore()
    }
    
    public func syncWithStore() async {
        // Prevent concurrent sync operations
        if !storeKitTheKitHasBeenStarted {
            Logger.store.addLog("StoreKitTheKit has not been started yet. Please call start(iapItems:) first.")
            return
        }
        if state.isSyncing {
            Logger.store.addLog("Sync already in progress, skipping...")
            return
        }
        
        state.setIsSyncing(true)
        defer { state.setIsSyncing(false) }
        
        Logger.store.addLog("Syncing with StoreKit...")
        let newListenerTask = listenForTransactions()
        state.updateListenerTask(newListenerTask)
        await requestProducts()
        await updateCustomerProductStatus()
    }
    
    func purchasedProductsMatchLocallyStored(productIds: [String]) -> Bool {
        let currentProductIds = LocalStoreManager.shared.getPurchasedProductIds()
        return Set(productIds) == Set(currentProductIds)
    }
}
