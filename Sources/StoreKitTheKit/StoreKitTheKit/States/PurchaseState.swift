//
//  PurchaseState.swift
//  100Questions
//
//  Created by Nicolai Schneider on 03.12.23.
//  Copyright © 2023 Schneider & co. All rights reserved.
//

import Foundation

public enum PurchaseState: Sendable {
    case purchaseCompleted(Purchasable)
    case purchaseFailure(PurchaseError)
    
    
    public enum PurchaseError: Error, Sendable {
        // Product errors
        case productNotFound
        case unverifiedPurchase
        
        // User interaction
        case userCancelled
        case pendingPurchase
        
        // System errors
        case unknownPurchaseState
        case purchaseError(Error)
    }
}
