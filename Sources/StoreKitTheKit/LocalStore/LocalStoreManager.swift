import Foundation
import Security
import os

/// The LocalStoreManager handles the storing of all purchases locally such that the data is still accessible even if the connection to
/// Storekit should fail.
class LocalStoreManager: @unchecked Sendable {
    
    static let shared = LocalStoreManager()
    
    // Thread-safe keychain access using serial queue
    private let keychainQueue = DispatchQueue(label: "com.storekitthekit.keychain", qos: .userInitiated)
    
    private let purchasesKey = "com.nicolaischneider.100questions.purchases"
    private let subscriptionsKey = "com.nicolaischneider.100questions.subscriptions"
    
    func storePurchasedProductIds(_ productIds: [String]) {
        keychainQueue.sync {
            do {
                let data = try JSONEncoder().encode(productIds)
                saveToKeychain(data)
            } catch {
                Logger.store.addLog("Failed to encode purchases for keychain: \(error)", level: .error)
            }
        }
    }
    
    func getPurchasedProductIds() -> [String] {
        return keychainQueue.sync {
            guard let data = loadFromKeychain() else { return [] }
            
            do {
                return try JSONDecoder().decode([String].self, from: data)
            } catch {
                Logger.store.addLog("Failed to decode purchases from keychain: \(error)", level: .error)
                return []
            }
        }
    }
    
    private func saveToKeychain(_ data: Data) {
        saveToKeychain(data, key: purchasesKey)
    }
    
    private func loadFromKeychain() -> Data? {
        return loadFromKeychain(key: purchasesKey)
    }
    
    // MARK: - Subscription Storage
    
    func storeSubscriptionData(_ subscriptionData: StoredSubscriptionData) {
        keychainQueue.sync {
            do {
                let data = try JSONEncoder().encode(subscriptionData)
                saveToKeychain(data, key: subscriptionsKey)
            } catch {
                Logger.store.addLog("Failed to encode subscription data for keychain: \(error)", level: .error)
            }
        }
    }
    
    func getSubscriptionData() -> StoredSubscriptionData {
        return keychainQueue.sync {
            guard let data = loadFromKeychain(key: subscriptionsKey) else { 
                return StoredSubscriptionData()
            }
            
            do {
                return try JSONDecoder().decode(StoredSubscriptionData.self, from: data)
            } catch {
                Logger.store.addLog("Failed to decode subscription data from keychain: \(error)", level: .error)
                return StoredSubscriptionData()
            }
        }
    }
    
    func getSubscriptionInfo(for productID: String) -> SubscriptionInfo? {
        let subscriptionData = getSubscriptionData()
        return subscriptionData.subscriptions[productID]
    }
    
    func isSubscriptionActive(for productID: String) -> Bool {
        guard let subscriptionInfo = getSubscriptionInfo(for: productID) else { return false }
        
        let now = Date()
        
        // Check if subscription is within its active period
        if subscriptionInfo.expirationDate > now {
            return true
        }
        
        // Check if subscription is in grace period
        if let gracePeriodEnd = subscriptionInfo.gracePeriodExpirationDate,
           gracePeriodEnd > now {
            return true
        }
        
        return false
    }
    
    private func saveToKeychain(_ data: Data, key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
        ]
        
        SecItemDelete(query as CFDictionary)
        let status = SecItemAdd(query as CFDictionary, nil)
        
        if status != errSecSuccess {
            Logger.store.addLog("Failed to save to keychain: \(status)", level: .error)
        }
    }
    
    private func loadFromKeychain(key: String) -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecReturnData as String: kCFBooleanTrue!,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var dataTypeRef: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &dataTypeRef)
        
        return status == errSecSuccess ? (dataTypeRef as? Data) : nil
    }
}
