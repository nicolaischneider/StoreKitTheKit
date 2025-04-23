import StoreKit
import Foundation
import os
import Network

public class StoreKitTheKit: NSObject, @unchecked Sendable {
    
    public static let shared = StoreKitTheKit()
    
    // products
    var products = [Product]()
    var purchasedProducts = [Product]()
    var updateListenerTask: Task<Void, Error>? = nil
    
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
        await connectToStore()
    }
    
    // MARK: - initialize Store and load products
    
    public func begin () async {
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
