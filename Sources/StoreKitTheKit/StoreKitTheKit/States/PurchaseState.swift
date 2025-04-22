//
//  PurchaseState.swift
//  100Questions
//
//  Created by Nicolai Schneider on 03.12.23.
//  Copyright © 2023 Schneider & co. All rights reserved.
//

import Foundation

public enum PurchaseState {
    case purchaseCompleted(Purchasable)
    case purchaseNotCompleted(withError: Bool)
}
