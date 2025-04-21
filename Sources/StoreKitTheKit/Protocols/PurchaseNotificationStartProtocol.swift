//
//  PurchaseNotificationProtocol.swift
//  100Questions
//
//  Created by Nicolai Schneider on 17.10.21.
//  Copyright © 2021 Schneider & co. All rights reserved.
//

import Foundation

protocol PurchaseNotificationProtocol {
    func itemWasPurchased (_ item: Purchasable?)
    func purchasing ()
}

protocol PurchaseNotificationLaunchProtocol: PurchaseNotificationProtocol {}
