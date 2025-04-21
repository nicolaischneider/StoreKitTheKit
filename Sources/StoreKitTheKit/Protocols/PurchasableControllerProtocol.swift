//
//  PurchasableControllerProtocol.swift
//  100Questions
//
//  Created by Nicolai Schneider on 03.12.23.
//  Copyright © 2023 Schneider & co. All rights reserved.
//

import UIKit
import os

protocol PurchasableControllerProtocol {
    func purchase(item: Purchasable)
    func handlePurchaseResult(_ result: PurchaseState)
    func showLoadingPurchaseView(_ show: Bool)
    func onPurchaseProcessEnded(purchasable: Purchasable?, withError: Bool)
}

extension PurchasableControllerProtocol {
    
    func purchase(item: Purchasable) {
        guard !StoreManager.shared.userHasAccessTo(element: item) else {
            Logger.purchase.addLog("User has already access to Purchasable.")
            return
        }
        
        showLoadingPurchaseView(true)
        
        Task {
            let purchaseState = await StoreManager.shared.purchaseElement(element: item)
            handlePurchaseResult(purchaseState)
        }
    }

    func handlePurchaseResult(_ result: PurchaseState) {
        DispatchQueue.main.async {
            switch result {
            case .purchaseCompleted(let purchasable):
                Logger.purchase.addLog("Purchase was completed.")
                self.onPurchaseProcessEnded(purchasable: purchasable, withError: false)
            case .purchaseNotCompleted(let withError):
                Logger.purchase.addLog("Purchase was not completed.")
                self.onPurchaseProcessEnded(purchasable: nil, withError: withError)
            }
            self.showLoadingPurchaseView(false)
        }
    }
}

