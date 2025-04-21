//
//  LocalStoreManager.swift
//  100Questions
//
//  Created by knc on 09.02.25.
//  Copyright © 2025 Schneider & co. All rights reserved.
//

import Foundation
import Security
import os

/// The LocalStoreManager handles the storing of all purchases locally such that the data is still accessible even if the connection to
/// Storekit should fail.
class LocalStoreManager: @unchecked Sendable {
    
    static let shared = LocalStoreManager()
    
    private let purchasesKey = "com.nicolaischneider.100questions.purchases"
    
    func storePurchasedProductIds(_ productIds: [String]) {
        do {
            let data = try JSONEncoder().encode(productIds)
            saveToKeychain(data)
        } catch {
            // Logger.purchase.addLog("Failed to encode purchases for keychain: \(error)", level: .error)
        }
    }
    
    func getPurchasedProductIds() -> [String] {
        guard let data = loadFromKeychain() else { return [] }
        
        do {
            return try JSONDecoder().decode([String].self, from: data)
        } catch {
            // Logger.purchase.addLog("Failed to decode purchases from keychain: \(error)", level: .error)
            return []
        }
    }
    
    private func saveToKeychain(_ data: Data) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: purchasesKey,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
        ]
        
        SecItemDelete(query as CFDictionary)
        let status = SecItemAdd(query as CFDictionary, nil)
        
        if status != errSecSuccess {
            // Logger.purchase.addLog("Failed to save to keychain: \(status)", level: .error)
        }
    }
    
    private func loadFromKeychain() -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: purchasesKey,
            kSecReturnData as String: kCFBooleanTrue!,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var dataTypeRef: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &dataTypeRef)
        
        return status == errSecSuccess ? (dataTypeRef as? Data) : nil
    }
}
