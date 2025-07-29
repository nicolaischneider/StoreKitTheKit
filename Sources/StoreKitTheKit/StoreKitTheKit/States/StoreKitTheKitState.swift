import StoreKit
import Foundation
import os

/// Thread-safe state manager for StoreKitTheKit
/// Handles all mutable state with proper synchronization using a serial dispatch queue
final class StoreKitTheKitState: @unchecked Sendable {
    
    // MARK: - Thread Safety
    
    /// Serial queue for all state mutations - ensures thread safety and prevents race conditions
    let queue = DispatchQueue(label: "com.storekitthekit.state", qos: .userInitiated)
    
    // MARK: - Internal State Properties
    
    /// Internal storage for products - access via thread-safe properties
    var _products: [Product] = []
    
    /// Internal storage for purchased products - access via thread-safe properties  
    var _purchasedProducts: [Product] = []
    
    /// Internal storage for update listener task - access via thread-safe methods
    var _updateListenerTask: Task<Void, Error>?
    
    /// Internal storage for sync state - access via thread-safe properties
    var _isSyncing = false
    
    // MARK: - Thread-Safe Public Interface
    
    /// Thread-safe access to products array
    var products: [Product] {
        queue.sync { _products }
    }
    
    /// Thread-safe access to purchased products array
    var purchasedProducts: [Product] {
        queue.sync { _purchasedProducts }
    }
    
    /// Thread-safe access to sync state
    var isSyncing: Bool {
        queue.sync { _isSyncing }
    }
    
    // MARK: - Safe Mutation Methods
    
    /// Thread-safely update the products array
    /// - Parameter products: New products array to set
    func updateProducts(_ products: [Product]) {
        queue.async {
            self._products = products
        }
    }
    
    /// Thread-safely update the purchased products array
    /// - Parameter products: New purchased products array to set
    func updatePurchasedProducts(_ products: [Product]) {
        queue.async {
            self._purchasedProducts = products
        }
    }
    
    /// Thread-safely set the syncing state
    /// - Parameter syncing: New syncing state
    func setIsSyncing(_ syncing: Bool) {
        queue.async {
            self._isSyncing = syncing
        }
    }
    
    /// Thread-safely update the listener task, canceling any existing task
    /// - Parameter task: New task to set, or nil to clear
    func updateListenerTask(_ task: Task<Void, Error>?) {
        queue.async {
            self._updateListenerTask?.cancel()
            self._updateListenerTask = task
        }
    }
    
    /// Thread-safely cancel and clear the listener task
    func cancelListenerTask() {
        queue.async {
            self._updateListenerTask?.cancel()
            self._updateListenerTask = nil
        }
    }
    
    // MARK: - Atomic Operations
    
    /// Perform an atomic read operation on multiple state properties
    /// - Parameter operation: Closure that receives products and purchasedProducts arrays
    /// - Returns: Result of the operation
    func performAtomicRead<T>(_ operation: @escaping ([Product], [Product]) -> T) -> T {
        queue.sync {
            operation(_products, _purchasedProducts)
        }
    }
    
    /// Thread-safe check if products array is empty
    /// - Returns: True if products array is empty
    func isEmpty() -> Bool {
        queue.sync { _products.isEmpty }
    }
    
    /// Thread-safe check if a specific product exists in products array
    /// - Parameter productId: Product ID to search for
    /// - Returns: True if product is found
    func hasProduct(withId productId: String) -> Bool {
        queue.sync {
            _products.contains { $0.id == productId }
        }
    }
    
    /// Thread-safe search for a product in products array
    /// - Parameter productId: Product ID to search for
    /// - Returns: Product if found, nil otherwise
    func getProduct(withId productId: String) -> Product? {
        queue.sync {
            _products.first { $0.id == productId }
        }
    }
    
    /// Thread-safe search for a purchased product
    /// - Parameter productId: Product ID to search for
    /// - Returns: True if product is in purchased products array
    func isPurchased(productId: String) -> Bool {
        queue.sync {
            _purchasedProducts.contains { $0.id == productId }
        }
    }
}
