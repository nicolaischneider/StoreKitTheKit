import StoreKit
import Foundation
import os
import Network

public class StoreKitTheKit: NSObject, @unchecked Sendable {
    
    public static let shared = StoreKitTheKit()

    // MARK: - Properties
    let purchasableManager = PurchasableManager()
    
    // Products
    var products = [Product]()
    var purchasedProducts = [Product]()
    var updateListenerTask: Task<Void, Error>? = nil
    
    // Loading indicators
    private var storeKitTheKitHasBeenStarted = false
    private var isSyncing = false
    
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
    
    var storeIsAvailable: Bool {
        return storeState == .available && !products.isEmpty
    }
        
    override init() {
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
        await MainActor.run {
            self.storeState = .checking
        }
        await syncWithStore()
    }
    
    // MARK: - initialize Store and load products
    
    /// Initialize the StoreKit, register the purchasable items, and start listening for transactions.
    /// - Parameter iapItems: A list of purchasable items to register within the app..
    public func start(iapItems: [Purchasable]) async {
        Logger.store.addLog("Starting StoreKitTheKit with items: \(iapItems.map { $0.bundleId })")
        await MainActor.run {
            self.storeState = .checking
        }
        
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
        if isSyncing {
            Logger.store.addLog("Sync already in progress, skipping...")
            return
        }
        
        isSyncing = true
        defer { isSyncing = false }
        
        Logger.store.addLog("Syncing with StoreKit...")
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
