//
//  StoreAvailability.swift
//  100Questions
//
//  Created by knc on 08.02.25.
//  Copyright © 2025 Schneider & co. All rights reserved.
//

import Foundation

enum StoreAvailabilityState {
    case available
    case unavailable
    case checking
}

protocol StoreAvailabilityDelegate: AnyObject {
    func storeAvailabilityChanged(_ state: StoreAvailabilityState)
}
