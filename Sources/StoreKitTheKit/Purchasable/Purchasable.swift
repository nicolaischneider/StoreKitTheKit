//
//  PurchasableGameModes.swift
//  100Questions
//
//  Created by Nicolai Schneider on 09.10.21.
//  Copyright © 2021 Schneider & co. All rights reserved.
//

import Foundation

enum Purchasable: String, CaseIterable, Equatable {
    
    // modes
    case interactiveMode = "com.nicolaischneider.100questions.interactivemode"
    case sexualAndFriendlyMode = "com.nicolaischneider.100questions.sexualandfriendlymode"
    
    // question packs
    case questionPack1 = "com.nicolaischneider.100questions.questionpack1"
    case questionPack2 = "com.nicolaischneider.100questions.questionpack2"
    case questionPack3 = "com.nicolaischneider.100questions.questionpack3"
    case questionPack4 = "com.nicolaischneider.100questions.questionpack4"
    
    // premium
    case premium = "com.nicolaischneider.100questions.premium"
    case premiumReduced = "com.nicolaischneider.100questions.premiumreduced"
    
    static func productIDExists(_ id: String) -> Bool {
        return Purchasable(rawValue: id) != nil
    }
}
